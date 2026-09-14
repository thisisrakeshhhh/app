package com.routeflow.app.feature.owner

import androidx.compose.runtime.Composable
import com.routeflow.app.core.design.RoleHomeScreen
import com.routeflow.app.domain.model.Employee

@Composable
fun OwnerHomeScreen(employee: Employee) = RoleHomeScreen(
    employee = employee,
    title = "Business overview",
    location = "Jaipur Main Warehouse",
    emptyTitle = "No business activity yet",
    emptyMessage = "Sales, collections and approval requests will appear here when your business is connected.",
    upcoming = listOf("Order approvals and sales", "Stock and retailer balances", "Team, beats and reports"),
)
