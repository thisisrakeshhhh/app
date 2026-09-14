package com.routeflow.app.feature.warehouse

import androidx.compose.runtime.Composable
import com.routeflow.app.core.design.RoleHomeScreen
import com.routeflow.app.domain.model.Employee

@Composable
fun WarehouseHomeScreen(employee: Employee) = RoleHomeScreen(
    employee = employee,
    title = "Warehouse desk",
    location = "Jaipur Main Warehouse",
    emptyTitle = "No orders in the queue",
    emptyMessage = "Owner-approved orders will appear here for picking, packing and dispatch.",
    upcoming = listOf("Picking and packing queues", "Stock and bin locations", "Dispatch assignments and returns"),
)
