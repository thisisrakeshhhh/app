package com.routeflow.app.domain.repository

import com.routeflow.app.domain.model.Employee
import kotlinx.coroutines.flow.StateFlow

interface SessionRepository {
    val activeEmployee: StateFlow<Employee?>
    fun login(employee: Employee)
    fun logout()
}
