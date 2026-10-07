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
import javax.inject.Inject

data class RetailerListState(
    val beatName: String = "Sector Beat — BEAT-04",
    val isOnShift: Boolean = false,
    val retailers: List<RetailerItemState> = emptyList(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val message: String? = null,
    val error: String? = null
)

data class RetailerItemState(
    val retailer: Retailer,
    val visitStatus: String = "PENDING", // PENDING, IN_PROGRESS, VISITED
    val isHighCreditRisk: Boolean = false
)

@HiltViewModel
class RetailerListViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository,
    private val sessionRepository: SessionRepository,
    private val shiftRepository: ShiftRepository,
    private val visitDao: VisitDao
) : ViewModel() {

    private val _isSaving = MutableStateFlow(false)
    private val _message = MutableStateFlow<String?>(null)
    private val _error = MutableStateFlow<String?>(null)

    private val employeeVisits = sessionRepository.activeEmployee.flatMapLatest { emp ->
        if (emp != null) visitDao.getVisitsByEmployee(emp.id)
        else flowOf(emptyList())
    }

    private val activeVisitFlow = sessionRepository.activeEmployee.flatMapLatest { emp ->
        if (emp != null) visitDao.getActiveVisit(emp.id)
        else flowOf(null)
    }

    val state: StateFlow<RetailerListState> = combine(
        retailerRepository.getRetailersByBeat("BEAT-04"),
        shiftRepository.activeShift,
        employeeVisits,
        activeVisitFlow,
        combine(_isSaving, _message, _error) { isSaving, message, error -> Triple(isSaving, message, error) }
    ) { retailers, shift, visits, activeVisit, (isSaving, message, error) ->
        val isOnShift = shift != null && shift.status == "ON_SHIFT"
        val completedRetailerIds = visits.filter { it.status == "COMPLETED" }.map { it.retailerId }.toSet()
        val activeRetailerId = activeVisit?.retailerId

        val items = retailers.map { retailer ->
            val status = when {
                activeRetailerId == retailer.id -> "IN_PROGRESS"
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

        RetailerListState(
            beatName = "Sector Beat — BEAT-04",
            isOnShift = isOnShift,
            retailers = items,
            isLoading = false,
            isSaving = isSaving,
            message = message,
            error = error
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = RetailerListState(isLoading = true)
    )

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

            val req = CreateRetailerRequest(
                id = "RET-${System.currentTimeMillis().toString().takeLast(6)}",
                name = name.trim(),
                beatId = "BEAT-04",
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
}
