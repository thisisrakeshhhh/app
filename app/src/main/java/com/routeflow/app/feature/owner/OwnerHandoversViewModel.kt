package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.CashHandoverDto
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

data class OwnerHandoversUiState(
    val isLoading: Boolean = true,
    val handovers: List<CashHandoverDto> = emptyList(),
    val error: String? = null,
    val processingId: String? = null
) {
    val pendingHandovers: List<CashHandoverDto>
        get() = handovers.filter { it.status == "PENDING" }

    val completedHandovers: List<CashHandoverDto>
        get() = handovers.filter { it.status != "PENDING" }

    val pendingTotalPaise: Long
        get() = pendingHandovers.sumOf { it.amount_paise }
}

sealed interface HandoverActionEvent {
    data class Success(val message: String) : HandoverActionEvent
    data class Error(val error: String) : HandoverActionEvent
}

@HiltViewModel
class OwnerHandoversViewModel @Inject constructor(
    private val handoverRepository: HandoverRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(OwnerHandoversUiState())
    val uiState: StateFlow<OwnerHandoversUiState> = _uiState.asStateFlow()

    private val _eventFlow = MutableSharedFlow<HandoverActionEvent>()
    val eventFlow: SharedFlow<HandoverActionEvent> = _eventFlow.asSharedFlow()

    init {
        loadHandovers()
    }

    fun loadHandovers() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            handoverRepository.getOwnerHandovers().fold(
                onSuccess = { list ->
                    _uiState.update { it.copy(isLoading = false, handovers = list) }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isLoading = false, error = err.message) }
                }
            )
        }
    }

    fun acknowledgeHandover(
        id: String,
        action: String, // "ACCEPT" or "REJECT"
        receivedPaise: Long?,
        notes: String?
    ) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = id) }
        viewModelScope.launch {
            handoverRepository.acknowledgeHandover(
                id = id,
                action = action,
                receivedPaise = receivedPaise,
                notes = notes
            ).fold(
                onSuccess = { resp ->
                    _uiState.update { it.copy(processingId = null) }
                    val discrepancy = resp.discrepancyPaise ?: 0L
                    val discrepancyMsg = if (discrepancy != 0L) {
                        " (Discrepancy: ₹${discrepancy / 100})"
                    } else ""
                    _eventFlow.emit(HandoverActionEvent.Success("Handover ${resp.status.lowercase()}$discrepancyMsg"))
                    loadHandovers()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(HandoverActionEvent.Error(err.message ?: "Action failed"))
                }
            )
        }
    }
}
