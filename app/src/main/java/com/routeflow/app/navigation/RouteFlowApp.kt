package com.routeflow.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.feature.auth.DemoLoginScreen
import com.routeflow.app.feature.auth.DemoLoginState
import com.routeflow.app.feature.delivery.DeliveryDetailScreen
import com.routeflow.app.feature.delivery.DeliveryHomeScreen
import com.routeflow.app.feature.delivery.DeliveryListScreen
import com.routeflow.app.feature.delivery.DeliveryViewModel
import com.routeflow.app.feature.owner.OrderApprovalScreen
import com.routeflow.app.feature.owner.OrderApprovalViewModel
import com.routeflow.app.feature.owner.OwnerHomeScreen
import com.routeflow.app.feature.owner.OwnerViewModel
import com.routeflow.app.feature.sales.OrderBookingScreen
import com.routeflow.app.feature.sales.OrderBookingViewModel
import com.routeflow.app.feature.sales.RetailerListScreen
import com.routeflow.app.feature.sales.RetailerListViewModel
import com.routeflow.app.feature.sales.SalesHomeScreen
import com.routeflow.app.feature.sales.SalesViewModel
import com.routeflow.app.feature.sales.ShopVisitScreen
import com.routeflow.app.feature.sales.ShopVisitViewModel
import com.routeflow.app.feature.warehouse.PickingScreen
import com.routeflow.app.feature.warehouse.PickingViewModel
import com.routeflow.app.feature.warehouse.WarehouseHomeScreen
import com.routeflow.app.feature.warehouse.WarehouseViewModel

private const val LOGIN_ROUTE = "demo-login"
private const val OWNER_APPROVALS = "owner/approvals"
private const val WAREHOUSE_PICKING = "warehouse/picking"
private const val DELIVERY_LIST = "delivery/list"
private const val DELIVERY_DETAIL = "delivery/detail/{orderId}"
private const val SALES_RETAILER_LIST = "sales/retailers"
private const val SALES_SHOP_VISIT = "sales/visit/{retailerId}"
private const val SALES_ORDER_BOOKING = "sales/order/{retailerId}"
private const val SALES_STOCK_CHECK = "sales/stock-check"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteFlowApp(
    state: DemoLoginState,
    onUsernameChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onLogin: () -> Unit,
    onLogout: () -> Unit,
    onRetry: () -> Unit,
    onToggleReset: (Boolean) -> Unit,
    onConfirmReset: () -> Unit,
) {
    val navController = rememberNavController()
    val employee = state.activeEmployee
    val destination = employee?.let { RoleDestination.forRole(it.role) }
    
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStackEntry?.destination?.route

    // Centralized state-driven navigation
    LaunchedEffect(employee) {
        if (employee == null) {
            navController.navigate(LOGIN_ROUTE) {
                popUpTo(0) { inclusive = true }
            }
        }
    }

    LaunchedEffect(destination) {
        val targetRoute = destination?.route
        if (targetRoute != null && (navController.currentDestination?.route == LOGIN_ROUTE || navController.currentDestination == null)) {
            navController.navigate(targetRoute) {
                popUpTo(LOGIN_ROUTE) { inclusive = true }
                launchSingleTop = true
            }
        }
    }

    if (state.showResetDialog) {
        AlertDialog(
            onDismissRequest = { onToggleReset(false) },
            title = { Text("Reset demo data?") },
            text = { Text("This will clear all local demo orders, payments and visits. This cannot be undone.") },
            confirmButton = {
                TextButton(onConfirmReset) { Text("Reset everything", color = RFColors.Error) }
            },
            dismissButton = {
                TextButton(onClick = { onToggleReset(false) }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            if (employee != null) {
                Column {
                    TopAppBar(
                        title = {
                            Column {
                                Text(
                                    "RouteFlow",
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    employee.role.label,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.Accent
                                )
                            }
                        },
                        actions = {
                            TextButton(onLogout, Modifier.testTag("logout")) {
                                Text("Logout", style = MaterialTheme.typography.labelMedium)
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.White,
                            titleContentColor = RFColors.TextPrimary,
                        )
                    )
                    Surface(color = Color(0xFFEFF6FF)) {
                        Text(
                            text = "Demo data only · Jaipur Wholesale Distributors",
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = RFColors.Accent
                        )
                    }
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = LOGIN_ROUTE,
            modifier = Modifier.fillMaxSize().padding(if (employee != null) padding else PaddingValues(0.dp))
        ) {
            composable(LOGIN_ROUTE) {
                DemoLoginScreen(
                    state = state,
                    onUsernameChange = onUsernameChange,
                    onPasswordChange = onPasswordChange,
                    onLogin = onLogin
                )
            }

            composable(RoleDestination.OWNER.route) {
                if (employee != null) {
                    val viewModel: OwnerViewModel = hiltViewModel()
                    val ownerState by viewModel.state.collectAsStateWithLifecycle()
                    OwnerHomeScreen(
                        employee = employee,
                        state = ownerState,
                        onViewApprovals = { navController.navigate(OWNER_APPROVALS) }
                    )
                }
            }

            composable(OWNER_APPROVALS) {
                val viewModel: OrderApprovalViewModel = hiltViewModel()
                val approvalState by viewModel.state.collectAsStateWithLifecycle()
                OrderApprovalScreen(
                    state = approvalState,
                    onApprove = viewModel::approveOrder,
                    onReject = viewModel::rejectOrder
                )
            }

            composable(RoleDestination.SALES.route) {
                if (employee != null) {
                    val salesViewModel: SalesViewModel = hiltViewModel()
                    val salesState by salesViewModel.state.collectAsStateWithLifecycle()
                    SalesHomeScreen(
                        employee = employee,
                        state = salesState,
                        onStartVisits = { navController.navigate(SALES_RETAILER_LIST) }
                    )
                }
            }

            composable(SALES_RETAILER_LIST) {
                val viewModel: RetailerListViewModel = hiltViewModel()
                val salesListState by viewModel.state.collectAsStateWithLifecycle()
                RetailerListScreen(
                    state = salesListState,
                    onRetailerClick = { id -> navController.navigate("sales/visit/$id") }
                )
            }

            composable(
                route = SALES_SHOP_VISIT,
                arguments = listOf(navArgument("retailerId") { type = NavType.StringType })
            ) {
                val viewModel: ShopVisitViewModel = hiltViewModel()
                val visitState by viewModel.state.collectAsStateWithLifecycle()
                ShopVisitScreen(
                    state = visitState,
                    onCheckIn = viewModel::checkIn,
                    onCheckOut = viewModel::checkOut,
                    onCreateOrder = { navController.navigate("sales/order/${visitState.retailer?.id}") },
                    onStockCheck = { /* TODO */ }
                )
            }

            composable(
                route = SALES_ORDER_BOOKING,
                arguments = listOf(navArgument("retailerId") { type = NavType.StringType })
            ) {
                val viewModel: OrderBookingViewModel = hiltViewModel()
                val orderState by viewModel.state.collectAsStateWithLifecycle()
                
                if (orderState.orderSubmittedId != null) {
                    LaunchedEffect(orderState.orderSubmittedId) {
                        navController.popBackStack(SALES_RETAILER_LIST, inclusive = false)
                    }
                } else {
                    OrderBookingScreen(
                        state = orderState,
                        onSearchChange = viewModel::updateSearch,
                        onCategorySelect = viewModel::selectCategory,
                        onQuantityChange = viewModel::updateQuantity,
                        onSubmit = viewModel::submitOrder
                    )
                }
            }

            composable(RoleDestination.WAREHOUSE.route) {
                if (employee != null) {
                    val viewModel: WarehouseViewModel = hiltViewModel()
                    val warehouseState by viewModel.state.collectAsStateWithLifecycle()
                    WarehouseHomeScreen(
                        employee = employee,
                        state = warehouseState,
                        onViewPicking = { navController.navigate(WAREHOUSE_PICKING) }
                    )
                }
            }

            composable(WAREHOUSE_PICKING) {
                val viewModel: PickingViewModel = hiltViewModel()
                val pickingState by viewModel.state.collectAsStateWithLifecycle()
                PickingScreen(
                    state = pickingState,
                    onTogglePicked = viewModel::toggleItemPicked,
                    onStartPicking = viewModel::startPicking,
                    onPacked = viewModel::markPacked,
                    onDispatch = viewModel::dispatchOrder,
                    onErrorShown = viewModel::clearError
                )
            }

            composable(RoleDestination.DELIVERY.route) {
                if (employee != null) {
                    val viewModel: DeliveryViewModel = hiltViewModel()
                    val deliveryHomeState by viewModel.state.collectAsStateWithLifecycle()
                    DeliveryHomeScreen(
                        employee = employee,
                        state = deliveryHomeState,
                        onViewDeliveries = { navController.navigate(DELIVERY_LIST) }
                    )
                }
            }

            composable(DELIVERY_LIST) {
                val viewModel: DeliveryViewModel = hiltViewModel()
                val listState by viewModel.deliveryList.collectAsStateWithLifecycle()
                DeliveryListScreen(
                    state = listState,
                    onDeliveryClick = { id -> navController.navigate("delivery/detail/$id") }
                )
            }

            composable(
                route = DELIVERY_DETAIL,
                arguments = listOf(navArgument("orderId") { type = NavType.StringType })
            ) { backStackEntry ->
                val orderId = backStackEntry.arguments?.getString("orderId")
                val viewModel: DeliveryViewModel = hiltViewModel()
                val listState by viewModel.deliveryList.collectAsStateWithLifecycle()
                val detailState by viewModel.detailState.collectAsStateWithLifecycle()
                val item = listState.find { it.order.id == orderId }
                
                LaunchedEffect(detailState.success) {
                    if (detailState.success) {
                        viewModel.resetDetailState()
                        navController.popBackStack(DELIVERY_LIST, inclusive = false)
                    }
                }

                if (item != null) {
                    DeliveryDetailScreen(
                        orderId = item.order.id,
                        retailerName = item.retailerName,
                        amountPaise = item.order.totalAmountPaise,
                        onDeliver = { method ->
                            viewModel.markDelivered(item.order.id, method)
                        }
                    )
                }
            }
        }
    // Registered after NavHost: Back leaves the demo workspace and clears its role.
    BackHandler(enabled = employee != null) {
        if (navController.previousBackStackEntry != null) {
            navController.popBackStack()
        } else {
            onLogout()
        }
    }
    }
}
