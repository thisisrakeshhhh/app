package com.routeflow.app.feature.auth

import com.routeflow.app.core.testing.MainDispatcherRule
import com.routeflow.app.data.repository.FakeDemoRepository
import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.data.repository.InMemorySessionRepository
import com.routeflow.app.domain.model.EmployeeRole
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DemoLoginViewModelTest {
    @get:Rule val mainDispatcher = MainDispatcherRule()

    private val employeeRepo = FakeEmployeeRepository()
    private val demoRepo = FakeDemoRepository()
    private val sessionRepo = InMemorySessionRepository()

    @Test
    fun loginFlow_Success() = runTest {
        val viewModel = DemoLoginViewModel(employeeRepo, demoRepo, sessionRepo)
        
        // Start collection to activate stateIn
        val job = viewModel.state.onEach { }.launchIn(this)
        
        viewModel.onUsernameChange("sales")
        viewModel.onPasswordChange("123")
        viewModel.login()
        
        advanceUntilIdle()
        
        assertNotNull("Employee should be logged in", viewModel.state.value.activeEmployee)
        assertEquals(EmployeeRole.SALESPERSON, viewModel.state.value.activeEmployee?.role)
        assertNull(viewModel.state.value.errorMessage)
        
        job.cancel()
    }

    @Test
    fun loginFlow_InvalidCredentials() = runTest {
        val viewModel = DemoLoginViewModel(employeeRepo, demoRepo, sessionRepo)
        val job = viewModel.state.onEach { }.launchIn(this)
        
        viewModel.onUsernameChange("owner")
        viewModel.onPasswordChange("wrong")
        viewModel.login()
        
        advanceUntilIdle()
        
        assertNull(viewModel.state.value.activeEmployee)
        assertEquals("Invalid username or password", viewModel.state.value.errorMessage)
        
        job.cancel()
    }

    @Test
    fun loginFlow_EmptyCredentials() = runTest {
        val viewModel = DemoLoginViewModel(employeeRepo, demoRepo, sessionRepo)
        val job = viewModel.state.onEach { }.launchIn(this)
        
        viewModel.login()
        
        advanceUntilIdle()
        
        assertNull(viewModel.state.value.activeEmployee)
        assertEquals("Please enter credentials", viewModel.state.value.errorMessage)
        
        job.cancel()
    }

    @Test
    fun logout_ClearsActiveEmployee() = runTest {
        val viewModel = DemoLoginViewModel(employeeRepo, demoRepo, sessionRepo)
        val job = viewModel.state.onEach { }.launchIn(this)
        
        viewModel.onUsernameChange("sales")
        viewModel.onPasswordChange("123")
        viewModel.login()
        advanceUntilIdle()
        assertNotNull(viewModel.state.value.activeEmployee)
        
        viewModel.logout()
        advanceUntilIdle()
        
        assertNull(viewModel.state.value.activeEmployee)
        assertNull(sessionRepo.activeEmployee.value)
        
        job.cancel()
    }
}
