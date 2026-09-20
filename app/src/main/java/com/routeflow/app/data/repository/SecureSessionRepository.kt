package com.routeflow.app.data.repository

import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.SessionRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SecureSessionRepository @Inject constructor(
    private val tokenStorage: TokenStorage
) : SessionRepository {
    private val _activeEmployee = MutableStateFlow<Employee?>(null)
    override val activeEmployee: StateFlow<Employee?> = _activeEmployee.asStateFlow()

    // In a real app, we might derive Employee from token or fetch it on start
    // For this milestone, we'll populate it after successful API login
    
    override fun login(employee: Employee) {
        _activeEmployee.value = employee
    }

    override fun logout() {
        _activeEmployee.value = null
        tokenStorage.clear()
    }
}
