package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.DeliveryExceptionDto
import com.routeflow.app.core.network.dto.DriverHeldStockDto
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto
import com.routeflow.app.domain.repository.OrderRepository
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

data class OwnerReturnsUiState(
    val isLoading: Boolean = true,
    val returns: List<ReturnRequestDto> = emptyList(),
    val deliveryExceptions: List<DeliveryExceptionDto> = emptyList(),
    val driverHeldStock: List<DriverHeldStockDto> = emptyList(),
    val error: String? = null,
    val processingId: String? = null
) {
    val pendingAuthorization: List<ReturnRequestDto>
        get() = returns.filter { it.status == "REQUESTED" }

    val pendingReceiving: List<ReturnRequestDto>
        get() = returns.filter { it.status == "AUTHORIZED" }

    val pendingInspection: List<ReturnRequestDto>
        get() = returns.filter { it.status == "RECEIVED" }

    val pendingCredit: List<ReturnRequestDto>
        get() = returns.filter { it.status == "INSPECTED" }

    val creditedOrApproved: List<ReturnRequestDto>
        get() = returns.filter { it.status in listOf("CREDITED", "APPROVED") }
}

sealed interface OwnerReturnEvent {
    data class Success(val message: String) : OwnerReturnEvent
    data class Error(val error: String) : OwnerReturnEvent
}

@HiltViewModel
class OwnerReturnsViewModel @Inject constructor(
    private val returnRepository: ReturnRepository,
    private val orderRepository: OrderRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(OwnerReturnsUiState())
    val uiState: StateFlow<OwnerReturnsUiState> = _uiState.asStateFlow()

    private val _eventFlow = MutableSharedFlow<OwnerReturnEvent>()
    val eventFlow: SharedFlow<OwnerReturnEvent> = _eventFlow.asSharedFlow()

    init {
        loadData()
    }

    fun loadData() {
        loadReturns()
        loadExceptionsAndHeldStock()
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

    fun loadExceptionsAndHeldStock() {
        viewModelScope.launch {
            orderRepository.getDeliveryExceptions().onSuccess { excList ->
                _uiState.update { it.copy(deliveryExceptions = excList) }
            }
            orderRepository.getDriverHeldStock().onSuccess { stockList ->
                _uiState.update { it.copy(driverHeldStock = stockList) }
            }
        }
    }

    fun authorizeReturn(returnId: String, action: String, notes: String) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = returnId) }
        viewModelScope.launch {
            returnRepository.authorizeReturn(id = returnId, action = action, notes = notes).fold(
                onSuccess = {
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Success("Return authorization ${action.lowercase()}d"))
                    loadReturns()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Error(err.message ?: "Authorization failed"))
                }
            )
        }
    }

    fun receiveReturn(returnId: String, notes: String?) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = returnId) }
        viewModelScope.launch {
            returnRepository.receiveReturn(id = returnId, notes = notes).fold(
                onSuccess = {
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Success("Return marked received at warehouse"))
                    loadReturns()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Error(err.message ?: "Receiving failed"))
                }
            )
        }
    }

    fun inspectReturn(returnId: String, action: String, items: List<InspectItemRequest>?, notes: String?) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = returnId) }
        viewModelScope.launch {
            returnRepository.inspectReturn(id = returnId, action = action, items = items, notes = notes).fold(
                onSuccess = { resp ->
                    _uiState.update { it.copy(processingId = null) }
                    val creditMsg = if (resp.totalCreditNotePaise > 0) " Credit note: ₹${resp.totalCreditNotePaise / 100}" else ""
                    _eventFlow.emit(OwnerReturnEvent.Success("Return inspected.$creditMsg"))
                    loadReturns()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Error(err.message ?: "Inspection failed"))
                }
            )
        }
    }

    fun creditReturn(returnId: String, notes: String) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = returnId) }
        viewModelScope.launch {
            returnRepository.creditReturn(id = returnId, notes = notes).fold(
                onSuccess = {
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Success("Credit note approved and issued to retailer"))
                    loadReturns()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(OwnerReturnEvent.Error(err.message ?: "Credit approval failed"))
                }
            )
        }
    }
}
