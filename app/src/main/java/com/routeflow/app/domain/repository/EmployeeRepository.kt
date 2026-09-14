package com.routeflow.app.domain.repository

import com.routeflow.app.domain.model.Employee

/** Demo directory boundary. This is not authentication or a role authorization service. */
interface EmployeeRepository {
    suspend fun getDemoEmployees(): List<Employee>
}
