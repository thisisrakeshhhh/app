package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.util.Calendar
import javax.inject.Inject

data class OwnerHomeState(
    val pendingApprovalsCount: Int = 0,
    val deliveredSalesTodayPaise: Long = 0,
    val totalOutstandingPaise: Long = 0,
    val lowStockCount: Int = 0,
    val isLoading: Boolean = false
)

@HiltViewModel
class OwnerViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<OwnerHomeState> = combine(
        orderRepository.getAllOrders(),
        productRepository.getAllProducts(),
        retailerRepository.getRetailersByBeat("BEAT-04")
    ) { orders, products, retailers ->
        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val deliveredSalesToday = orders.filter { 
            it.status == "DELIVERED" && it.updatedAt >= todayStart 
        }.sumOf { it.totalAmountPaise }

        OwnerHomeState(
            pendingApprovalsCount = orders.count { it.status == "SUBMITTED" },
            lowStockCount = products.count { it.stockQuantity < 10 },
            totalOutstandingPaise = retailers.sumOf { it.outstandingAmountPaise },
            deliveredSalesTodayPaise = deliveredSalesToday,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerHomeState(isLoading = true)
    )
}
