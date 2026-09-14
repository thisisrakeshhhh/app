package com.routeflow.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.routeflow.app.feature.auth.DemoLoginScreen
import com.routeflow.app.feature.auth.DemoLoginState
import com.routeflow.app.feature.delivery.DeliveryHomeScreen
import com.routeflow.app.feature.owner.OwnerHomeScreen
import com.routeflow.app.feature.sales.SalesHomeScreen
import com.routeflow.app.feature.warehouse.WarehouseHomeScreen

private const val LOGIN_ROUTE = "demo-login"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteFlowApp(
    state: DemoLoginState,
    onSelectEmployee: (String) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    onChangeRole: () -> Unit,
) {
    val navController = rememberNavController()
    val employee = state.activeEmployee
    val destination = employee?.let { RoleDestination.forRole(it.role) }

    // The in-memory demo session is the source of truth, including after process restart.
    LaunchedEffect(destination) {
        val route = destination?.route ?: LOGIN_ROUTE
        if (navController.currentDestination?.route != route) {
            navController.navigate(route) {
                popUpTo(navController.graph.id) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    Scaffold(
        topBar = {
            Column {
                TopAppBar(
                    title = {
                        Column {
                            Text("RouteFlow", style = MaterialTheme.typography.titleLarge)
                            Text(employee?.role?.label ?: "Employee demo",
                                style = MaterialTheme.typography.bodyMedium)
                        }
                    },
                    actions = {
                        if (employee != null) {
                            TextButton(onChangeRole, Modifier.heightIn(min = 48.dp).testTag("change_role")) {
                                Text("Change role", style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    },
                )
                Surface(color = MaterialTheme.colorScheme.secondaryContainer) {
                    Text("Offline demo · Sample data only",
                        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp),
                        style = MaterialTheme.typography.bodyMedium)
                }
            }
        },
    ) { padding ->
        NavHost(navController, startDestination = LOGIN_ROUTE,
            modifier = Modifier.fillMaxSize().padding(padding)) {
            composable(LOGIN_ROUTE) {
                DemoLoginScreen(state, onSelectEmployee, onContinue, onRetry)
            }
            RoleDestination.entries.forEach { home ->
                composable(home.route) {
                    // A restored or stale destination never displays another employee's home.
                    if (employee != null && destination == home) {
                        when (home) {
                            RoleDestination.OWNER -> OwnerHomeScreen(employee)
                            RoleDestination.SALES -> SalesHomeScreen(employee)
                            RoleDestination.WAREHOUSE -> WarehouseHomeScreen(employee)
                            RoleDestination.DELIVERY -> DeliveryHomeScreen(employee)
                        }
                    }
                }
            }
        }
        // Registered after NavHost: Back leaves the demo workspace and clears its role.
        BackHandler(enabled = employee != null, onBack = onChangeRole)
    }
}
