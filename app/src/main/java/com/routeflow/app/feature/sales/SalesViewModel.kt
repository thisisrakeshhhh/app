package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class SalesOrderSummary(
    val id: String,
    val retailerName: String,
    val totalAmountPaise: Long,
    val status: String,
    val syncState: com.routeflow.app.domain.model.OrderSyncState,
    val syncError: String? = null
)

data class SalesHomeState(
    val beatName: String = "Sector Beat — BEAT-04",
    val shopsVisited: Int = 0,
    val totalShops: Int = 6,
    val todayOrderValuePaise: Long = 0,
    val monthlyTargetPaise: Long = 50000000, // ₹5,00,000
    val currentAchievedPaise: Long = 12500000, // ₹1,25,000
    val recentOrders: List<SalesOrderSummary> = emptyList(),
    val isLoading: Boolean = false
)

@HiltViewModel
class SalesViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val retailerRepository: RetailerRepository,
    private val orderRepository: com.routeflow.app.domain.repository.OrderRepository
) : ViewModel() {

    val state: StateFlow<SalesHomeState> = combine(
        sessionRepository.activeEmployee,
        retailerRepository.getRetailersByBeat("BEAT-04"),
        retailerRepository.getAllRetailers(),
        orderRepository.getAllOrders(),
        orderRepository.getPendingSyncOutbox()
    ) { employee, beatRetailers, allRetailers, orders, pendingSyncs ->
        val visitedCount = 0 // TODO: Count from visits
        val todayStart = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
        
        val userOrders = orders.filter { it.employeeId == employee?.id }
        val todayOrders = userOrders.filter { it.createdAt >= todayStart }
        
        val recentOrderSummaries = userOrders.sortedByDescending { it.createdAt }.take(5).map { order ->
            val retailer = allRetailers.find { it.id == order.retailerId }
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
            SalesOrderSummary(
                id = order.id,
                retailerName = retailer?.name ?: "Unknown Retailer",
                totalAmountPaise = order.totalAmountPaise,
                status = order.status,
                syncState = syncState,
                syncError = syncError
            )
        }

        SalesHomeState(
            shopsVisited = visitedCount,
            totalShops = beatRetailers.size,
            todayOrderValuePaise = todayOrders.sumOf { it.totalAmountPaise },
            recentOrders = recentOrderSummaries,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SalesHomeState(isLoading = true)
    )
}
