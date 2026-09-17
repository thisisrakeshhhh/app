package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.DemoRepository
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DemoLoginState(
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val activeEmployee: Employee? = null,
    val errorMessage: String? = null,
    val showResetDialog: Boolean = false,
)

@HiltViewModel
class DemoLoginViewModel @Inject constructor(
    private val employeeRepository: EmployeeRepository,
    private val demoRepository: DemoRepository,
    private val sessionRepository: SessionRepository,
) : ViewModel() {

    private val mutableState = MutableStateFlow(DemoLoginState())
    val state = combine(
        mutableState,
        sessionRepository.activeEmployee
    ) { state, activeEmployee ->
        state.copy(activeEmployee = activeEmployee)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DemoLoginState())

    fun onUsernameChange(value: String) {
        mutableState.update { it.copy(username = value, errorMessage = null) }
    }

    fun onPasswordChange(value: String) {
        mutableState.update { it.copy(password = value, errorMessage = null) }
    }

    fun login() {
        val current = mutableState.value
        if (current.username.isBlank() || current.password.isBlank()) {
            mutableState.update { it.copy(errorMessage = "Please enter credentials") }
            return
        }

        mutableState.update { it.copy(isLoading = true) }
        
        viewModelScope.launch {
            try {
                if (!demoRepository.isDemoDataSeeded()) {
                    demoRepository.seedDemoData()
                }

                val role = when {
                    current.username.lowercase() == "owner" && current.password == "123" -> EmployeeRole.OWNER
                    current.username.lowercase() == "sales" && current.password == "123" -> EmployeeRole.SALESPERSON
                    current.username.lowercase() == "warehouse" && current.password == "123" -> EmployeeRole.WAREHOUSE_MANAGER
                    current.username.lowercase() == "delivery" && current.password == "123" -> EmployeeRole.DELIVERY_EXECUTIVE
                    else -> null
                }

                if (role != null) {
                    val employee = employeeRepository.getDemoEmployees().find { it.role == role }
                    if (employee != null) {
                        println("DEBUG: Login successful for ${employee.name}")
                        sessionRepository.login(employee)
                        mutableState.update { it.copy(isLoading = false, username = "", password = "") }
                    } else {
                        println("DEBUG: Employee not found for role $role")
                        mutableState.update { it.copy(isLoading = false, errorMessage = "Internal error: Employee not found") }
                    }
                } else {
                    println("DEBUG: Invalid credentials for ${current.username}")
                    mutableState.update { it.copy(isLoading = false, errorMessage = "Invalid username or password") }
                }
            } catch (e: Exception) {
                mutableState.update { it.copy(isLoading = false, errorMessage = "Login failed: ${e.message}") }
            }
        }
    }

    fun logout() {
        sessionRepository.logout()
        mutableState.update { DemoLoginState() }
    }

    fun toggleResetDialog(show: Boolean) {
        mutableState.update { it.copy(showResetDialog = show) }
    }

    fun resetDemo() {
        mutableState.update { it.copy(showResetDialog = false, isLoading = true) }
        viewModelScope.launch {
            try {
                demoRepository.resetDemoData()
                sessionRepository.logout()
                mutableState.update { it.copy(isLoading = false) }
            } catch (_: Exception) {
                mutableState.update { it.copy(isLoading = false, errorMessage = "Reset failed.") }
            }
        }
    }
}
