package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.repository.PlannedRouteRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class OwnerRoutesState(
    val selectedDate: String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()),
    val routes: List<PlannedRoute> = emptyList(),
    val selectedRouteForInspection: PlannedRoute? = null,
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val message: String? = null,
    val errorMessage: String? = null
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class OwnerRoutesViewModel @Inject constructor(
    private val plannedRouteRepository: PlannedRouteRepository,
    private val tokenStorage: TokenStorage
) : ViewModel() {

    private val _selectedDate = MutableStateFlow(SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
    private val _selectedRouteIdForInspection = MutableStateFlow<String?>(null)
    private val _isRefreshing = MutableStateFlow(false)
    private val _message = MutableStateFlow<String?>(null)
    private val _errorMessage = MutableStateFlow<String?>(null)
    private val _isLoading = MutableStateFlow(false)

    private data class OperationStatus(
        val isLoading: Boolean,
        val isRefreshing: Boolean,
        val message: String?,
        val errorMessage: String?
    )

    private val _statusFlow = combine(_isLoading, _isRefreshing, _message, _errorMessage) { loading, refreshing, msg, err ->
        OperationStatus(loading, refreshing, msg, err)
    }

    private val _routesWithDate = _selectedDate.flatMapLatest { date ->
        val companyId = tokenStorage.getCompanyId() ?: "comp_1"
        plannedRouteRepository.observeRoutesByDate(companyId, date).map { routes -> date to routes }
    }

    val uiState: StateFlow<OwnerRoutesState> = combine(
        _routesWithDate,
        _selectedRouteIdForInspection,
        _statusFlow
    ) { (date, routes), selectedId, status ->
        OwnerRoutesState(
            selectedDate = date,
            routes = routes,
            selectedRouteForInspection = routes.find { it.id == selectedId },
            isLoading = status.isLoading,
            isRefreshing = status.isRefreshing,
            message = status.message,
            errorMessage = status.errorMessage
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerRoutesState()
    )

    fun onDateSelected(date: String) {
        _selectedDate.value = date
    }

    fun selectRouteForInspection(route: PlannedRoute?) {
        _selectedRouteIdForInspection.value = route?.id
    }

    fun refreshRoute(routeId: String) {
        viewModelScope.launch {
            _isRefreshing.value = true
            val result = plannedRouteRepository.refreshRouteFromServer(routeId)
            _isRefreshing.value = false
            result.fold(
                onSuccess = { _message.value = "Route updated from cloud" },
                onFailure = { _errorMessage.value = "Cloud refresh failed: ${it.message ?: "Network error"}" }
            )
        }
    }

    fun publishRoute(routeId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            val res = plannedRouteRepository.publishRoute(routeId)
            _isLoading.value = false
            res.fold(
                onSuccess = { _message.value = "Route \"${it.name}\" published successfully!" },
                onFailure = { _errorMessage.value = "Failed to publish route: ${it.message}" }
            )
        }
    }

    fun cancelRoute(routeId: String, reason: String) {
        viewModelScope.launch {
            _isLoading.value = true
            val res = plannedRouteRepository.cancelRoute(routeId, reason)
            _isLoading.value = false
            res.fold(
                onSuccess = { _message.value = "Route cancelled." },
                onFailure = { _errorMessage.value = "Failed to cancel route: ${it.message}" }
            )
        }
    }

    fun clearMessages() {
        _message.value = null
        _errorMessage.value = null
    }
}
