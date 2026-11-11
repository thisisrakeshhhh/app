package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.StopStatus
import com.routeflow.app.domain.repository.PlannedRouteRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class SalesRouteState(
    val todayRoute: PlannedRoute? = null,
    val stops: List<PlannedRouteStop> = emptyList(),
    val routeCoordinates: List<Pair<Double, Double>> = emptyList(),
    val selectedStop: PlannedRouteStop? = null,
    val isLoading: Boolean = false,
    val message: String? = null,
    val errorMessage: String? = null
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class SalesRouteViewModel @Inject constructor(
    private val plannedRouteRepository: PlannedRouteRepository,
    private val tokenStorage: TokenStorage
) : ViewModel() {

    private val _message = MutableStateFlow<String?>(null)
    private val _errorMessage = MutableStateFlow<String?>(null)
    private val _selectedStopId = MutableStateFlow<String?>(null)
    private val _isLoading = MutableStateFlow(false)

    private val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    private val companyId = tokenStorage.getCompanyId() ?: "comp_1"
    private val userId = tokenStorage.getUserId() ?: "user_sales"

    val uiState: StateFlow<SalesRouteState> = plannedRouteRepository
        .observeTodayRouteForSalesperson(companyId, userId, today)
        .flatMapLatest { route ->
            if (route == null) {
                flowOf(SalesRouteState(isLoading = false))
            } else {
                plannedRouteRepository.observeStopsForRoute(route.id).map { stops ->
                    val coords = if (!route.routeGeometry.isNullOrBlank()) {
                        OsrmRoutingHelper.decodePolyline6(route.routeGeometry)
                    } else {
                        stops.filter { it.latitude != 0.0 && it.longitude != 0.0 }
                            .map { Pair(it.latitude, it.longitude) }
                    }

                    SalesRouteState(
                        todayRoute = route,
                        stops = stops,
                        routeCoordinates = coords,
                        selectedStop = stops.find { it.id == _selectedStopId.value } ?: stops.firstOrNull(),
                        isLoading = false,
                        message = _message.value,
                        errorMessage = _errorMessage.value
                    )
                }
            }
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = SalesRouteState(isLoading = true)
        )

    fun onSelectStop(stop: PlannedRouteStop) {
        _selectedStopId.value = stop.id
    }

    fun markStopVisited(stopId: String, notes: String?) {
        val routeId = uiState.value.todayRoute?.id ?: return
        viewModelScope.launch {
            _isLoading.value = true
            val res = plannedRouteRepository.updateStopStatus(stopId, routeId, StopStatus.VISITED, notes)
            _isLoading.value = false
            res.fold(
                onSuccess = { _message.value = "Stop marked as visited" },
                onFailure = { _errorMessage.value = "Failed to update stop: ${it.message}" }
            )
        }
    }

    fun markStopSkipped(stopId: String, reason: String?) {
        val routeId = uiState.value.todayRoute?.id ?: return
        viewModelScope.launch {
            _isLoading.value = true
            val res = plannedRouteRepository.updateStopStatus(stopId, routeId, StopStatus.SKIPPED, reason)
            _isLoading.value = false
            res.fold(
                onSuccess = { _message.value = "Stop marked as skipped" },
                onFailure = { _errorMessage.value = "Failed to update stop: ${it.message}" }
            )
        }
    }

    fun clearMessages() {
        _message.value = null
        _errorMessage.value = null
    }
}
