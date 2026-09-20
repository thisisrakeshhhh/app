package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.api.LoginRequest
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LoginState(
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isLoggedIn: Boolean = false
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val api: RouteFlowApi,
    private val sessionRepository: SessionRepository,
    private val tokenStorage: TokenStorage
) : ViewModel() {

    private val _state = MutableStateFlow(LoginState())
    val state: StateFlow<LoginState> = _state.asStateFlow()

    fun onUsernameChange(value: String) {
        _state.update { it.copy(username = value, errorMessage = null) }
    }

    fun onPasswordChange(value: String) {
        _state.update { it.copy(password = value, errorMessage = null) }
    }

    fun login() {
        val current = _state.value
        if (current.username.isBlank() || current.password.isBlank()) {
            _state.update { it.copy(errorMessage = "Enter credentials") }
            return
        }

        _state.update { it.copy(isLoading = true, errorMessage = null) }

        viewModelScope.launch {
            try {
                val response = api.login(LoginRequest(current.username, current.password))
                tokenStorage.saveTokens(response.access_token, response.refresh_token)
                
                val user = response.user
                if (user != null) {
                    val role = try {
                        EmployeeRole.valueOf(user.role)
                    } catch (e: Exception) {
                        EmployeeRole.SALESPERSON // Fallback
                    }
                    
                    sessionRepository.login(
                        Employee(
                            id = user.id,
                            name = user.name,
                            role = role
                        )
                    )
                    _state.update { it.copy(isLoading = false, isLoggedIn = true) }
                } else {
                    _state.update { it.copy(isLoading = false, errorMessage = "User data missing") }
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = "Login failed: ${e.message}") }
            }
        }
    }
}
