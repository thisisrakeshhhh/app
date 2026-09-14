package com.routeflow.app.feature.auth

import com.routeflow.app.core.testing.MainDispatcherRule
import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.EmployeeRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DemoLoginViewModelTest {
    @get:Rule val mainDispatcher = MainDispatcherRule()

    @Test
    fun loadingFinishesWithNoEmployeeSignedIn() = runTest {
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository())
        assertTrue(viewModel.state.value.isLoading)
        viewModel.openWorkspace()
        assertNull(viewModel.state.value.activeEmployee)
        runCurrent()
        assertFalse(viewModel.state.value.isLoading)
        assertEquals(4, viewModel.state.value.employees.size)
        assertNull(viewModel.state.value.selectedEmployeeId)
        assertNull(viewModel.state.value.activeEmployee)
    }

    @Test
    fun eachRoleRequiresSelectionAndExplicitContinue() = runTest {
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository())
        runCurrent()
        viewModel.state.value.employees.forEach { employee ->
            viewModel.selectEmployee(employee.id)
            assertNull(viewModel.state.value.activeEmployee)
            viewModel.openWorkspace()
            assertEquals(employee, viewModel.state.value.activeEmployee)
            viewModel.changeRole()
        }
    }

    @Test
    fun invalidEmployeeCannotOpenWorkspace() = runTest {
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository())
        runCurrent()
        viewModel.selectEmployee("untrusted-employee-id")
        viewModel.openWorkspace()
        assertNull(viewModel.state.value.selectedEmployeeId)
        assertNull(viewModel.state.value.activeEmployee)
    }

    @Test
    fun changingRoleClearsSessionAndRequiresNewSelection() = runTest {
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository())
        runCurrent()
        viewModel.selectEmployee("demo-owner")
        viewModel.openWorkspace()
        viewModel.selectEmployee("demo-sales")
        assertEquals("demo-owner", viewModel.state.value.activeEmployee?.id)
        viewModel.changeRole()
        viewModel.openWorkspace()
        assertNull(viewModel.state.value.activeEmployee)
        assertNull(viewModel.state.value.selectedEmployeeId)
    }

    @Test
    fun repositoryFailureIsSafeAndRetryRecovers() = runTest {
        var fail = true
        val repository = object : EmployeeRepository {
            override suspend fun getDemoEmployees(): List<Employee> {
                if (fail) error("private repository diagnostics")
                return FakeEmployeeRepository().getDemoEmployees()
            }
        }
        val viewModel = DemoLoginViewModel(repository)
        runCurrent()
        assertNotNull(viewModel.state.value.errorMessage)
        assertFalse(viewModel.state.value.errorMessage.orEmpty().contains("private"))
        assertFalse(viewModel.state.value.isLoading)
        fail = false
        viewModel.loadEmployees()
        assertTrue(viewModel.state.value.isLoading)
        runCurrent()
        assertNull(viewModel.state.value.errorMessage)
        assertEquals(4, viewModel.state.value.employees.size)
    }

    @Test
    fun emptyDirectoryCannotCreateADemoSession() = runTest {
        val viewModel = DemoLoginViewModel(object : EmployeeRepository {
            override suspend fun getDemoEmployees(): List<Employee> = emptyList()
        })
        runCurrent()
        assertFalse(viewModel.state.value.isLoading)
        assertTrue(viewModel.state.value.employees.isEmpty())
        viewModel.openWorkspace()
        assertNull(viewModel.state.value.activeEmployee)
    }
}
