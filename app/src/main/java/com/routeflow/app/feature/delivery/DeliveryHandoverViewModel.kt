package com.routeflow.app.feature.delivery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.CashHandoverDto
import com.routeflow.app.core.network.dto.CashHandoverSummaryResponse
import com.routeflow.app.domain.repository.HandoverRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HandoverUiState(
    val isLoading: Boolean = true,
    val cashHeldPaise: Long = 0L,
    val totalCollectedPaise: Long = 0L,
    val totalSettledPaise: Long = 0L,
    val pendingHandover: CashHandoverDto? = null,
    val recentHandovers: List<CashHandoverDto> = emptyList(),
    val isSubmitting: Boolean = false,
    val error: String? = null
)

sealed interface HandoverEvent {
    data class Success(val message: String) : HandoverEvent
    data class Error(val error: String) : HandoverEvent
}

@HiltViewModel
class DeliveryHandoverViewModel @Inject constructor(
    private val handoverRepository: HandoverRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HandoverUiState())
    val uiState: StateFlow<HandoverUiState> = _uiState.asStateFlow()

    private val _eventFlow = MutableSharedFlow<HandoverEvent>()
    val eventFlow: SharedFlow<HandoverEvent> = _eventFlow.asSharedFlow()

    init {
        loadSummary()
    }

    fun loadSummary() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            handoverRepository.getSummary().fold(
                onSuccess = { summary ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            cashHeldPaise = summary.cashHeldPaise,
                            totalCollectedPaise = summary.totalCollectedPaise,
                            totalSettledPaise = summary.totalSettledPaise,
                            pendingHandover = summary.pendingHandover,
                            recentHandovers = summary.recentHandovers
                        )
                    }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isLoading = false, error = err.message) }
                }
            )
        }
    }

    fun submitHandover(amountPaise: Long, notes: String?) {
        if (_uiState.value.isSubmitting) return
        if (_uiState.value.pendingHandover != null) {
            viewModelScope.launch {
                _eventFlow.emit(HandoverEvent.Error("A handover request is already pending. Wait for the owner to acknowledge it."))
            }
            return
        }
        _uiState.update { it.copy(isSubmitting = true) }
        viewModelScope.launch {
            handoverRepository.submitHandover(amountPaise = amountPaise, notes = notes).fold(
                onSuccess = { resp ->
                    _uiState.update { it.copy(isSubmitting = false) }
                    if (resp.success) {
                        _eventFlow.emit(HandoverEvent.Success("Handover of ₹${"%,d".format(amountPaise / 100)} submitted. Awaiting owner confirmation."))
                        loadSummary()
                    } else {
                        _eventFlow.emit(HandoverEvent.Error("Server rejected handover request"))
                    }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isSubmitting = false) }
                    _eventFlow.emit(HandoverEvent.Error(err.message ?: "Failed to submit handover"))
                }
            )
        }
    }
}
