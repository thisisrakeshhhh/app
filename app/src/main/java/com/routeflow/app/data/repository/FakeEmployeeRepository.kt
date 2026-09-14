package com.routeflow.app.data.repository

import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.EmployeeRepository
import javax.inject.Inject

/** Deliberately fake Jaipur records. No passwords, tokens, network or disk access. */
class FakeEmployeeRepository @Inject constructor() : EmployeeRepository {
    override suspend fun getDemoEmployees(): List<Employee> = listOf(
        Employee("demo-owner", "Amit Sharma", EmployeeRole.OWNER),
        Employee("demo-sales", "Rakesh Kumar", EmployeeRole.SALESPERSON),
        Employee("demo-warehouse", "Manoj Kumar", EmployeeRole.WAREHOUSE_MANAGER),
        Employee("demo-delivery", "Suresh Yadav", EmployeeRole.DELIVERY_EXECUTIVE),
    )
}
