package com.routeflow.app.feature.delivery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
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
    private val orderDao: OrderDao,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<DeliveryHomeState> = orderDao.getAllOrders().map { orders ->
        DeliveryHomeState(
            assignedCount = orders.count { it.status == "OUT_FOR_DELIVERY" },
            completedCount = orders.count { it.status == "DELIVERED" },
            paymentsCollectedPaise = 0 // TODO: Real calculation
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
            // TODO: Record payment, update ledger, etc.
            orderDao.updateOrderStatus(orderId, "DELIVERED", System.currentTimeMillis())
        }
    }
}
