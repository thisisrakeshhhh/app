package com.routeflow.app.feature.warehouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PickingState(
    val orders: List<PickingOrderDetailState> = emptyList(),
    val deliveryExecutives: List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto> = emptyList(),
    val selectedDeliveryExecutiveMap: Map<String, String> = emptyMap(),
    val dispatchDialogOrderId: String? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

data class PickingOrderDetailState(
    val order: OrderEntity,
    val items: List<OrderItemWithPicking>,
    val retailerName: String,
    val allPicked: Boolean = false
)

data class OrderItemWithPicking(
    val item: OrderItemEntity,
    val product: Product?,
    val isPicked: Boolean = false
)

@HiltViewModel
class PickingViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val _error = MutableStateFlow<String?>(null)
    private val _deliveryExecutives = MutableStateFlow<List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto>>(emptyList())
    private val _selectedDeliveryExecutives = MutableStateFlow<Map<String, String>>(emptyMap())
    private val _dispatchDialogOrderId = MutableStateFlow<String?>(null)

    init {
        loadDeliveryExecutives()
    }

    fun loadDeliveryExecutives() {
        viewModelScope.launch {
            val result = orderRepository.getDeliveryExecutives()
            if (result.isSuccess) {
                val list = result.getOrNull().orEmpty()
                _deliveryExecutives.value = list
                // Pre-select first executive if available and not yet selected
                if (list.isNotEmpty()) {
                    _selectedDeliveryExecutives.update { current ->
                        val updated = current.toMutableMap()
                        state.value.orders.forEach { orderState ->
                            if (!updated.containsKey(orderState.order.id)) {
                                updated[orderState.order.id] = list.first().id
                            }
                        }
                        updated
                    }
                }
            }
        }
    }

    private data class PickingUiInternalState(
        val executives: List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto> = emptyList(),
        val selectedExecs: Map<String, String> = emptyMap(),
        val dialogOrderId: String? = null,
        val error: String? = null
    )

    private val _uiInternalState = combine(
        _deliveryExecutives,
        _selectedDeliveryExecutives,
        _dispatchDialogOrderId,
        _error
    ) { executives, selectedExecs, dialogOrderId, error ->
        PickingUiInternalState(executives, selectedExecs, dialogOrderId, error)
    }

    val state: StateFlow<PickingState> = combine(
        orderRepository.getAllOrders(),
        productRepository.getAllProducts(),
        _uiInternalState
    ) { orders, products, uiState ->
        val details = orders.filter { 
            it.status == "APPROVED" || it.status == "PICKING" || it.status == "PACKED" 
        }.map { order ->
            val items = orderRepository.getItemsForOrder(order.id).first().map { item ->
                OrderItemWithPicking(item, products.find { it.id == item.productId }, item.isPicked)
            }
            val retailer = retailerRepository.getRetailerById(order.retailerId).first()
            PickingOrderDetailState(
                order = order, 
                items = items, 
                retailerName = retailer?.name ?: "Unknown Retailer",
                allPicked = items.all { it.isPicked }
            )
        }
        PickingState(
            orders = details,
            deliveryExecutives = uiState.executives,
            selectedDeliveryExecutiveMap = uiState.selectedExecs,
            dispatchDialogOrderId = uiState.dialogOrderId,
            isLoading = false,
            error = uiState.error
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = PickingState(isLoading = true)
    )

    fun toggleItemPicked(orderId: String, productId: String) {
        val order = state.value.orders.find { it.order.id == orderId }
        val item = order?.items?.find { it.item.productId == productId }
        if (item != null) {
            viewModelScope.launch {
                val result = orderRepository.updateItemPickingStatus(orderId, productId, !item.isPicked)
                if (result.isFailure) {
                    _error.value = result.exceptionOrNull()?.message ?: "Failed to update item picking status"
                }
            }
        }
    }

    fun startPicking(orderId: String) {
        viewModelScope.launch {
            val result = orderRepository.startPicking(orderId)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Failed to start picking on server"
            }
        }
    }

    fun markPacked(orderId: String) {
        val orderState = state.value.orders.find { it.order.id == orderId }
        if (orderState?.allPicked != true) {
            _error.value = "Confirm all items before packing"
            return
        }
        viewModelScope.launch {
            val result = orderRepository.markPacked(orderId)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message ?: "Failed to pack order on server"
            }
        }
    }

    fun openDispatchDialog(orderId: String) {
        _dispatchDialogOrderId.value = orderId
        // If delivery executives list is empty, retry fetching
        if (_deliveryExecutives.value.isEmpty()) {
            loadDeliveryExecutives()
        }
    }

    fun dismissDispatchDialog() {
        _dispatchDialogOrderId.value = null
    }

    fun selectDeliveryExecutive(orderId: String, employeeId: String) {
        _selectedDeliveryExecutives.update { current ->
            current + (orderId to employeeId)
        }
    }

    fun confirmDispatch(orderId: String) {
        val executiveId = _selectedDeliveryExecutives.value[orderId] 
            ?: _deliveryExecutives.value.firstOrNull()?.id

        if (executiveId.isNullOrBlank()) {
            _error.value = "Please select a delivery executive to dispatch"
            return
        }

        viewModelScope.launch {
            val result = orderRepository.dispatchOrder(orderId, executiveId)
            if (result.isSuccess) {
                _dispatchDialogOrderId.value = null
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Failed to dispatch order"
            }
        }
    }
    
    fun clearError() {
        _error.value = null
    }
}
