package com.routeflow.app.feature.auth

import com.routeflow.app.core.testing.MainDispatcherRule
import com.routeflow.app.data.repository.FakeDemoRepository
import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.SessionRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DemoLoginViewModelTest {
    @get:Rule val mainDispatcher = MainDispatcherRule()

    @Test
    fun validCredentialsCreateSessionWithoutLeavingLoading() = runTest {
        val session = FakeSessionRepository()
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository(), FakeDemoRepository(), session)

        viewModel.onUsernameChange("sales")
        viewModel.onPasswordChange("123")
        viewModel.login()
        advanceUntilIdle()

        assertFalse(viewModel.state.value.isLoading)
        assertEquals("demo-sales", viewModel.state.value.activeEmployee?.id)
        assertNull(viewModel.state.value.errorMessage)
    }

    @Test
    fun invalidCredentialsDoNotCreateSession() = runTest {
        val session = FakeSessionRepository()
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository(), FakeDemoRepository(), session)

        viewModel.onUsernameChange("sales")
        viewModel.onPasswordChange("wrong")
        viewModel.login()
        advanceUntilIdle()

        assertNull(viewModel.state.value.activeEmployee)
        assertEquals("Invalid username or password", viewModel.state.value.errorMessage)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun retryAfterInvalidCredentialsCanSucceed() = runTest {
        val session = FakeSessionRepository()
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository(), FakeDemoRepository(), session)

        viewModel.onUsernameChange("owner")
        viewModel.onPasswordChange("wrong")
        viewModel.login()
        advanceUntilIdle()
        assertNotNull(viewModel.state.value.errorMessage)

        viewModel.onPasswordChange("123")
        viewModel.login()
        advanceUntilIdle()

        assertEquals("demo-owner", viewModel.state.value.activeEmployee?.id)
        assertNull(viewModel.state.value.errorMessage)
        assertFalse(viewModel.state.value.isLoading)
    }

    @Test
    fun logoutClearsSession() = runTest {
        val session = FakeSessionRepository()
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository(), FakeDemoRepository(), session)

        viewModel.onUsernameChange("delivery")
        viewModel.onPasswordChange("123")
        viewModel.login()
        advanceUntilIdle()
        assertEquals("demo-delivery", viewModel.state.value.activeEmployee?.id)

        viewModel.logout()
        assertNull(viewModel.state.value.activeEmployee)
        assertEquals("", viewModel.state.value.username)
        assertEquals("", viewModel.state.value.password)
    }

    @Test
    fun blankCredentialsAreRejectedImmediately() = runTest {
        val session = FakeSessionRepository()
        val viewModel = DemoLoginViewModel(FakeEmployeeRepository(), FakeDemoRepository(), session)

        viewModel.login()

        assertEquals("Please enter credentials", viewModel.state.value.errorMessage)
        assertNull(viewModel.state.value.activeEmployee)
    }

    private fun assertNotNull(value: Any?) {
        assertTrue(value != null)
    }
}

private class FakeSessionRepository : SessionRepository {
    private val active = MutableStateFlow<Employee?>(null)
    override val activeEmployee: StateFlow<Employee?> = active.asStateFlow()

    override fun login(employee: Employee) {
        active.value = employee
    }

    override fun logout() {
        active.value = null
    }
}
