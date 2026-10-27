package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.PlannedRouteRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.RoadCalculationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

data class OwnerRoutePlannerState(
    val routeDate: String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()),
    val routeName: String = "",
    val salespeople: List<Employee> = emptyList(),
    val selectedSalesperson: Employee? = null,
    val allRetailers: List<Retailer> = emptyList(),
    val stops: List<PlannedRouteStop> = emptyList(),
    val roadMetrics: RoadCalculationResult? = null,
    val routeGeometryCoordinates: List<Pair<Double, Double>> = emptyList(),
    val isCalculatingRoad: Boolean = false,
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null,
    val existingRouteId: String? = null,
    val isPublished: Boolean = false
)

@HiltViewModel
class OwnerRoutePlannerViewModel @Inject constructor(
    private val plannedRouteRepository: PlannedRouteRepository,
    private val retailerRepository: RetailerRepository,
    private val employeeRepository: EmployeeRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(OwnerRoutePlannerState())
    val uiState: StateFlow<OwnerRoutePlannerState> = _uiState.asStateFlow()

    init {
        loadInitialData()
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            try {
                val companyEmpsResult = employeeRepository.getCompanyEmployees()
                val employees = if (companyEmpsResult.isSuccess && !companyEmpsResult.getOrNull().isNullOrEmpty()) {
                    val dtos = companyEmpsResult.getOrDefault(emptyList())
                    dtos.map { dto ->
                        Employee(
                            id = dto.id,
                            name = dto.fullName,
                            role = try { EmployeeRole.valueOf(dto.role) } catch (_: Exception) { EmployeeRole.SALESPERSON }
                        )
                    }
                } else {
                    employeeRepository.getDemoEmployees()
                }

                val sales = employees.filter { it.role == EmployeeRole.SALESPERSON }
                val retailers = retailerRepository.getAllRetailers().first()

                _uiState.update { current ->
                    current.copy(
                        salespeople = sales,
                        selectedSalesperson = sales.firstOrNull(),
                        allRetailers = retailers,
                        routeName = if (current.routeName.isBlank()) "Daily Route - ${current.routeDate}" else current.routeName
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = "Failed to load master data: ${e.message}") }
            }
        }
    }

    fun onDateChanged(date: String) {
        _uiState.update {
            it.copy(
                routeDate = date,
                routeName = if (it.routeName.startsWith("Daily Route")) "Daily Route - $date" else it.routeName
            )
        }
    }

    fun onNameChanged(name: String) {
        _uiState.update { it.copy(routeName = name) }
    }

    fun onSalespersonSelected(employee: Employee) {
        _uiState.update { it.copy(selectedSalesperson = employee) }
    }

    fun onAddRetailerStop(retailer: Retailer) {
        val currentStops = _uiState.value.stops
        if (currentStops.any { it.retailerId == retailer.id }) {
            _uiState.update { it.copy(errorMessage = "Retailer ${retailer.name} is already in the route") }
            return
        }

        val newStop = PlannedRouteStop(
            id = UUID.randomUUID().toString(),
            routeId = _uiState.value.existingRouteId ?: "",
            companyId = retailer.companyId,
            retailerId = retailer.id,
            retailerName = retailer.name,
            stopSequence = currentStops.size + 1,
            address = retailer.address,
            contactNumber = retailer.contactNumber,
            latitude = retailer.latitude,
            longitude = retailer.longitude
        )

        val updatedStops = currentStops + newStop
        _uiState.update { it.copy(stops = updatedStops, errorMessage = null) }
        recalculateRoadRoute(updatedStops)
    }

    fun onMoveStopUp(index: Int) {
        val currentStops = _uiState.value.stops.toMutableList()
        if (index <= 0 || index >= currentStops.size) return

        val temp = currentStops[index]
        currentStops[index] = currentStops[index - 1]
        currentStops[index - 1] = temp

        val renumbered = currentStops.mapIndexed { idx, s -> s.copy(stopSequence = idx + 1) }
        _uiState.update { it.copy(stops = renumbered) }
        recalculateRoadRoute(renumbered)
    }

    fun onMoveStopDown(index: Int) {
        val currentStops = _uiState.value.stops.toMutableList()
        if (index < 0 || index >= currentStops.size - 1) return

        val temp = currentStops[index]
        currentStops[index] = currentStops[index + 1]
        currentStops[index + 1] = temp

        val renumbered = currentStops.mapIndexed { idx, s -> s.copy(stopSequence = idx + 1) }
        _uiState.update { it.copy(stops = renumbered) }
        recalculateRoadRoute(renumbered)
    }

    fun onRemoveStop(index: Int) {
        val currentStops = _uiState.value.stops.toMutableList()
        if (index < 0 || index >= currentStops.size) return

        currentStops.removeAt(index)
        val renumbered = currentStops.mapIndexed { idx, s -> s.copy(stopSequence = idx + 1) }
        _uiState.update { it.copy(stops = renumbered) }
        recalculateRoadRoute(renumbered)
    }

    fun recalculateRoadRoute(stopsToCalculate: List<PlannedRouteStop> = _uiState.value.stops) {
        val validCoords = stopsToCalculate
            .filter { it.latitude != 0.0 && it.longitude != 0.0 }
            .map { Pair(it.latitude, it.longitude) }

        if (validCoords.size < 2) {
            _uiState.update {
                it.copy(
                    roadMetrics = RoadCalculationResult(0.0, 0.0, null, "NONE", false),
                    routeGeometryCoordinates = validCoords,
                    isCalculatingRoad = false
                )
            }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isCalculatingRoad = true) }
            val res = plannedRouteRepository.calculateRoad(validCoords)
            res.fold(
                onSuccess = { metrics ->
                    val coords = if (!metrics.geometry.isNullOrBlank()) {
                        OsrmRoutingHelper.decodePolyline6(metrics.geometry)
                    } else {
                        validCoords
                    }
                    _uiState.update {
                        it.copy(
                            roadMetrics = metrics,
                            routeGeometryCoordinates = coords,
                            isCalculatingRoad = false
                        )
                    }
                },
                onFailure = { err ->
                    _uiState.update {
                        it.copy(
                            isCalculatingRoad = false,
                            errorMessage = "OSRM route calculation fallback: ${err.message}"
                        )
                    }
                }
            )
        }
    }

    fun saveDraft(onSaved: (String) -> Unit) {
        val state = _uiState.value
        if (state.routeName.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Route name is required") }
            return
        }
        val sp = state.selectedSalesperson
        if (sp == null) {
            _uiState.update { it.copy(errorMessage = "Salesperson must be selected") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, errorMessage = null) }
            val result = if (state.existingRouteId == null) {
                plannedRouteRepository.createDraftRoute(
                    routeDate = state.routeDate,
                    name = state.routeName,
                    salespersonId = sp.id,
                    salespersonName = sp.name,
                    stops = state.stops
                )
            } else {
                plannedRouteRepository.updateDraftRoute(
                    routeId = state.existingRouteId,
                    routeDate = state.routeDate,
                    name = state.routeName,
                    salespersonId = sp.id,
                    salespersonName = sp.name,
                    stops = state.stops
                )
            }

            result.fold(
                onSuccess = { saved ->
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            existingRouteId = saved.id,
                            successMessage = "Draft route saved successfully"
                        )
                    }
                    onSaved(saved.id)
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isSaving = false, errorMessage = err.message) }
                }
            )
        }
    }

    fun publishRoute(onPublished: () -> Unit) {
        val state = _uiState.value
        if (state.stops.isEmpty()) {
            _uiState.update { it.copy(errorMessage = "Cannot publish a route with zero stops") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, errorMessage = null) }
            // Ensure draft is saved first if not already saved
            var targetId = state.existingRouteId
            if (targetId == null) {
                val saveRes = plannedRouteRepository.createDraftRoute(
                    routeDate = state.routeDate,
                    name = state.routeName,
                    salespersonId = state.selectedSalesperson!!.id,
                    salespersonName = state.selectedSalesperson.name,
                    stops = state.stops
                )
                if (saveRes.isFailure) {
                    _uiState.update { it.copy(isSaving = false, errorMessage = saveRes.exceptionOrNull()?.message) }
                    return@launch
                }
                targetId = saveRes.getOrThrow().id
            }

            val pubRes = plannedRouteRepository.publishRoute(targetId)
            pubRes.fold(
                onSuccess = { pub ->
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            isPublished = true,
                            successMessage = "Route \"${pub.name}\" published for ${pub.salespersonName}!"
                        )
                    }
                    onPublished()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isSaving = false, errorMessage = err.message) }
                }
            )
        }
    }

    fun clearMessages() {
        _uiState.update { it.copy(errorMessage = null, successMessage = null) }
    }
}
