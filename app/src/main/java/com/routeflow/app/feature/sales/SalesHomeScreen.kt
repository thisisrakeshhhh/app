package com.routeflow.app.feature.sales

import androidx.compose.runtime.Composable
import com.routeflow.app.core.design.RoleHomeScreen
import com.routeflow.app.domain.model.Employee

@Composable
fun SalesHomeScreen(employee: Employee) = RoleHomeScreen(
    employee = employee,
    title = "Your sales day",
    location = "Mansarovar West · BEAT-04",
    emptyTitle = "No shop visits scheduled yet",
    emptyMessage = "Your assigned shops and visit sequence will appear here. This sample beat has no live assignments.",
    upcoming = listOf("Today's shops and visits", "Order drafts and product schemes", "Collections and personal targets"),
)
