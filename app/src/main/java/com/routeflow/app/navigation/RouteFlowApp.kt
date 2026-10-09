package com.routeflow.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Today
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
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
import com.routeflow.app.BuildConfig
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.feature.auth.DemoLoginScreen
import com.routeflow.app.feature.auth.DemoLoginState
import com.routeflow.app.feature.auth.DemoLoginViewModel
import com.routeflow.app.feature.auth.LoginScreen
import com.routeflow.app.feature.auth.LoginViewModel
import com.routeflow.app.feature.delivery.DeliveryDetailScreen
import com.routeflow.app.feature.delivery.DeliveryHandoverScreen
import com.routeflow.app.feature.delivery.DeliveryHandoverViewModel
import com.routeflow.app.feature.delivery.DeliveryHomeScreen
import com.routeflow.app.feature.delivery.DeliveryListScreen
import com.routeflow.app.feature.delivery.DeliveryProfileScreen
import com.routeflow.app.feature.delivery.DeliveryViewModel
import com.routeflow.app.feature.owner.OrderApprovalScreen
import com.routeflow.app.feature.owner.OrderApprovalViewModel
import com.routeflow.app.feature.owner.OwnerBeatsScreen
import com.routeflow.app.feature.owner.OwnerBusinessHubScreen
import com.routeflow.app.feature.owner.OwnerCollectionsScreen
import com.routeflow.app.feature.owner.OwnerEmployeesScreen
import com.routeflow.app.feature.owner.OwnerFieldActivityScreen
import com.routeflow.app.feature.owner.OwnerFieldActivityViewModel
import com.routeflow.app.feature.owner.OwnerHandoversScreen
import com.routeflow.app.feature.owner.OwnerHomeScreen
import com.routeflow.app.feature.owner.OwnerMasterViewModel
import com.routeflow.app.feature.owner.OwnerProductsScreen
import com.routeflow.app.feature.owner.OwnerRetailersScreen
import com.routeflow.app.feature.owner.OwnerReturnsScreen
import com.routeflow.app.feature.owner.OwnerTeamScreen
import com.routeflow.app.feature.owner.OwnerTeamViewModel
import com.routeflow.app.feature.owner.OwnerViewModel
import com.routeflow.app.feature.sales.OrderBookingScreen
import com.routeflow.app.feature.sales.OrderBookingViewModel
import com.routeflow.app.feature.sales.RetailerListScreen
import com.routeflow.app.feature.sales.RetailerListViewModel
import com.routeflow.app.feature.sales.SalesCollectionsScreen
import com.routeflow.app.feature.sales.SalesHomeScreen
import com.routeflow.app.feature.sales.SalesProfileScreen
import com.routeflow.app.feature.sales.SalesTodayScreen
import com.routeflow.app.feature.sales.SalesTodayViewModel
import com.routeflow.app.feature.sales.SalesViewModel
import com.routeflow.app.feature.sales.ShopVisitScreen
import com.routeflow.app.feature.sales.ShopVisitViewModel
import com.routeflow.app.feature.sales.StockCheckScreen
import com.routeflow.app.feature.sales.StockCheckViewModel
import com.routeflow.app.feature.warehouse.BarcodeScannerModal
import com.routeflow.app.feature.warehouse.DispatchBatchScreen
import com.routeflow.app.feature.warehouse.PickingScreen
import com.routeflow.app.feature.warehouse.PickingViewModel
import com.routeflow.app.feature.warehouse.WarehouseHomeScreen
import com.routeflow.app.feature.warehouse.WarehouseReturnsScreen
import com.routeflow.app.feature.warehouse.WarehouseStockScreen
import com.routeflow.app.feature.warehouse.WarehouseViewModel

private const val DEMO_LOGIN_ROUTE = "demo-login"
private const val REAL_LOGIN_ROUTE = "login"

// Owner Routes
private const val OWNER_APPROVALS = "owner/approvals"
private const val OWNER_BUSINESS_HUB = "owner/business"
private const val OWNER_PRODUCTS = "owner/products"
private const val OWNER_RETAILERS = "owner/retailers"
private const val OWNER_EMPLOYEES = "owner/employees"
private const val OWNER_BEATS = "owner/beats"
private const val OWNER_TEAM = "owner/team"
private const val OWNER_ACTIVITY = "owner/activity"
private const val OWNER_HANDOVERS = "owner/handovers"
private const val OWNER_COLLECTIONS = "owner/collections"
private const val OWNER_RETURNS = "owner/returns"

// Admin / Team Leader Routes — delegated subset of Owner operations
private const val ADMIN_APPROVALS = "admin/approvals"
private const val ADMIN_TEAM = "admin/team"
private const val ADMIN_ACTIVITY = "admin/activity"

// Sales Routes
private const val SALES_TODAY = "sales/today"
private const val SALES_RETAILER_LIST = "sales/retailers"
private const val SALES_SHOP_VISIT = "sales/visit/{retailerId}"
private const val SALES_STOCK_CHECK = "sales/stock-check/{retailerId}"
private const val SALES_ORDER_BOOKING = "sales/order/{retailerId}"
private const val SALES_COLLECTIONS = "sales/collections"
private const val SALES_PROFILE = "sales/profile"

// Warehouse Routes
private const val WAREHOUSE_PICKING = "warehouse/picking"
private const val WAREHOUSE_STOCK = "warehouse/stock"
private const val WAREHOUSE_DISPATCH = "warehouse/dispatch"
private const val WAREHOUSE_RETURNS = "warehouse/returns"

// Delivery Routes
private const val DELIVERY_LIST = "delivery/list"
private const val DELIVERY_DETAIL = "delivery/detail/{orderId}"
private const val DELIVERY_HANDOVER = "delivery/handover"
private const val DELIVERY_PROFILE = "delivery/profile"

private data class NavItem(
    val route: String,
    val labelRes: Int,
    val icon: ImageVector
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteFlowApp(
    activeEmployee: com.routeflow.app.domain.model.Employee? = null,
    demoState: DemoLoginState,
    onDemoLogout: () -> Unit,
    onToggleReset: (Boolean) -> Unit,
    onConfirmReset: () -> Unit,
    currentLanguage: String = "en",
    onLanguageChange: (String) -> Unit = {}
) {
    val navController = rememberNavController()
    val employee = activeEmployee ?: demoState.activeEmployee
    val destination = employee?.let { RoleDestination.forRole(it.role) }

    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStackEntry?.destination?.route

    var isDemoMode by remember { mutableStateOf(false) }
    val startRoute = if (isDemoMode) DEMO_LOGIN_ROUTE else REAL_LOGIN_ROUTE
    val initialRoute = remember {
        destination?.route ?: startRoute
    }

    // Centralized state-driven navigation
    LaunchedEffect(employee) {
        if (employee == null) {
            val loginRoute = if (isDemoMode) DEMO_LOGIN_ROUTE else REAL_LOGIN_ROUTE
            if (navController.currentDestination?.route != loginRoute) {
                navController.navigate(loginRoute) {
                    popUpTo(0) { inclusive = true }
                    launchSingleTop = true
                }
            }
        }
    }

    var lastNavigatedRole by remember { mutableStateOf<com.routeflow.app.domain.model.EmployeeRole?>(null) }
    LaunchedEffect(employee?.role) {
        val currentRole = employee?.role
        if (currentRole != null && currentRole != lastNavigatedRole) {
            lastNavigatedRole = currentRole
            val targetRoute = destination?.route
            if (targetRoute != null) {
                navController.navigate(targetRoute) {
                    popUpTo(0) { inclusive = true }
                    launchSingleTop = true
                }
            }
        }
    }

    if (demoState.showResetDialog) {
        AlertDialog(
            onDismissRequest = { onToggleReset(false) },
            title = { Text("Reset demo data?") },
            text = { Text("This will clear all local demo orders, payments and visits. This cannot be undone.") },
            confirmButton = {
                TextButton(onConfirmReset) { Text("Reset everything", color = RFColors.Error) }
            },
            dismissButton = {
                TextButton(onClick = { onToggleReset(false) }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // Role-specific 5 bottom navigation tabs
    val bottomNavItems = remember(employee?.role) {
        when (employee?.role) {
            EmployeeRole.OWNER -> listOf(
                NavItem(RoleDestination.OWNER.route, R.string.tab_home, Icons.Default.Home),
                NavItem(OWNER_APPROVALS, R.string.tab_orders, Icons.Default.CheckCircle),
                NavItem(OWNER_BUSINESS_HUB, R.string.tab_business, Icons.Default.Business),
                NavItem(OWNER_TEAM, R.string.tab_team, Icons.Default.People),
                NavItem(OWNER_ACTIVITY, R.string.tab_reports, Icons.Default.Assessment)
            )
            EmployeeRole.ADMIN -> listOf(
                NavItem(RoleDestination.ADMIN.route, R.string.tab_home, Icons.Default.Home),
                NavItem(ADMIN_APPROVALS, R.string.tab_orders, Icons.Default.CheckCircle),
                NavItem(ADMIN_TEAM, R.string.tab_team, Icons.Default.People),
                NavItem(ADMIN_ACTIVITY, R.string.tab_reports, Icons.Default.Assessment)
            )
            EmployeeRole.SALESPERSON -> listOf(
                NavItem(RoleDestination.SALES.route, R.string.tab_today, Icons.Default.Today),
                NavItem(SALES_RETAILER_LIST, R.string.tab_shops, Icons.Default.Store),
                NavItem(SALES_ORDER_BOOKING.replace("{retailerId}", "all"), R.string.tab_order_booking, Icons.Default.ShoppingCart),
                NavItem(SALES_COLLECTIONS, R.string.tab_collections, Icons.Default.Payments),
                NavItem(SALES_PROFILE, R.string.tab_profile, Icons.Default.Person)
            )
            EmployeeRole.WAREHOUSE_MANAGER -> listOf(
                NavItem(RoleDestination.WAREHOUSE.route, R.string.tab_dashboard, Icons.Default.Home),
                NavItem(WAREHOUSE_STOCK, R.string.tab_stock, Icons.Default.Inventory2),
                NavItem(WAREHOUSE_PICKING, R.string.tab_pick_pack, Icons.Default.Checklist),
                NavItem(WAREHOUSE_DISPATCH, R.string.tab_dispatch, Icons.Default.LocalShipping),
                NavItem(WAREHOUSE_RETURNS, R.string.tab_returns, Icons.Default.AssignmentReturn)
            )
            EmployeeRole.DELIVERY_EXECUTIVE -> listOf(
                NavItem(RoleDestination.DELIVERY.route, R.string.tab_trips, Icons.Default.Route),
                NavItem(DELIVERY_LIST, R.string.tab_deliveries, Icons.Default.LocalShipping),
                NavItem(DELIVERY_HANDOVER, R.string.tab_cash, Icons.Default.AccountBalanceWallet),
                NavItem(DELIVERY_PROFILE, R.string.tab_profile, Icons.Default.Person)
            )
            null -> emptyList()
        }
    }

    Scaffold(
        topBar = {
            if (employee != null) {
                Column {
                    if (employee.role == EmployeeRole.SALESPERSON) {
                        val isSubScreen = currentRoute?.startsWith("sales/visit") == true ||
                                          currentRoute?.startsWith("sales/order") == true ||
                                          currentRoute?.startsWith("sales/stock-check") == true ||
                                          currentRoute == SALES_TODAY
                        val salesTitle = when {
                            currentRoute == RoleDestination.SALES.route -> "Today's Route"
                            currentRoute == SALES_TODAY -> "Today's Route"
                            currentRoute == SALES_RETAILER_LIST -> "Assigned Shops"
                            currentRoute == SALES_COLLECTIONS -> "Collections"
                            currentRoute == SALES_PROFILE -> "Profile"
                            currentRoute?.startsWith("sales/order") == true -> "Order Booking"
                            currentRoute?.startsWith("sales/visit") == true -> "Shop Visit"
                            currentRoute?.startsWith("sales/stock-check") == true -> "Stock Check"
                            else -> "RouteFlow Sales"
                        }
                        TopAppBar(
                            navigationIcon = {
                                if (isSubScreen) {
                                    IconButton(onClick = { navController.popBackStack() }) {
                                        Icon(
                                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                            contentDescription = "Back",
                                            tint = RFColors.TextPrimary
                                        )
                                    }
                                }
                            },
                            title = {
                                Text(
                                    salesTitle,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                            },
                            actions = {
                                TextButton(onClick = {
                                    isDemoMode = false
                                    onDemoLogout()
                                }, Modifier.testTag("logout")) {
                                    Text(
                                        stringResource(R.string.logout),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = RFColors.Error,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = Color.White,
                                titleContentColor = RFColors.TextPrimary,
                            )
                        )
                    } else if (employee.role == EmployeeRole.WAREHOUSE_MANAGER) {
                        TopAppBar(
                            title = {
                                Text(
                                    "Jaipur Godown Depot",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                            },
                            actions = {
                                TextButton(onClick = {
                                    isDemoMode = false
                                    onDemoLogout()
                                }, Modifier.testTag("logout")) {
                                    Text(
                                        stringResource(R.string.logout),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = RFColors.Error,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = Color.White,
                                titleContentColor = RFColors.TextPrimary,
                            )
                        )
                    } else if (employee.role == EmployeeRole.DELIVERY_EXECUTIVE) {
                        val isSubScreen = currentRoute?.startsWith("delivery/detail") == true
                        TopAppBar(
                            navigationIcon = {
                                if (isSubScreen) {
                                    IconButton(onClick = { navController.popBackStack() }) {
                                        Icon(
                                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                            contentDescription = "Back",
                                            tint = RFColors.TextPrimary
                                        )
                                    }
                                }
                            },
                            title = {
                                Text(
                                    "Jaipur Delivery Fleet",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                            },
                            actions = {
                                TextButton(onClick = {
                                    isDemoMode = false
                                    onDemoLogout()
                                }, Modifier.testTag("logout")) {
                                    Text(
                                        stringResource(R.string.logout),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = RFColors.Error,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = Color.White,
                                titleContentColor = RFColors.TextPrimary,
                            )
                        )
                    } else {
                        TopAppBar(
                            title = {
                                Column {
                                    Text(
                                        "RouteFlow",
                                        style = MaterialTheme.typography.titleLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        stringResource(employee.role.labelRes),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = RFColors.Accent,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                }
                            },
                            actions = {
                                TextButton(onClick = {
                                    isDemoMode = false
                                    onDemoLogout()
                                }, Modifier.testTag("logout")) {
                                    Text(
                                        stringResource(R.string.logout),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = RFColors.Error,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = Color.White,
                                titleContentColor = RFColors.TextPrimary,
                            )
                        )
                    }
                }
            }
        },
        bottomBar = {
            if (employee != null && bottomNavItems.isNotEmpty()) {
                NavigationBar(
                    containerColor = Color.White,
                    tonalElevation = 8.dp
                ) {
                    bottomNavItems.forEach { item ->
                        val isSelected = when (item.route) {
                            RoleDestination.SALES.route, SALES_TODAY ->
                                currentRoute == RoleDestination.SALES.route || currentRoute == SALES_TODAY
                            SALES_RETAILER_LIST ->
                                currentRoute == SALES_RETAILER_LIST || currentRoute?.startsWith("sales/visit") == true
                            SALES_ORDER_BOOKING.replace("{retailerId}", "all"), SALES_ORDER_BOOKING ->
                                currentRoute?.startsWith("sales/order") == true || currentRoute?.startsWith("sales/stock-check") == true
                            SALES_COLLECTIONS ->
                                currentRoute == SALES_COLLECTIONS
                            SALES_PROFILE ->
                                currentRoute == SALES_PROFILE
                            else -> currentRoute == item.route
                        }
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = {
                                if (!isSelected) {
                                    navController.navigate(item.route) {
                                        popUpTo(destination?.route ?: item.route) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            icon = { Icon(item.icon, contentDescription = null) },
                            label = {
                                Text(
                                    stringResource(item.labelRes),
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                )
                            },
                            colors = androidx.compose.material3.NavigationBarItemDefaults.colors(
                                selectedIconColor = Color(0xFF1D4ED8),
                                selectedTextColor = Color(0xFF1D4ED8),
                                indicatorColor = Color(0xFFDBEAFE),
                                unselectedIconColor = Color(0xFF94A3B8),
                                unselectedTextColor = Color(0xFF64748B)
                            )
                        )
                    }
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = initialRoute,
            modifier = Modifier.fillMaxSize().padding(if (employee != null) padding else PaddingValues(0.dp))
        ) {
            composable(REAL_LOGIN_ROUTE) {
                val viewModel: LoginViewModel = hiltViewModel()
                val loginState by viewModel.state.collectAsStateWithLifecycle()

                LoginScreen(
                    state = loginState,
                    onUsernameChange = viewModel::onUsernameChange,
                    onPasswordChange = viewModel::onPasswordChange,
                    onLogin = viewModel::login,
                    onSwitchToDemo = if (BuildConfig.DEBUG || BuildConfig.STAGING_MODE) {
                        {
                            isDemoMode = true
                            navController.navigate(DEMO_LOGIN_ROUTE)
                        }
                    } else null,
                    currentLanguage = currentLanguage,
                    onLanguageChange = onLanguageChange
                )
            }

            composable(DEMO_LOGIN_ROUTE) {
                val viewModel: DemoLoginViewModel = hiltViewModel()
                val demoLoginState by viewModel.state.collectAsStateWithLifecycle()
                DemoLoginScreen(
                    state = demoLoginState,
                    onUsernameChange = viewModel::onUsernameChange,
                    onPasswordChange = viewModel::onPasswordChange,
                    onLogin = viewModel::login
                )
            }

            // ==========================================
            // OWNER DESTINATIONS
            // ==========================================
            composable(RoleDestination.OWNER.route) {
                if (employee != null) {
                    val viewModel: OwnerViewModel = hiltViewModel()
                    val ownerState by viewModel.state.collectAsStateWithLifecycle()
                    OwnerHomeScreen(
                        employee = employee,
                        state = ownerState,
                        onViewApprovals = { navController.navigate(OWNER_APPROVALS) },
                        onViewProducts = { navController.navigate(OWNER_PRODUCTS) },
                        onViewRetailers = { navController.navigate(OWNER_RETAILERS) },
                        onViewEmployees = { navController.navigate(OWNER_EMPLOYEES) },
                        onViewHandovers = { navController.navigate(OWNER_HANDOVERS) },
                        onViewCollections = { navController.navigate(OWNER_COLLECTIONS) },
                        onViewReturns = { navController.navigate(OWNER_RETURNS) },
                        onViewTeam = { navController.navigate(OWNER_TEAM) },
                        onViewReports = { navController.navigate(OWNER_ACTIVITY) },
                        onRefresh = viewModel::refreshOperations
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

            composable(OWNER_BUSINESS_HUB) {
                val viewModel: OwnerMasterViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerBusinessHubScreen(
                    state = state,
                    onNavigateProducts = { navController.navigate(OWNER_PRODUCTS) },
                    onNavigateRetailers = { navController.navigate(OWNER_RETAILERS) },
                    onNavigateBeats = { navController.navigate(OWNER_BEATS) },
                    onNavigateEmployees = { navController.navigate(OWNER_EMPLOYEES) },
                    onNavigateHandovers = { navController.navigate(OWNER_HANDOVERS) },
                    onNavigateCollections = { navController.navigate(OWNER_COLLECTIONS) },
                    onNavigateReturns = { navController.navigate(OWNER_RETURNS) }
                )
            }

            composable(OWNER_PRODUCTS) {
                val viewModel: OwnerMasterViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerProductsScreen(
                    state = state,
                    onCreateProduct = viewModel::createProduct,
                    onUpdateProduct = viewModel::updateProduct,
                    onAdjustStock = viewModel::adjustStock,
                    onClearMessages = viewModel::clearMessages,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_RETAILERS) {
                val viewModel: OwnerMasterViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerRetailersScreen(
                    state = state,
                    onCreateRetailer = viewModel::createRetailer,
                    onUpdateRetailer = viewModel::updateRetailer,
                    onLoadStockChecks = viewModel::loadStockChecks,
                    onClearMessages = viewModel::clearMessages,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_EMPLOYEES) {
                val viewModel: OwnerMasterViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerEmployeesScreen(
                    state = state,
                    onCreateEmployee = viewModel::createEmployee,
                    onDeactivateEmployee = viewModel::deactivateEmployee,
                    onResetPassword = viewModel::resetEmployeePassword,
                    onClearMessages = viewModel::clearMessages,
                    onBack = { navController.popBackStack() }
                )

            }

            composable(OWNER_BEATS) {
                val viewModel: OwnerMasterViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerBeatsScreen(
                    state = state,
                    onCreateBeat = viewModel::createBeat,
                    onAssignSalesperson = viewModel::assignBeat,
                    onClearMessages = viewModel::clearMessages,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_TEAM) {
                val viewModel: OwnerTeamViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerTeamScreen(
                    state = state,
                    onRefresh = viewModel::refresh
                )
            }

            composable(OWNER_ACTIVITY) {
                val viewModel: OwnerFieldActivityViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerFieldActivityScreen(
                    state = state,
                    onRefresh = viewModel::refresh,
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_HANDOVERS) {
                OwnerHandoversScreen(
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_COLLECTIONS) {
                OwnerCollectionsScreen(
                    onBack = { navController.popBackStack() }
                )
            }

            composable(OWNER_RETURNS) {
                OwnerReturnsScreen(
                    onBack = { navController.popBackStack() }
                )
            }

            // ==========================================
            // ADMIN / TEAM LEADER DESTINATIONS
            // Delegated subset — order review, team visibility, activity.
            // No business-config or unlimited credit/price overrides.
            // ==========================================
            composable(RoleDestination.ADMIN.route) {
                if (employee != null) {
                    val viewModel: OwnerViewModel = hiltViewModel()
                    val adminState by viewModel.state.collectAsStateWithLifecycle()
                    OwnerHomeScreen(
                        employee = employee,
                        state = adminState,
                        onViewApprovals = { navController.navigate(ADMIN_APPROVALS) },
                        onViewProducts = {},
                        onViewRetailers = {},
                        onViewEmployees = {},
                        onViewHandovers = {},
                        onViewCollections = {},
                        onViewReturns = {},
                        onViewTeam = { navController.navigate(ADMIN_TEAM) },
                        onViewReports = { navController.navigate(ADMIN_ACTIVITY) },
                        onRefresh = viewModel::refreshOperations
                    )

                }
            }

            composable(ADMIN_APPROVALS) {
                val viewModel: OrderApprovalViewModel = hiltViewModel()
                val approvalState by viewModel.state.collectAsStateWithLifecycle()
                OrderApprovalScreen(
                    state = approvalState,
                    onApprove = viewModel::approveOrder,
                    onReject = viewModel::rejectOrder
                )
            }

            composable(ADMIN_TEAM) {
                val viewModel: OwnerTeamViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerTeamScreen(
                    state = state,
                    onRefresh = viewModel::refresh
                )
            }

            composable(ADMIN_ACTIVITY) {
                val viewModel: OwnerFieldActivityViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                OwnerFieldActivityScreen(
                    state = state,
                    onRefresh = viewModel::refresh,
                    onBack = { navController.popBackStack() }
                )
            }

            // ==========================================
            // SALESPERSON DESTINATIONS
            // ==========================================
            composable(RoleDestination.SALES.route) {
                if (employee != null) {
                    val salesViewModel: SalesViewModel = hiltViewModel()
                    val salesState by salesViewModel.state.collectAsStateWithLifecycle()
                    SalesHomeScreen(
                        employee = employee,
                        state = salesState,
                        onStartVisits = { navController.navigate(SALES_TODAY) },
                        onStartShift = salesViewModel::startShift,
                        onContinueRoute = { nextRetailerId ->
                            if (nextRetailerId != null) {
                                navController.navigate("sales/visit/$nextRetailerId")
                            } else {
                                navController.navigate(SALES_TODAY)
                            }
                        },
                        onSyncNow = salesViewModel::syncNow
                    )
                }
            }

            composable(SALES_TODAY) {
                val viewModel: SalesTodayViewModel = hiltViewModel()
                val state by viewModel.state.collectAsStateWithLifecycle()
                SalesTodayScreen(
                    state = state,
                    onStartShift = { viewModel.startShift() },
                    onEndShift = { viewModel.endShift() },
                    onRetailerClick = { id -> navController.navigate("sales/visit/$id") },
                    onClearMessages = viewModel::clearMessages,
                    onSyncAgain = { viewModel.syncRetailers() }
                )
            }

            composable(SALES_RETAILER_LIST) {
                val viewModel: RetailerListViewModel = hiltViewModel()
                val salesListState by viewModel.state.collectAsStateWithLifecycle()
                RetailerListScreen(
                    state = salesListState,
                    onRetailerClick = { id -> navController.navigate("sales/visit/$id") },
                    onStartShift = { viewModel.startShift() },
                    onAddRetailer = { name, address, contact, lat, lng ->
                        viewModel.createRetailer(name, address, contact, lat, lng)
                    },
                    onClearMessages = { viewModel.clearMessages() },
                    onSyncAgain = { viewModel.refreshRetailers() }
                )
            }

            composable(SALES_COLLECTIONS) {
                val collectionsVm: com.routeflow.app.feature.sales.SalesCollectionsViewModel = hiltViewModel()
                val collectionsState by collectionsVm.uiState.collectAsStateWithLifecycle()
                val snackbarHostState = remember { androidx.compose.material3.SnackbarHostState() }
                val scope = rememberCoroutineScope()

                LaunchedEffect(Unit) {
                    collectionsVm.eventFlow.collect { event ->
                        when (event) {
                            is com.routeflow.app.feature.sales.CollectionEvent.Success -> {
                                val badge = if (event.isConfirmed) "✓ Confirmed" else "⏳ Pending sync"
                                scope.launch { snackbarHostState.showSnackbar("$badge — ${event.message}. Receipt: ${event.receiptId}") }
                            }
                            is com.routeflow.app.feature.sales.CollectionEvent.Error ->
                                scope.launch { snackbarHostState.showSnackbar("Error: ${event.error}") }
                        }
                    }
                }

                SalesCollectionsScreen(
                    retailers = collectionsState.retailers,
                    onCollectPayment = { retailerId, amountPaise, method, reference ->
                        val retailer = collectionsState.retailers.find { it.id == retailerId }
                        collectionsVm.recordCollection(
                            retailerId = retailerId,
                            retailerName = retailer?.name ?: retailerId,
                            amountPaise = amountPaise,
                            paymentMethod = method,
                            receiptId = reference.takeIf { it.isNotBlank() },
                            notes = null
                        )
                    }
                )
            }

            composable(SALES_PROFILE) {
                if (employee != null) {
                    val salesViewModel: SalesViewModel = hiltViewModel()
                    val salesState by salesViewModel.state.collectAsStateWithLifecycle()
                    SalesProfileScreen(
                        employee = employee,
                        salesState = salesState,
                        currentLanguage = currentLanguage,
                        onLanguageChange = onLanguageChange,
                        onSyncNow = salesViewModel::syncNow,
                        onLogout = onDemoLogout
                    )
                }
            }

            composable(
                route = SALES_SHOP_VISIT,
                arguments = listOf(navArgument("retailerId") { type = NavType.StringType })
            ) { backStackEntry ->
                val retailerId = backStackEntry.arguments?.getString("retailerId") ?: ""
                val viewModel: ShopVisitViewModel = hiltViewModel()
                val visitState by viewModel.state.collectAsStateWithLifecycle()
                ShopVisitScreen(
                    state = visitState,
                    onCheckIn = viewModel::checkIn,
                    onCheckOut = viewModel::checkOut,
                    onCreateOrder = {
                        val targetId = visitState.retailer?.id ?: retailerId
                        if (targetId.isNotBlank()) navController.navigate("sales/order/$targetId")
                    },
                    onStockCheck = {
                        val targetId = visitState.retailer?.id ?: retailerId
                        if (targetId.isNotBlank()) navController.navigate("sales/stock-check/$targetId")
                    },
                    onCollectPayment = viewModel::recordCollection
                )
            }

            composable(
                route = SALES_STOCK_CHECK,
                arguments = listOf(navArgument("retailerId") { type = NavType.StringType })
            ) {
                val viewModel: StockCheckViewModel = hiltViewModel()
                val checkState by viewModel.state.collectAsStateWithLifecycle()
                StockCheckScreen(
                    state = checkState,
                    onQuantityChanged = viewModel::onQuantityChanged,
                    onSuggestedQuantityChanged = viewModel::onSuggestedQuantityChanged,
                    onNotesChanged = viewModel::onNotesChanged,
                    onSaveStockCheck = viewModel::saveStockCheck,
                    onBack = { navController.popBackStack() }
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
                        val popped = navController.popBackStack(SALES_TODAY, inclusive = false)
                        if (!popped) {
                            navController.popBackStack()
                        }
                    }
                } else {
                    OrderBookingScreen(
                        state = orderState,
                        onSearchChange = viewModel::updateSearch,
                        onCategorySelect = viewModel::selectCategory,
                        onQuantityChange = viewModel::updateQuantity,
                        onSubmit = viewModel::submitOrder,
                        onAddNewProduct = viewModel::addNewProduct,
                        onRetailerSelect = viewModel::selectRetailer
                    )
                }
            }

            // ==========================================
            // WAREHOUSE DESTINATIONS (5 Tabs & Barcode Modal)
            // ==========================================
            composable(RoleDestination.WAREHOUSE.route) {
                if (employee != null) {
                    val viewModel: WarehouseViewModel = hiltViewModel()
                    val dashboardState by viewModel.dashboardState.collectAsStateWithLifecycle()
                    val stockState by viewModel.stockState.collectAsStateWithLifecycle()

                    WarehouseHomeScreen(
                        employee = employee,
                        state = dashboardState,
                        onNavigateTab = { route -> navController.navigate(route) },
                        onScanBarcode = { viewModel.setScanning(true) }
                    )

                    if (stockState.isScanning) {
                        BarcodeScannerModal(
                            onDismiss = { viewModel.setScanning(false) },
                            onBarcodeScanned = { barcode ->
                                viewModel.onScanBarcode(barcode)
                            }
                        )
                    }
                }
            }

            composable(WAREHOUSE_STOCK) {
                val viewModel: WarehouseViewModel = hiltViewModel()
                val stockState by viewModel.stockState.collectAsStateWithLifecycle()

                WarehouseStockScreen(
                    state = stockState,
                    onSearchChange = { q -> viewModel.loadStock(search = q) },
                    onFilterChange = { f -> viewModel.loadStock(filter = f) },
                    onOpenScanner = { viewModel.setScanning(true) },
                    onAdjustStock = { pId, qty, reason, notes, bId ->
                        viewModel.adjustStock(pId, qty, reason, notes, bId)
                    },
                    onAuditStock = { pId, physicalCount, notes ->
                        viewModel.auditStock(pId, physicalCount, notes)
                    },
                    onCreateBatch = { request ->
                        viewModel.createBatch(request)
                    }
                )

                if (stockState.isScanning) {
                    BarcodeScannerModal(
                        onDismiss = { viewModel.setScanning(false) },
                        onBarcodeScanned = { barcode ->
                            viewModel.onScanBarcode(barcode)
                        }
                    )
                }
            }

            composable(WAREHOUSE_PICKING) {
                val viewModel: WarehouseViewModel = hiltViewModel()
                val pickingOrders by viewModel.pickingQueue.collectAsStateWithLifecycle()
                var activeScanningOrderId by remember { mutableStateOf<String?>(null) }

                PickingScreen(
                    orders = pickingOrders,
                    isLoading = false,
                    onRefresh = { viewModel.loadPickingQueue() },
                    onStartPicking = { orderId -> viewModel.startPicking(orderId) },
                    onScanPick = { orderId, barcode -> viewModel.scanPickItem(orderId, barcode) },
                    onMarkPacked = { orderId, cartons, notes -> viewModel.markOrderPacked(orderId, cartons, notes) },
                    onOpenScannerForOrder = { orderId -> activeScanningOrderId = orderId }
                )

                activeScanningOrderId?.let { orderId ->
                    BarcodeScannerModal(
                        onDismiss = { activeScanningOrderId = null },
                        onBarcodeScanned = { barcode ->
                            viewModel.scanPickItem(orderId, barcode)
                            activeScanningOrderId = null
                        }
                    )
                }
            }

            composable(WAREHOUSE_DISPATCH) {
                val viewModel: WarehouseViewModel = hiltViewModel()
                val dispatchState by viewModel.dispatchState.collectAsStateWithLifecycle()

                DispatchBatchScreen(
                    state = dispatchState,
                    onRefresh = { viewModel.loadDispatchBatches() },
                    onCreateBatch = { orderIds, driverId, notes ->
                        viewModel.createDispatchBatch(orderIds, driverId, notes)
                    },
                    onHandover = { batchId ->
                        viewModel.handoverDispatchBatch(batchId)
                    }
                )
            }

            composable(WAREHOUSE_RETURNS) {
                WarehouseReturnsScreen(
                    currentLanguage = currentLanguage,
                    onLanguageChange = onLanguageChange,
                    onLogout = onDemoLogout
                )
            }

            // ==========================================
            // DELIVERY DESTINATIONS
            // ==========================================
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

            composable(DELIVERY_HANDOVER) {
                DeliveryHandoverScreen()
            }

            composable(DELIVERY_PROFILE) {
                if (employee != null) {
                    val deliveryViewModel: DeliveryViewModel = hiltViewModel()
                    val handoverViewModel: DeliveryHandoverViewModel = hiltViewModel()
                    val homeState by deliveryViewModel.state.collectAsStateWithLifecycle()
                    val handoverState by handoverViewModel.uiState.collectAsStateWithLifecycle()

                    DeliveryProfileScreen(
                        employee = employee,
                        isOnShift = false,
                        onStartShift = {},
                        onEndShift = {},
                        assignedCount = homeState.assignedCount,
                        completedCount = homeState.completedCount,
                        cashHeldPaise = handoverState.cashHeldPaise,
                        pendingHandover = handoverState.pendingHandover != null,
                        currentLanguage = currentLanguage,
                        onLanguageChange = onLanguageChange,
                        onLogout = onDemoLogout
                    )
                }
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
                    // Trigger item fetch on screen open when items not cached from login sync
                    LaunchedEffect(item.order.id) {
                        viewModel.loadOrderItems(item.order.id)
                    }

                    // Merge network item-fetch error into detailState.error so existing error card shows it
                    val effectiveDetailState = if (detailState.error == null && detailState.itemsFetchError != null) {
                        detailState.copy(error = detailState.itemsFetchError)
                    } else detailState

                    DeliveryDetailScreen(
                        orderId = item.order.id,
                        retailerName = item.retailerName,
                        retailerAddress = item.retailerAddress,
                        contactNumber = item.contactNumber,
                        amountPaise = item.order.totalAmountPaise,
                        detailState = effectiveDetailState,
                        itemsFlow = viewModel.getOrderItems(item.order.id),
                        onDeliver = { method, otp, recipientName, items ->
                            viewModel.markDelivered(item.order.id, method, otp, recipientName, items)
                        },
                        onDeliveryFailed = { reason, rescheduledDate, notes ->
                            viewModel.markDeliveryFailed(item.order.id, reason, rescheduledDate, notes)
                        },
                        onRequestOtp = {
                            viewModel.requestOtp(item.order.id)
                        },
                        onClearError = viewModel::clearError
                    )
                } else if (!detailState.success) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
            }
        }

        // Registered after NavHost: Back navigates back within the app stack
        BackHandler(enabled = employee != null && navController.previousBackStackEntry != null) {
            navController.popBackStack()
        }
    }
}
