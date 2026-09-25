package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.core.database.entity.VisitEntity
import com.routeflow.app.core.network.dto.ShiftDto
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
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SalesTodayState(
    val activeShift: ShiftDto? = null,
    val activeVisit: VisitEntity? = null,
    val retailers: List<Retailer> = emptyList(),
    val completedVisitRetailerIds: Set<String> = emptySet(),
    val isLoading: Boolean = false,
    val message: String? = null,
    val errorMessage: String? = null
)

private data class SalesUiStatus(
    val isLoading: Boolean = false,
    val message: String? = null,
    val errorMessage: String? = null
)

@HiltViewModel
class SalesTodayViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    private val shiftRepository: ShiftRepository,
    private val retailerRepository: RetailerRepository,
    private val visitDao: VisitDao
) : ViewModel() {

    private val _uiStatus = MutableStateFlow(SalesUiStatus())

    val state: StateFlow<SalesTodayState> = combine(
        shiftRepository.activeShift,
        retailerRepository.getAllRetailers(),
        sessionRepository.activeEmployee.flatMapLatest { employee ->
            if (employee != null) visitDao.getActiveVisit(employee.id)
            else flowOf(null)
        },
        sessionRepository.activeEmployee.flatMapLatest { employee ->
            if (employee != null) visitDao.getVisitsByEmployee(employee.id)
            else flowOf(emptyList())
        },
        _uiStatus
    ) { activeShift, retailers, activeVisit, visits, uiStatus ->
        val completedIds = visits
            .filter { it.status == "COMPLETED" }
            .map { it.retailerId }
            .toSet()

        SalesTodayState(
            activeShift = activeShift,
            activeVisit = activeVisit,
            retailers = retailers,
            completedVisitRetailerIds = completedIds,
            isLoading = uiStatus.isLoading,
            message = uiStatus.message,
            errorMessage = uiStatus.errorMessage
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SalesTodayState(isLoading = true)
    )

    init {
        viewModelScope.launch {
            retailerRepository.syncRetailersFromServer()
        }
    }

    fun startShift(lat: Double? = null, lng: Double? = null) {
        viewModelScope.launch {
            _uiStatus.update { it.copy(isLoading = true, errorMessage = null) }
            val result = shiftRepository.startShift(lat, lng)
            if (result.isSuccess) {
                _uiStatus.update { it.copy(isLoading = false, message = "Duty started. Live GPS tracking enabled.") }
            } else {
                _uiStatus.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to start shift") }
            }
        }
    }

    fun endShift(lat: Double? = null, lng: Double? = null) {
        viewModelScope.launch {
            _uiStatus.update { it.copy(isLoading = true, errorMessage = null) }
            val result = shiftRepository.endShift(lat, lng)
            if (result.isSuccess) {
                _uiStatus.update { it.copy(isLoading = false, message = "Duty ended. Shift completed.") }
            } else {
                _uiStatus.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to end shift") }
            }
        }
    }

    fun clearMessages() {
        _uiStatus.update { it.copy(message = null, errorMessage = null) }
    }
}
