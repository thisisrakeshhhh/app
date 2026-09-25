package com.routeflow.app.data.repository

import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateEmployeeRequest
import com.routeflow.app.core.network.dto.EmployeeDto
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.EmployeeRepository
import java.lang.reflect.Proxy
import javax.inject.Inject

/** Deliberately fake Jaipur records for demo login, plus network backing for owner employee management. */
class FakeEmployeeRepository @Inject constructor(
    private val api: RouteFlowApi
) : EmployeeRepository {

    /** Zero-arg constructor for local unit tests without Dagger */
    constructor() : this(
        Proxy.newProxyInstance(
            RouteFlowApi::class.java.classLoader,
            arrayOf(RouteFlowApi::class.java)
        ) { _, _, _ -> null } as RouteFlowApi
    )

    override suspend fun getDemoEmployees(): List<Employee> = listOf(
        Employee("demo-owner", "Amit Sharma", EmployeeRole.OWNER),
        Employee("demo-sales", "Rakesh Kumar", EmployeeRole.SALESPERSON),
        Employee("demo-warehouse", "Manoj Kumar", EmployeeRole.WAREHOUSE_MANAGER),
        Employee("demo-delivery", "Suresh Yadav", EmployeeRole.DELIVERY_EXECUTIVE),
    )

    override suspend fun getCompanyEmployees(): Result<List<EmployeeDto>> = try {
        Result.success(api.getEmployees())
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun createEmployee(request: CreateEmployeeRequest): Result<Unit> = try {
        val resp = api.createEmployee(request)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to create employee"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun deactivateEmployee(id: String): Result<Unit> = try {
        val resp = api.deactivateEmployee(id)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to deactivate employee"))
    } catch (e: Exception) {
        Result.failure(e)
    }
}
