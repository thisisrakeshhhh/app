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
    val employeeName: String = "",
    val assignedBeat: String = "BEAT-01",
    val activeShift: ShiftDto? = null,
    val activeVisit: VisitEntity? = null,
    val retailers: List<Retailer> = emptyList(),
    val completedVisitRetailerIds: Set<String> = emptySet(),
    val todayOrdersAmountPaise: Long = 0L,
    val todayCollectionsAmountPaise: Long = 0L,
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
    private val visitDao: VisitDao,
    private val orderDao: com.routeflow.app.core.database.dao.OrderDao,
    private val collectionRecordDao: com.routeflow.app.core.database.dao.CollectionRecordDao
) : ViewModel() {

    private val _uiStatus = MutableStateFlow(SalesUiStatus())

    val state: StateFlow<SalesTodayState> = combine(
        sessionRepository.activeEmployee,
        shiftRepository.activeShift,
        retailerRepository.getAllRetailers(),
        orderDao.getAllOrders(),
        _uiStatus
    ) { employee, activeShift, retailers, orders, uiStatus ->
        val empId = employee?.id.orEmpty()
        
        val startOfDay = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis

        val todayOrdersPaise = orders
            .filter { it.createdAt >= startOfDay }
            .sumOf { it.totalAmountPaise }

        val activeVisit = if (empId.isNotBlank()) visitDao.getActiveVisitSync(empId) else null
        val visits = if (empId.isNotBlank()) visitDao.getVisitsByEmployeeSync(empId) else emptyList()
        val completedIds = visits
            .filter { it.status == "COMPLETED" }
            .map { it.retailerId }
            .toSet()

        val collections = if (empId.isNotBlank()) {
            collectionRecordDao.getCollectionsByCollector(empId)
        } else emptyList()
        val todayCollectionsPaise = collections
            .filter { it.timestamp >= startOfDay }
            .sumOf { it.amountPaise }

        val beatName = retailers.firstOrNull { it.beatId.isNotBlank() }?.beatId ?: "BEAT-01"

        SalesTodayState(
            employeeName = employee?.name ?: "Sales Executive",
            assignedBeat = beatName,
            activeShift = activeShift,
            activeVisit = activeVisit,
            retailers = retailers,
            completedVisitRetailerIds = completedIds,
            todayOrdersAmountPaise = todayOrdersPaise,
            todayCollectionsAmountPaise = todayCollectionsPaise,
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

    fun syncRetailers() {
        viewModelScope.launch {
            _uiStatus.update { it.copy(isLoading = true, errorMessage = null) }
            val result = retailerRepository.syncRetailersFromServer()
            _uiStatus.update {
                it.copy(
                    isLoading = false,
                    message = if (result.isSuccess) "Shops updated" else null,
                    errorMessage = if (result.isFailure) "Sync failed (Offline copy in use)" else null
                )
            }
        }
    }

    fun clearMessages() {
        _uiStatus.update { it.copy(message = null, errorMessage = null) }
    }
}
