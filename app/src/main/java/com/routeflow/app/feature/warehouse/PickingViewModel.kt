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

    val state: StateFlow<PickingState> = combine(
        orderRepository.getAllOrders(),
        productRepository.getAllProducts(),
        _error
    ) { orders, products, error ->
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
        PickingState(orders = details, error = error)
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
                orderRepository.updateItemPickingStatus(orderId, productId, !item.isPicked)
            }
        }
    }

    fun startPicking(orderId: String) {
        viewModelScope.launch {
            orderRepository.startPicking(orderId)
        }
    }

    fun markPacked(orderId: String) {
        val orderState = state.value.orders.find { it.order.id == orderId }
        if (orderState?.allPicked != true) {
            _error.value = "Confirm all items before packing"
            return
        }
        viewModelScope.launch {
            orderRepository.markPacked(orderId)
        }
    }

    fun dispatchOrder(orderId: String) {
        viewModelScope.launch {
            val result = orderRepository.dispatchOrder(orderId)
            if (result.isFailure) {
                _error.value = result.exceptionOrNull()?.message
            }
        }
    }
    
    fun clearError() {
        _error.value = null
    }
}
