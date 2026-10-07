package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.OrderSyncState
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import com.routeflow.app.domain.repository.ShiftRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar
import javax.inject.Inject

data class SalesOrderSummary(
    val id: String,
    val retailerName: String,
    val totalAmountPaise: Long,
    val status: String,
    val syncState: OrderSyncState,
    val syncError: String? = null
)

data class SalesHomeState(
    val beatName: String = "Sector Beat — BEAT-04",
    val isOnShift: Boolean = false,
    val shopsVisited: Int = 0,
    val totalShops: Int = 0,
    val remainingShops: Int = 0,
    val nextShop: Retailer? = null,
    val pendingCollectionPaise: Long = 0,
    val todayOrderValuePaise: Long = 0,
    val monthlyTargetPaise: Long = 50000000, // ₹5,00,000
    val currentAchievedPaise: Long = 12500000, // ₹1,25,000
    val recentOrders: List<SalesOrderSummary> = emptyList(),
    val pendingSyncCount: Int = 0,
    val isSyncing: Boolean = false,
    val isLoading: Boolean = false
)

@HiltViewModel
class SalesViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val shiftRepository: ShiftRepository,
    private val retailerRepository: RetailerRepository,
    private val orderRepository: OrderRepository,
    private val visitDao: VisitDao
) : ViewModel() {

    private val _isSyncing = MutableStateFlow(false)

    private val employeeVisits = sessionRepository.activeEmployee.flatMapLatest { emp ->
        if (emp != null) visitDao.getVisitsByEmployee(emp.id)
        else flowOf(emptyList())
    }

    private val baseState = combine(
        sessionRepository.activeEmployee,
        shiftRepository.activeShift,
        retailerRepository.getAllRetailers(),
        orderRepository.getAllOrders(),
        employeeVisits
    ) { employee, activeShift, allRetailers, orders, visits ->
        val isOnShift = activeShift != null && activeShift.status == "ON_SHIFT"
        val completedRetailerIds = visits
            .filter { it.status == "COMPLETED" }
            .map { it.retailerId }
            .toSet()

        val beatRetailers = allRetailers.filter { it.beatId == "BEAT-04" || it.beatId == "BEAT-01" }.ifEmpty { allRetailers }
        val visitedCount = beatRetailers.count { completedRetailerIds.contains(it.id) }
        val remainingCount = (beatRetailers.size - visitedCount).coerceAtLeast(0)
        val nextShop = beatRetailers.firstOrNull { !completedRetailerIds.contains(it.id) }
        val pendingUdhaar = beatRetailers.sumOf { it.outstandingAmountPaise.coerceAtLeast(0) }

        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val userOrders = orders.filter { it.employeeId == employee?.id }
        val todayOrders = userOrders.filter { it.createdAt >= todayStart }

        SalesHomeState(
            beatName = "Sector Beat — BEAT-04",
            isOnShift = isOnShift,
            shopsVisited = visitedCount,
            totalShops = beatRetailers.size,
            remainingShops = remainingCount,
            nextShop = nextShop,
            pendingCollectionPaise = pendingUdhaar,
            todayOrderValuePaise = todayOrders.sumOf { it.totalAmountPaise },
            isLoading = false
        )
    }

    val state: StateFlow<SalesHomeState> = combine(
        baseState,
        orderRepository.getAllOrders(),
        orderRepository.getPendingSyncOutbox(),
        retailerRepository.getAllRetailers(),
        _isSyncing
    ) { base, orders, pendingSyncs, retailers, isSyncing ->
        val employee = sessionRepository.activeEmployee.value
        val userOrders = orders.filter { it.employeeId == employee?.id }
        val userPendingSyncs = pendingSyncs.filter { it.userId == employee?.id && it.type != "QUARANTINED" }

        val retailerNameMap = retailers.associate { it.id to it.name }
        // Format recent orders
        val recentOrderSummaries = userOrders.sortedByDescending { it.createdAt }.take(5).map { order ->
            val outboxItem = pendingSyncs.firstOrNull { it.payload.contains(order.id) }
            val (syncState, syncError) = when {
                order.status == "NEEDS_ATTENTION" ->
                    OrderSyncState.NEEDS_ATTENTION to (order.rejectionReason ?: outboxItem?.lastError ?: "Validation failure")
                outboxItem != null && outboxItem.type == "PERMANENT_FAILURE" ->
                    OrderSyncState.NEEDS_ATTENTION to (outboxItem.lastError ?: "Permanent failure")
                outboxItem != null ->
                    OrderSyncState.SAVED_OFFLINE to outboxItem.lastError
                else ->
                    OrderSyncState.SYNCED to null
            }
            SalesOrderSummary(
                id = order.id,
                retailerName = retailerNameMap[order.retailerId] ?: order.retailerId,
                totalAmountPaise = order.totalAmountPaise,
                status = order.status,
                syncState = syncState,
                syncError = syncError
            )
        }

        base.copy(
            recentOrders = recentOrderSummaries,
            pendingSyncCount = userPendingSyncs.size,
            isSyncing = isSyncing
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SalesHomeState(isLoading = true)
    )

    fun startShift(lat: Double? = null, lng: Double? = null) {
        viewModelScope.launch {
            shiftRepository.startShift(lat, lng)
        }
    }

    fun syncNow() {
        if (_isSyncing.value) return
        _isSyncing.value = true
        viewModelScope.launch {
            try {
                orderRepository.syncPendingOrders()
            } finally {
                _isSyncing.value = false
            }
        }
    }
}
