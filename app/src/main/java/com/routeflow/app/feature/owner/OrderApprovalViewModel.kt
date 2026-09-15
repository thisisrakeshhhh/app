package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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

data class OrderApprovalState(
    val orders: List<OrderDetailState> = emptyList(),
    val isLoading: Boolean = false,
    val selectedOrderId: String? = null,
    val rejectionReason: String = ""
)

data class OrderDetailState(
    val order: OrderEntity,
    val items: List<OrderItemWithProduct>,
    val retailerName: String
)

data class OrderItemWithProduct(
    val item: OrderItemEntity,
    val product: Product?
)

@HiltViewModel
class OrderApprovalViewModel @Inject constructor(
    private val orderDao: OrderDao,
    private val productDao: ProductDao,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<OrderApprovalState> = combine(
        orderDao.getAllOrders(),
        productDao.getAllProducts()
    ) { orders, productEntities ->
        val details = orders.filter { it.status == "SUBMITTED" }.map { order ->
            val items = orderDao.getItemsForOrder(order.id).first().map { item ->
                val entity = productEntities.find { it.id == item.productId }
                OrderItemWithProduct(item, entity?.asDomainModel())
            }
            val retailer = retailerRepository.getRetailerById(order.retailerId).first()
            OrderDetailState(order, items, retailer?.name ?: "Unknown Retailer")
        }
        OrderApprovalState(orders = details)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OrderApprovalState(isLoading = true)
    )

    fun approveOrder(orderId: String) {
        viewModelScope.launch {
            orderDao.updateOrderStatus(orderId, "APPROVED", System.currentTimeMillis())
        }
    }

    fun rejectOrder(orderId: String, reason: String) {
        viewModelScope.launch {
            orderDao.updateOrderStatus(orderId, "REJECTED", System.currentTimeMillis())
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
