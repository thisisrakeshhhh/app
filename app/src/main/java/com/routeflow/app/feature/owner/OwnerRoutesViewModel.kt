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
    val isLoading: Boolean = false,
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
    private val _message = MutableStateFlow<String?>(null)
    private val _errorMessage = MutableStateFlow<String?>(null)
    private val _isLoading = MutableStateFlow(false)

    val uiState: StateFlow<OwnerRoutesState> = combine(
        _selectedDate,
        _selectedDate.flatMapLatest { date ->
            val companyId = tokenStorage.getCompanyId() ?: "comp_1"
            plannedRouteRepository.observeRoutesByDate(companyId, date)
        },
        _isLoading,
        _message,
        _errorMessage
    ) { date, routes, loading, msg, err ->
        OwnerRoutesState(
            selectedDate = date,
            routes = routes,
            isLoading = loading,
            message = msg,
            errorMessage = err
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerRoutesState()
    )

    fun onDateSelected(date: String) {
        _selectedDate.value = date
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
