package com.routeflow.app.feature.warehouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.domain.model.Product
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

data class PickingState(
    val orders: List<PickingOrderDetailState> = emptyList(),
    val isLoading: Boolean = false
)

data class PickingOrderDetailState(
    val order: OrderEntity,
    val items: List<OrderItemWithPicking>,
    val retailerName: String
)

data class OrderItemWithPicking(
    val item: OrderItemEntity,
    val product: Product?,
    val isPicked: Boolean = false
)

@HiltViewModel
class PickingViewModel @Inject constructor(
    private val database: RouteFlowDatabase,
    private val orderDao: OrderDao,
    private val productDao: ProductDao,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<PickingState> = combine(
        orderDao.getAllOrders(),
        productDao.getAllProducts()
    ) { orders, productEntities ->
        // Now including PACKED status so it doesn't disappear from the warehouse view
        val details = orders.filter { 
            it.status == "APPROVED" || it.status == "PICKING" || it.status == "PACKED" 
        }.map { order ->
            val items = orderDao.getItemsForOrder(order.id).first().map { item ->
                val entity = productEntities.find { it.id == item.productId }
                OrderItemWithPicking(item, entity?.asDomainModel())
            }
            val retailer = retailerRepository.getRetailerById(order.retailerId).first()
            PickingOrderDetailState(order, items, retailer?.name ?: "Unknown Retailer")
        }
        PickingState(orders = details)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = PickingState(isLoading = true)
    )

    fun startPicking(orderId: String) {
        viewModelScope.launch {
            orderDao.updateOrderStatus(orderId, "PICKING", System.currentTimeMillis())
        }
    }

    fun markPacked(orderId: String) {
        viewModelScope.launch {
            orderDao.updateOrderStatus(orderId, "PACKED", System.currentTimeMillis())
        }
    }

    fun dispatchOrder(orderId: String) {
        viewModelScope.launch {
            database.withTransaction {
                val orderItems = orderDao.getItemsForOrder(orderId).first()
                val products = productDao.getAllProducts().first()
                
                orderItems.forEach { item ->
                    val product = products.find { it.id == item.productId }
                    if (product != null) {
                        val totalToDeduct = item.quantity + item.freeQuantity
                        val newStock = (product.stockQuantity - totalToDeduct).coerceAtLeast(0)
                        productDao.updateStock(product.id, newStock)
                    }
                }
                orderDao.updateOrderStatus(orderId, "OUT_FOR_DELIVERY", System.currentTimeMillis())
            }
        }
    }
}

private fun ProductEntity.asDomainModel() = Product(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    unit = unit,
    imageUrl = imageUrl
)
