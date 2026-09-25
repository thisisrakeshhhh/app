package com.routeflow.app.feature.warehouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto
import com.routeflow.app.domain.repository.ReturnRepository
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

data class WarehouseReturnsUiState(
    val isLoading: Boolean = true,
    val returns: List<ReturnRequestDto> = emptyList(),
    val error: String? = null,
    val inspectingId: String? = null
)

sealed interface ReturnEvent {
    data class InspectSuccess(val message: String, val creditNotePaise: Long) : ReturnEvent
    data class Error(val error: String) : ReturnEvent
}

@HiltViewModel
class WarehouseReturnsViewModel @Inject constructor(
    private val returnRepository: ReturnRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(WarehouseReturnsUiState())
    val uiState: StateFlow<WarehouseReturnsUiState> = _uiState.asStateFlow()

    private val _eventFlow = MutableSharedFlow<ReturnEvent>()
    val eventFlow: SharedFlow<ReturnEvent> = _eventFlow.asSharedFlow()

    init {
        loadReturns()
    }

    fun loadReturns() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            returnRepository.getPendingReturns().fold(
                onSuccess = { list ->
                    _uiState.update { it.copy(isLoading = false, returns = list) }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isLoading = false, error = err.message) }
                }
            )
        }
    }

    fun inspectReturn(
        returnId: String,
        action: String, // "APPROVE" or "REJECT"
        items: List<InspectItemRequest>?,
        notes: String?
    ) {
        if (_uiState.value.inspectingId != null) return
        _uiState.update { it.copy(inspectingId = returnId) }
        viewModelScope.launch {
            returnRepository.inspectReturn(
                id = returnId,
                action = action,
                items = items,
                notes = notes
            ).fold(
                onSuccess = { resp ->
                    _uiState.update { it.copy(inspectingId = null) }
                    if (resp.success) {
                        val creditMsg = if (resp.totalCreditNotePaise > 0) {
                            " Credit note: ₹${"%,d".format(resp.totalCreditNotePaise / 100)}"
                        } else ""
                        _eventFlow.emit(ReturnEvent.InspectSuccess(
                            message = "Return ${action.lowercase()}d.${creditMsg}",
                            creditNotePaise = resp.totalCreditNotePaise
                        ))
                        loadReturns()
                    } else {
                        _eventFlow.emit(ReturnEvent.Error("Server rejected inspection: ${resp.status}"))
                    }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(inspectingId = null) }
                    _eventFlow.emit(ReturnEvent.Error(err.message ?: "Inspection failed"))
                }
            )
        }
    }
}
