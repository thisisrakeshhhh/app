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

data class SalesHomeState(
    val beatName: String = "Mansarovar West — BEAT-04",
    val shopsVisited: Int = 0,
    val totalShops: Int = 6,
    val todayOrderValuePaise: Long = 0,
    val monthlyTargetPaise: Long = 50000000, // ₹5,00,000
    val currentAchievedPaise: Long = 12500000, // ₹1,25,000
    val isLoading: Boolean = false
)

@HiltViewModel
class SalesViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val retailerRepository: RetailerRepository,
    private val orderDao: OrderDao
) : ViewModel() {

    val state: StateFlow<SalesHomeState> = combine(
        sessionRepository.activeEmployee,
        retailerRepository.getRetailersByBeat("BEAT-04"),
        orderDao.getAllOrders()
    ) { employee, retailers, orders ->
        val visitedCount = 0 // TODO: Count from visits
        val todayStart = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
        
        val todayOrders = orders.filter { it.createdAt >= todayStart && it.employeeId == employee?.id }
        
        SalesHomeState(
            shopsVisited = visitedCount,
            totalShops = retailers.size,
            todayOrderValuePaise = todayOrders.sumOf { it.totalAmountPaise }
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SalesHomeState(isLoading = true)
    )
}
