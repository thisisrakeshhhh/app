package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.DemoRepository
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
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

    val state = combine(mutableState, sessionRepository.activeEmployee) { state, activeEmployee ->
        state.copy(activeEmployee = activeEmployee)
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        DemoLoginState()
    )

    init {
        // Seed demo data off the login click path. The first screen should never block
        // on Room writes just to establish a local demo session.
        viewModelScope.launch {
            runCatching {
                if (!demoRepository.isDemoDataSeeded()) {
                    demoRepository.seedDemoData()
                }
            }
        }
    }

    fun onUsernameChange(value: String) {
        mutableState.update { it.copy(username = value, errorMessage = null) }
    }

    fun onPasswordChange(value: String) {
        mutableState.update { it.copy(password = value, errorMessage = null) }
    }

    fun login() {
        val current = mutableState.value
        val username = current.username.trim().lowercase()
        val password = current.password

        if (username.isBlank() || password.isBlank()) {
            mutableState.update { it.copy(errorMessage = "Please enter credentials") }
            return
        }

        // This is intentionally a LOCAL DEMO credential check. It is not production
        // authentication and must be replaced by server-side authentication before release.
        val role = when {
            username == "owner" && password == "123" -> EmployeeRole.OWNER
            username == "sales" && password == "123" -> EmployeeRole.SALESPERSON
            username == "warehouse" && password == "123" -> EmployeeRole.WAREHOUSE_MANAGER
            username == "delivery" && password == "123" -> EmployeeRole.DELIVERY_EXECUTIVE
            else -> null
        }

        if (role == null) {
            mutableState.update {
                it.copy(isLoading = false, errorMessage = "Invalid username or password")
            }
            return
        }

        mutableState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                // Employee lookup is local and tiny; no Room seed or network operation is
                // required before navigation, so login remains responsive.
                val employee = employeeRepository.getDemoEmployees().firstOrNull { it.role == role }
                if (employee == null) {
                    mutableState.update {
                        it.copy(isLoading = false, errorMessage = "Account is unavailable")
                    }
                    return@launch
                }

                sessionRepository.login(employee)
                mutableState.update {
                    it.copy(isLoading = false, username = "", password = "", errorMessage = null)
                }
            } catch (_: Exception) {
                mutableState.update {
                    it.copy(isLoading = false, errorMessage = "Login failed. Please try again.")
                }
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
        mutableState.update { it.copy(showResetDialog = false, isLoading = true, errorMessage = null) }
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
