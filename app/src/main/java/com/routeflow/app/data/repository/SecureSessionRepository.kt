package com.routeflow.app.data.repository

import android.content.Context
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.location.ShiftTrackingService
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Provider
import javax.inject.Singleton

@Singleton
class SecureSessionRepository @Inject constructor(
    private val tokenStorage: TokenStorage,
    @ApplicationContext private val context: Context,
    private val databaseProvider: Provider<RouteFlowDatabase>
) : SessionRepository {
    private val _activeEmployee = MutableStateFlow<Employee?>(restoreSession())
    override val activeEmployee: StateFlow<Employee?> = _activeEmployee.asStateFlow()

    private fun restoreSession(): Employee? {
        val token = tokenStorage.getAccessToken() ?: return null
        val id = tokenStorage.getUserId() ?: return null
        val name = tokenStorage.getUserName() ?: return null
        val roleStr = tokenStorage.getUserRole() ?: return null
        val role = try { EmployeeRole.valueOf(roleStr) } catch (e: Exception) { return null }
        return Employee(id = id, name = name, role = role)
    }

    override fun login(employee: Employee) {
        _activeEmployee.value = employee
    }

    override fun logout() {
        ShiftTrackingService.stop(context)
        context.getSharedPreferences("rf_shift_prefs", Context.MODE_PRIVATE).edit().clear().apply()
        _activeEmployee.value = null
        tokenStorage.clear()
        try {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    databaseProvider.get().clearAllTables()
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }
}
