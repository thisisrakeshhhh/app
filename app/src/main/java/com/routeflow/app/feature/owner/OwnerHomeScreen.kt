package com.routeflow.app.feature.owner

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Approval
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RouteFlowStatus
import com.routeflow.app.domain.model.Employee

@Composable
fun OwnerHomeScreen(
    employee: Employee,
    state: OwnerHomeState,
    onViewApprovals: () -> Unit,
    onViewProducts: () -> Unit = {},
    onViewRetailers: () -> Unit = {},
    onViewEmployees: () -> Unit = {}
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        val scrollState = rememberScrollState()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Business Overview",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Black
            )

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MetricCard(
                    title = "Pending Approvals",
                    value = state.pendingApprovalsCount.toString(),
                    icon = Icons.Default.PendingActions,
                    color = if (state.pendingApprovalsCount > 0) RouteFlowStatus.Pending else MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f)
                )
                MetricCard(
                    title = "Low Stock Items",
                    value = state.lowStockCount.toString(),
                    icon = Icons.Default.Warning,
                    color = if (state.lowStockCount > 0) RouteFlowStatus.Rejected else MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f)
                )
            }

            MetricRowCard(
                title = "Delivered Sales Today",
                value = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                icon = Icons.Default.TrendingUp,
                color = RouteFlowStatus.Completed
            )

            MetricRowCard(
                title = "Retailer Outstanding",
                value = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                icon = Icons.Default.Assignment,
                color = RouteFlowStatus.Rejected
            )

            Text("Master Data & Controls", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))

            Button(
                onClick = onViewApprovals,
                modifier = Modifier.fillMaxWidth().height(52.dp).testTag("open_approvals_button"),
                shape = MaterialTheme.shapes.medium
            ) {
                Icon(Icons.Default.Approval, contentDescription = null)
                Spacer(Modifier.size(8.dp))
                Text("Pending Order Approvals (${state.pendingApprovalsCount})", style = MaterialTheme.typography.titleSmall)
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = onViewProducts,
                    modifier = Modifier.weight(1f).height(50.dp).testTag("nav_products_button")
                ) {
                    Icon(Icons.Default.Inventory, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Products", style = MaterialTheme.typography.labelLarge)
                }

                OutlinedButton(
                    onClick = onViewRetailers,
                    modifier = Modifier.weight(1f).height(50.dp).testTag("nav_retailers_button")
                ) {
                    Icon(Icons.Default.Store, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text("Retailers", style = MaterialTheme.typography.labelLarge)
                }
            }

            OutlinedButton(
                onClick = onViewEmployees,
                modifier = Modifier.fillMaxWidth().height(50.dp).testTag("nav_employees_button")
            ) {
                Icon(Icons.Default.Group, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(8.dp))
                Text("Manage Staff & Roles", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun MetricCard(title: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
            Text(text = value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = color)
            Text(text = title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun MetricRowCard(title: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Surface(color = color.copy(alpha = 0.1f), shape = MaterialTheme.shapes.small) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.padding(10.dp))
            }
            Column {
                Text(text = title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(text = value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
        }
    }
}
