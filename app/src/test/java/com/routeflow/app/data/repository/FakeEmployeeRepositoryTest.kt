package com.routeflow.app.data.repository

import com.routeflow.app.domain.model.EmployeeRole
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FakeEmployeeRepositoryTest {
    @Test
    fun directoryHasOneClearlyMarkedDemoEmployeePerRole() = runTest {
        val employees = FakeEmployeeRepository().getDemoEmployees()
        assertEquals(EmployeeRole.entries.toSet(), employees.map { it.role }.toSet())
        assertEquals(4, employees.size)
        assertEquals(4, employees.map { it.id }.distinct().size)
        assertTrue(employees.all { it.id.startsWith("demo-") && it.name.isNotBlank() })
        assertEquals("Rakesh Kumar", employees.single { it.role == EmployeeRole.SALESPERSON }.name)
    }
}
