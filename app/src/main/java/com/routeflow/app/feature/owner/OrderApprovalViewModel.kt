package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
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
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OrderApprovalState(
    val orders: List<OrderDetailState> = emptyList(),
    val isLoading: Boolean = false,
    val selectedOrderId: String? = null,
    val rejectionReason: String = "",
    val error: String? = null
)

data class OrderDetailState(
    val order: OrderEntity,
    val items: List<OrderItemWithProduct>,
    val retailerName: String,
    val syncState: com.routeflow.app.domain.model.OrderSyncState = com.routeflow.app.domain.model.OrderSyncState.SYNCED,
    val syncError: String? = null
)

data class OrderItemWithProduct(
    val item: OrderItemEntity,
    val product: Product?
)

@HiltViewModel
class OrderApprovalViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(OrderApprovalState())

    val state: StateFlow<OrderApprovalState> = combine(
        orderRepository.getAllOrders(),
        productRepository.getAllProducts(),
        orderRepository.getPendingSyncOutbox(),
        _uiState
    ) { orders, products, pendingSyncs, uiState ->
        val details = orders.filter { it.status == "SUBMITTED" || it.status == "NEEDS_ATTENTION" }.map { order ->
            val items = orderRepository.getItemsForOrder(order.id).first().map { item ->
                OrderItemWithProduct(item, products.find { it.id == item.productId })
            }
            val retailer = retailerRepository.getRetailerById(order.retailerId).first()
            val outboxItem = pendingSyncs.firstOrNull { it.payload.contains(order.id) }
            val (syncState, syncError) = when {
                order.status == "NEEDS_ATTENTION" ->
                    com.routeflow.app.domain.model.OrderSyncState.NEEDS_ATTENTION to (order.rejectionReason ?: outboxItem?.lastError ?: "Validation failure")
                outboxItem != null && outboxItem.type == "PERMANENT_FAILURE" ->
                    com.routeflow.app.domain.model.OrderSyncState.NEEDS_ATTENTION to (outboxItem.lastError ?: "Permanent failure")
                outboxItem != null ->
                    com.routeflow.app.domain.model.OrderSyncState.SAVED_OFFLINE to outboxItem.lastError
                else ->
                    com.routeflow.app.domain.model.OrderSyncState.SYNCED to null
            }
            OrderDetailState(
                order = order,
                items = items,
                retailerName = retailer?.name ?: "Unknown Retailer",
                syncState = syncState,
                syncError = syncError
            )
        }
        uiState.copy(orders = details, isLoading = false)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OrderApprovalState(isLoading = true)
    )

    fun approveOrder(orderId: String) {
        _uiState.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            val result = orderRepository.approveOrder(orderId)
            _uiState.update { it.copy(isLoading = false) }
            if (result.isFailure) {
                _uiState.update { it.copy(error = result.exceptionOrNull()?.message) }
            }
        }
    }

    fun rejectOrder(orderId: String, reason: String) {
        viewModelScope.launch {
            orderRepository.rejectOrder(orderId, reason)
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

private fun kotlinx.coroutines.flow.MutableStateFlow<OrderApprovalState>.update(function: (OrderApprovalState) -> OrderApprovalState) {
    this.value = function(this.value)
}
