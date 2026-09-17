package com.routeflow.app.feature.delivery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DeliveryHomeState(
    val assignedCount: Int = 0,
    val completedCount: Int = 0,
    val paymentsCollectedPaise: Long = 0,
    val isLoading: Boolean = false
)

data class DeliveryItemState(
    val order: OrderEntity,
    val retailerName: String,
    val retailerAddress: String
)

@HiltViewModel
class DeliveryViewModel @Inject constructor(
    private val database: RouteFlowDatabase,
    private val orderDao: OrderDao,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<DeliveryHomeState> = orderDao.getAllOrders().map { orders ->
        DeliveryHomeState(
            assignedCount = orders.count { it.status == "OUT_FOR_DELIVERY" },
            completedCount = orders.count { it.status == "DELIVERED" },
            paymentsCollectedPaise = 0 // TODO: Sum from payments table
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = DeliveryHomeState(isLoading = true)
    )

    val deliveryList: StateFlow<List<DeliveryItemState>> = combine(
        orderDao.getAllOrders(),
        retailerRepository.getRetailersByBeat("BEAT-04")
    ) { orders, retailers ->
        orders.filter { it.status == "OUT_FOR_DELIVERY" }.map { order ->
            val retailer = retailers.find { it.id == order.retailerId }
            DeliveryItemState(
                order = order,
                retailerName = retailer?.name ?: "Unknown",
                retailerAddress = retailer?.address ?: "Unknown"
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    fun markDelivered(orderId: String, method: String) {
        viewModelScope.launch {
            database.withTransaction {
                val order = orderDao.getOrderById(orderId).map { it }.stateIn(this).value ?: return@withTransaction
                
                // 1. Update order status
                orderDao.updateOrderStatus(orderId, "DELIVERED", System.currentTimeMillis())
                
                // 2. Update retailer outstanding if credit
                if (method == "CREDIT") {
                    val retailer = retailerRepository.getRetailerById(order.retailerId).map { it }.stateIn(this).value
                    if (retailer != null) {
                        val newOutstanding = retailer.outstandingAmountPaise + order.totalAmountPaise
                        database.retailerDao().updateOutstanding(order.retailerId, newOutstanding)
                    }
                }
                
                // 3. Record payment if cash
                if (method == "CASH") {
                    // TODO: Insert into payments table
                }
            }
        }
    }
}
