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
    private val _activeEmployee = MutableStateFlow<Employee?>(restoreSession())
    override val activeEmployee: StateFlow<Employee?> = _activeEmployee.asStateFlow()

    private fun restoreSession(): Employee? {
        val token = tokenStorage.getAccessToken() ?: return null
        val id = tokenStorage.getUserId() ?: return null
        val name = tokenStorage.getUserName() ?: return null
        val roleStr = tokenStorage.getUserRole() ?: return null
        val role = try { EmployeeRole.valueOf(roleStr) } catch (e: Exception) { return null }
        return Employee(id = id, name = name, role = role)
    }

    override fun login(employee: Employee) {
        _activeEmployee.value = employee
    }

    override fun logout() {
        _activeEmployee.value = null
        tokenStorage.clear()
    }
}
