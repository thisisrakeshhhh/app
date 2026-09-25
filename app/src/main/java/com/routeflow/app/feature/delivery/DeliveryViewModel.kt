package com.routeflow.app.feature.delivery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
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

data class DeliveryDetailState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val success: Boolean = false
)

@HiltViewModel
class DeliveryViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val _detailState = MutableStateFlow(DeliveryDetailState())
    val detailState = _detailState.asStateFlow()

    val state: StateFlow<DeliveryHomeState> = orderRepository.getAllOrders().map { orders ->
        DeliveryHomeState(
            assignedCount = orders.count { it.status == "OUT_FOR_DELIVERY" },
            completedCount = orders.count { it.status == "DELIVERED" },
            paymentsCollectedPaise = 0 // TODO: Real calculation from payments table
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = DeliveryHomeState(isLoading = true)
    )

    val deliveryList: StateFlow<List<DeliveryItemState>> = combine(
        orderRepository.getAllOrders(),
        retailerRepository.getAllRetailers()
    ) { orders, retailers ->
        orders.filter { it.status == "OUT_FOR_DELIVERY" }.map { order ->
            val retailer = retailers.find { it.id == order.retailerId }
            DeliveryItemState(
                order = order,
                retailerName = retailer?.name ?: "Retailer ${order.retailerId}",
                retailerAddress = retailer?.address ?: "Address not available"
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    fun markDelivered(orderId: String, method: String) {
        if (_detailState.value.isLoading) return
        
        _detailState.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            val result = orderRepository.completeDelivery(orderId, method)
            _detailState.update {
                if (result.isSuccess) {
                    it.copy(isLoading = false, success = true)
                } else {
                    it.copy(isLoading = false, error = result.exceptionOrNull()?.message ?: "Delivery failed")
                }
            }
        }
    }

    fun clearError() {
        _detailState.update { it.copy(error = null) }
    }

    fun resetDetailState() {
        _detailState.value = DeliveryDetailState()
    }
}
