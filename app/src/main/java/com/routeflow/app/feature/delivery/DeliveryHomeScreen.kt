package com.routeflow.app.feature.delivery

import androidx.compose.runtime.Composable
import com.routeflow.app.core.design.RoleHomeScreen
import com.routeflow.app.domain.model.Employee

@Composable
fun DeliveryHomeScreen(employee: Employee) = RoleHomeScreen(
    employee = employee,
    title = "Your delivery day",
    location = "Jaipur Main Warehouse",
    emptyTitle = "No deliveries assigned yet",
    emptyMessage = "Your delivery sequence and retailer details will appear here after dispatch assignment.",
    upcoming = listOf("Assigned deliveries and navigation", "Delivery proof and returns", "Payment status and cash handover"),
)
