package com.routeflow.app.data.repository

import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.SessionRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InMemorySessionRepository @Inject constructor() : SessionRepository {
    private val _activeEmployee = MutableStateFlow<Employee?>(null)
    override val activeEmployee: StateFlow<Employee?> = _activeEmployee.asStateFlow()

    override fun login(employee: Employee) {
        _activeEmployee.value = employee
    }

    override fun logout() {
        _activeEmployee.value = null
    }
}
