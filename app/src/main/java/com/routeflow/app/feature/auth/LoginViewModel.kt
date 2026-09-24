package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.LoginRequest
import com.routeflow.app.core.network.dto.OrderSubmitRequest
import com.routeflow.app.core.network.dto.toEntity
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import javax.inject.Inject

data class LoginState(
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val isLoggedIn: Boolean = false
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val api: RouteFlowApi,
    private val sessionRepository: SessionRepository,
    private val tokenStorage: TokenStorage,
    private val database: RouteFlowDatabase,
    private val json: Json
) : ViewModel() {

    private val _state = MutableStateFlow(LoginState())
    val state: StateFlow<LoginState> = _state.asStateFlow()

    fun onUsernameChange(value: String) {
        _state.update { it.copy(username = value, errorMessage = null) }
    }

    fun onPasswordChange(value: String) {
        _state.update { it.copy(password = value, errorMessage = null) }
    }

    fun login() {
        val current = _state.value
        if (current.username.isBlank() || current.password.isBlank()) {
            _state.update { it.copy(errorMessage = "Enter credentials") }
            return
        }

        _state.update { it.copy(isLoading = true, errorMessage = null) }

        viewModelScope.launch {
            try {
                val response = api.login(LoginRequest(current.username.trim(), current.password))
                val user = response.user
                if (user != null) {
                    val role = try {
                        EmployeeRole.valueOf(user.role)
                    } catch (e: Exception) {
                        EmployeeRole.SALESPERSON
                    }

                    tokenStorage.saveTokens(response.accessToken, response.refreshToken)
                    tokenStorage.saveUser(user.id, user.name, user.role, user.companyId)

                    // 1. Identify and preserve offline unsynced orders to protect them from deletion
                    val pendingSyncs = database.syncOutboxDao().getAllPendingSyncs()
                    val preservedOrderIds = pendingSyncs.mapNotNull { syncItem ->
                        try {
                            json.decodeFromString<OrderSubmitRequest>(syncItem.payload).order.id
                        } catch (_: Exception) {
                            null
                        }
                    }.distinct()

                    // 2. Synchronize server-authorized catalog and orders into Room cache
                    try {
                        val serverRetailers = api.getRetailers().map { it.toEntity() }
                        val serverProducts = api.getProducts().map { it.toEntity() }
                        val serverOrders = api.getOrders()

                        database.withTransaction {
                            database.retailerDao().deleteAllRetailers()
                            database.productDao().deleteAllProducts()
                            // Safe selective deletion: keep unsynced orders and their items
                            database.orderDao().clearOrdersExcept(preservedOrderIds)

                            database.retailerDao().insertRetailers(serverRetailers)
                            database.productDao().insertProducts(serverProducts)

                            // Restore both order headers and order items
                            serverOrders.forEach { orderDto ->
                                database.orderDao().insertOrder(orderDto.toEntity())
                                try {
                                    val details = api.getOrderDetails(orderDto.id)
                                    val items = details.items.map { it.toEntity() }
                                    database.orderDao().insertOrderItems(items)
                                } catch (_: Exception) {
                                    // Order header preserved if individual detail fetch encounters transient error
                                }
                            }
                        }
                    } catch (syncEx: Exception) {
                        // Do not swallow sync failures: inform user with clear recoverable message
                        _state.update {
                            it.copy(
                                isLoading = false,
                                errorMessage = "Initial catalog sync failed: ${syncEx.message}. Please check connection and retry."
                            )
                        }
                        return@launch
                    }

                    sessionRepository.login(
                        Employee(
                            id = user.id,
                            name = user.name,
                            role = role
                        )
                    )
                    _state.update { it.copy(isLoading = false, isLoggedIn = true) }
                } else {
                    _state.update { it.copy(isLoading = false, errorMessage = "User data missing") }
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, errorMessage = "Login failed: ${e.message}") }
            }
        }
    }
}
