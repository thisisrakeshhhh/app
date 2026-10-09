package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.repository.CollectionRepository
import com.routeflow.app.domain.repository.HandoverRepository
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.ShiftRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar
import javax.inject.Inject

data class OperationsData(
    val pendingHandoverCount: Int = 0,
    val pendingHandoverAmountPaise: Long = 0L,
    val staffOnDutyCount: Int = 0
)

data class OwnerHomeState(
    val pendingApprovalsCount: Int = 0,
    val deliveredSalesTodayPaise: Long = 0,
    val cashCollectedTodayPaise: Long = 0,
    val totalOutstandingPaise: Long = 0, // Pending Udhaar
    val lowStockCount: Int = 0,
    val failedDeliveriesCount: Int = 0,
    val pendingHandoverCount: Int = 0,
    val pendingHandoverAmountPaise: Long = 0,
    val staffOnDutyCount: Int = 0,
    val fulfillmentQueueCount: Int = 0,
    val outForDeliveryCount: Int = 0,
    val isLoading: Boolean = false
)

@HiltViewModel
class OwnerViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository,
    private val collectionRepository: CollectionRepository,
    private val handoverRepository: HandoverRepository,
    private val shiftRepository: ShiftRepository
) : ViewModel() {

    private val _opsData = MutableStateFlow(OperationsData())

    init {
        refreshOperations()
    }

    fun refreshOperations() {
        viewModelScope.launch {
            var hoCount = 0
            var hoAmount = 0L
            var onDuty = 0

            val hoResult = handoverRepository.getOwnerHandovers()
            if (hoResult.isSuccess) {
                val pending = hoResult.getOrNull()?.filter { it.status == "PENDING" } ?: emptyList()
                hoCount = pending.size
                hoAmount = pending.sumOf { it.amount_paise }
            }

            val teamResult = shiftRepository.getTeamStatus()
            if (teamResult.isSuccess) {
                onDuty = teamResult.getOrNull()?.count { it.shiftStatus == "ON_SHIFT" } ?: 0
            }

            _opsData.value = OperationsData(
                pendingHandoverCount = hoCount,
                pendingHandoverAmountPaise = hoAmount,
                staffOnDutyCount = onDuty
            )
        }
    }

    val state: StateFlow<OwnerHomeState> = combine(
        orderRepository.getAllOrders(),
        productRepository.getAllProducts(),
        retailerRepository.getAllRetailers(),
        collectionRepository.observeCollections(),
        _opsData
    ) { orders, products, retailers, collections, ops ->
        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val deliveredSalesToday = orders.filter { 
            it.status == "DELIVERED" && it.updatedAt >= todayStart 
        }.sumOf { it.totalAmountPaise }

        val cashCollectedToday = collections.filter {
            it.timestamp >= todayStart && it.paymentMethod == "CASH"
        }.sumOf { it.amountPaise }

        val fulfillmentQueue = orders.count { it.status == "APPROVED" || it.status == "PICKING" || it.status == "PACKED" }
        val outForDelivery = orders.count { it.status == "OUT_FOR_DELIVERY" || it.status == "ASSIGNED_TO_TRIP" }
        val failedDeliveries = orders.count { it.status == "DELIVERY_FAILED" || it.status == "PARTIALLY_DELIVERED" }

        OwnerHomeState(
            pendingApprovalsCount = orders.count { it.status == "SUBMITTED" },
            deliveredSalesTodayPaise = deliveredSalesToday,
            cashCollectedTodayPaise = cashCollectedToday,
            totalOutstandingPaise = retailers.sumOf { it.outstandingAmountPaise },
            lowStockCount = products.count { it.stockQuantity < 10 },
            failedDeliveriesCount = failedDeliveries,
            pendingHandoverCount = ops.pendingHandoverCount,
            pendingHandoverAmountPaise = ops.pendingHandoverAmountPaise,
            staffOnDutyCount = ops.staffOnDutyCount,
            fulfillmentQueueCount = fulfillmentQueue,
            outForDeliveryCount = outForDelivery,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerHomeState(isLoading = true)
    )
}
