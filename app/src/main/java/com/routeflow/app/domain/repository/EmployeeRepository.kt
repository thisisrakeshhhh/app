package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CreateEmployeeRequest
import com.routeflow.app.core.network.dto.EmployeeDto
import com.routeflow.app.domain.model.Employee

interface EmployeeRepository {
    suspend fun getDemoEmployees(): List<Employee>
    suspend fun getCompanyEmployees(): Result<List<EmployeeDto>>
    suspend fun createEmployee(request: CreateEmployeeRequest): Result<Unit>
    suspend fun deactivateEmployee(id: String): Result<Unit>
}
