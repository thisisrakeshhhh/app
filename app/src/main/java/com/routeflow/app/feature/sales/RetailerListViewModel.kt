package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.domain.model.Retailer
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
import com.routeflow.app.domain.repository.OrderRepository
import java.util.Calendar
import javax.inject.Inject

data class RetailerListState(
    val beatName: String = "Assigned Beat",
    val isOnShift: Boolean = false,
    val retailers: List<RetailerItemState> = emptyList(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val isOfflineCache: Boolean = false,
    val message: String? = null,
    val error: String? = null
)

data class RetailerItemState(
    val retailer: Retailer,
    val visitStatus: String = "PENDING", // PENDING, IN_PROGRESS, VISITED, ORDERED, NO_ORDER
    val isHighCreditRisk: Boolean = false
)

@HiltViewModel
class RetailerListViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository,
    private val sessionRepository: SessionRepository,
    private val shiftRepository: ShiftRepository,
    private val orderRepository: OrderRepository,
    private val visitDao: VisitDao
) : ViewModel() {

    private val _isSaving = MutableStateFlow(false)
    private val _message = MutableStateFlow<String?>(null)
    private val _error = MutableStateFlow<String?>(null)
    private val _isOffline = MutableStateFlow(false)
    private val _isRefreshing = MutableStateFlow(false)

    private val employeeVisits = sessionRepository.activeEmployee.flatMapLatest { emp ->
        if (emp != null) visitDao.getVisitsByEmployee(emp.id)
        else flowOf(emptyList())
    }

    private val activeVisitFlow = sessionRepository.activeEmployee.flatMapLatest { emp ->
        if (emp != null) visitDao.getActiveVisit(emp.id)
        else flowOf(null)
    }

    private val visitInfoFlow = combine(employeeVisits, activeVisitFlow) { visits, activeVisit ->
        visits to activeVisit
    }

    val state: StateFlow<RetailerListState> = combine(
        retailerRepository.getAllRetailers(),
        shiftRepository.activeShift,
        orderRepository.getAllOrders(),
        visitInfoFlow,
        combine(_isSaving, _message, _error, _isOffline, _isRefreshing) { isSaving, message, error, isOffline, isRefreshing ->
            StateExtras(isSaving, message, error, isOffline, isRefreshing)
        }
    ) { retailers, shift, orders, (visits, activeVisit), extras ->
        val isOnShift = shift != null && shift.status == "ON_SHIFT"
        val activeRetailerId = activeVisit?.retailerId

        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val currentEmp = sessionRepository.activeEmployee.value
        val todayOrders = orders.filter { it.createdAt >= todayStart && (currentEmp == null || it.employeeId == currentEmp.id) }
        val orderedRetailerIds = todayOrders.map { it.retailerId }.toSet()

        val completedVisits = visits.filter { it.status == "COMPLETED" }
        val noOrderRetailerIds = completedVisits.filter { !it.noOrderReason.isNullOrBlank() }.map { it.retailerId }.toSet()
        val completedRetailerIds = completedVisits.map { it.retailerId }.toSet()

        val items = retailers.map { retailer ->
            val status = when {
                activeRetailerId == retailer.id -> "IN_PROGRESS"
                orderedRetailerIds.contains(retailer.id) -> "ORDERED"
                noOrderRetailerIds.contains(retailer.id) -> "NO_ORDER"
                completedRetailerIds.contains(retailer.id) -> "VISITED"
                else -> "PENDING"
            }
            val isHighRisk = retailer.outstandingAmountPaise > (retailer.creditLimitPaise * 0.8) && retailer.creditLimitPaise > 0
            RetailerItemState(
                retailer = retailer,
                visitStatus = status,
                isHighCreditRisk = isHighRisk
            )
        }

        val beatName = retailers.firstOrNull()?.beatId?.let { "Assigned Beat — $it" } ?: "Assigned Beat"

        RetailerListState(
            beatName = beatName,
            isOnShift = isOnShift,
            retailers = items,
            isLoading = extras.isRefreshing && items.isEmpty(),
            isSaving = extras.isSaving,
            isOfflineCache = extras.isOffline,
            message = extras.message,
            error = extras.error
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = RetailerListState(isLoading = true)
    )

    init {
        refreshRetailers()
    }

    fun refreshRetailers() {
        viewModelScope.launch {
            _isRefreshing.value = true
            val result = retailerRepository.syncRetailersFromServer()
            _isOffline.value = result.isFailure
            _isRefreshing.value = false
        }
    }

    fun startShift(lat: Double? = null, lng: Double? = null) {
        viewModelScope.launch {
            shiftRepository.startShift(lat, lng)
        }
    }

    fun createRetailer(
        name: String,
        address: String,
        contactNumber: String,
        latitude: Double?,
        longitude: Double?
    ) {
        viewModelScope.launch {
            _isSaving.value = true
            _message.value = null
            _error.value = null

            val currentRetailers = state.value.retailers
            val beatId = currentRetailers.firstOrNull()?.retailer?.beatId ?: "BEAT-01"

            val req = CreateRetailerRequest(
                id = "RET-${System.currentTimeMillis().toString().takeLast(6)}",
                name = name.trim(),
                beatId = beatId,
                address = address.trim(),
                contactNumber = contactNumber.trim(),
                creditLimitPaise = 500000L,
                paymentTermsDays = 7,
                latitude = latitude,
                longitude = longitude
            )
            val result = retailerRepository.createRetailer(req)
            _isSaving.value = false
            if (result.isSuccess) {
                _message.value = "Shop '$name' added successfully!"
                retailerRepository.syncRetailersFromServer()
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Failed to add shop"
            }
        }
    }

    fun clearMessages() {
        _message.value = null
        _error.value = null
    }

    private data class StateExtras(
        val isSaving: Boolean,
        val message: String?,
        val error: String?,
        val isOffline: Boolean,
        val isRefreshing: Boolean
    )
}
