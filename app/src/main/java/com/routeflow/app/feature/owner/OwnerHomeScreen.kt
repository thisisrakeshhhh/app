package com.routeflow.app.feature.owner

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.ReportProblem
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.RouteFlowStatus
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole

@Composable
fun OwnerHomeScreen(
    employee: Employee,
    state: OwnerHomeState,
    onViewApprovals: () -> Unit,
    onViewProducts: () -> Unit = {},
    onViewRetailers: () -> Unit = {},
    onViewEmployees: () -> Unit = {},
    onViewHandovers: () -> Unit = {},
    onViewCollections: () -> Unit = {},
    onViewReturns: () -> Unit = {},
    onViewTeam: () -> Unit = {},
    onViewReports: () -> Unit = {},
    onRefresh: () -> Unit = {}
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        val scrollState = rememberScrollState()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Control Room",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Today's Wholesale & Cash Operations",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = MaterialTheme.colorScheme.primary)
                }
            }

            // Quick Actions Section
            Text(
                text = "Quick Actions",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF0F172A)
            )

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                QuickActionButton(
                    title = "Approve Orders",
                    badge = if (state.pendingApprovalsCount > 0) "${state.pendingApprovalsCount}" else null,
                    badgeColor = Color(0xFFDC2626),
                    icon = Icons.Default.PendingActions,
                    modifier = Modifier.weight(1f).testTag("quick_action_approvals"),
                    onClick = onViewApprovals
                )
                QuickActionButton(
                    title = "View Cash",
                    badge = if (state.pendingHandoverCount > 0) "${state.pendingHandoverCount}" else null,
                    badgeColor = Color(0xFF2563EB),
                    icon = Icons.Default.AccountBalanceWallet,
                    modifier = Modifier.weight(1f).testTag("quick_action_cash"),
                    onClick = onViewHandovers
                )
                QuickActionButton(
                    title = "Staff Location",
                    badge = "${state.staffOnDutyCount}",
                    badgeColor = Color(0xFF16A34A),
                    icon = Icons.Default.LocationOn,
                    modifier = Modifier.weight(1f).testTag("quick_action_staff"),
                    onClick = onViewTeam
                )
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                QuickActionButton(
                    title = "Stock Alert",
                    badge = if (state.lowStockCount > 0) "${state.lowStockCount}" else null,
                    badgeColor = Color(0xFFD97706),
                    icon = Icons.Default.Warning,
                    modifier = Modifier.weight(1f).testTag("quick_action_stock"),
                    onClick = onViewProducts
                )
                QuickActionButton(
                    title = "Reports",
                    badge = null,
                    badgeColor = Color(0xFF4B5563),
                    icon = Icons.Default.Assessment,
                    modifier = Modifier.weight(1f).testTag("quick_action_reports"),
                    onClick = onViewReports
                )
            }

            // 8 Core Operational KPI Cards
            Text(
                text = "Business Metrics",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF0F172A)
            )

            // Row 1: Today Sales & Cash Collected
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(
                    title = "Today Sales",
                    value = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                    icon = Icons.Default.TrendingUp,
                    color = Color(0xFF16A34A),
                    modifier = Modifier.weight(1f)
                )
                MetricCard(
                    title = "Cash Collected",
                    value = CurrencyFormatter.formatPaise(state.cashCollectedTodayPaise),
                    icon = Icons.Default.Payments,
                    color = Color(0xFF2563EB),
                    modifier = Modifier.weight(1f)
                )
            }

            // Row 2: Pending Udhaar & Pending Approvals
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(
                    title = "Pending Udhaar",
                    value = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                    icon = Icons.Default.ReportProblem,
                    color = Color(0xFFDC2626),
                    modifier = Modifier.weight(1f)
                )
                MetricCard(
                    title = "Pending Approvals",
                    value = "${state.pendingApprovalsCount}",
                    icon = Icons.Default.PendingActions,
                    color = if (state.pendingApprovalsCount > 0) Color(0xFFD97706) else Color(0xFF4B5563),
                    modifier = Modifier.weight(1f)
                )
            }

            // Row 3: Godown Low Stock & Failed Deliveries
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(
                    title = "Low Stock Items",
                    value = "${state.lowStockCount}",
                    icon = Icons.Default.Warning,
                    color = if (state.lowStockCount > 0) Color(0xFFEA580C) else Color(0xFF16A34A),
                    modifier = Modifier.weight(1f)
                )
                MetricCard(
                    title = "Failed Deliveries",
                    value = "${state.failedDeliveriesCount}",
                    icon = Icons.Default.ReportProblem,
                    color = if (state.failedDeliveriesCount > 0) Color(0xFFDC2626) else Color(0xFF16A34A),
                    modifier = Modifier.weight(1f)
                )
            }

            // Row 4: Pending Cash Handover & Staff On Duty
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricCard(
                    title = "Pending Handover",
                    value = "${state.pendingHandoverCount} (${CurrencyFormatter.formatPaise(state.pendingHandoverAmountPaise)})",
                    icon = Icons.Default.AccountBalanceWallet,
                    color = if (state.pendingHandoverCount > 0) Color(0xFF7C3AED) else Color(0xFF4B5563),
                    modifier = Modifier.weight(1f)
                )
                MetricCard(
                    title = "Staff On Duty",
                    value = "${state.staffOnDutyCount} Active",
                    icon = Icons.Default.Group,
                    color = Color(0xFF0284C7),
                    modifier = Modifier.weight(1f)
                )
            }

            // Operations & Verifications Section
            Text(
                text = "Cash & Ledger Reconciliation",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF0F172A),
                modifier = Modifier.padding(top = 8.dp)
            )

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onViewHandovers,
                    modifier = Modifier.weight(1f).height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    )
                ) {
                    Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Cash Handover", color = Color.White, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                }

                Button(
                    onClick = onViewCollections,
                    modifier = Modifier.weight(1f).height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Accent,
                        contentColor = Color.White
                    )
                ) {
                    Icon(Icons.Default.Payments, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Verify UPI/Cheque", color = Color.White, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                }
            }

            OutlinedButton(
                onClick = onViewReturns,
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.AssignmentReturn, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Returns & Credit Notes", style = MaterialTheme.typography.labelLarge)
            }

            // Master Data & Configuration Section
            if (employee.role == EmployeeRole.OWNER) {
                Text(
                    text = "Master Data & Staff Controls",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A),
                    modifier = Modifier.padding(top = 8.dp)
                )

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(
                        onClick = onViewProducts,
                        modifier = Modifier.weight(1f).height(50.dp).testTag("nav_products_button"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Inventory, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Godown Stock", style = MaterialTheme.typography.labelMedium)
                    }

                    OutlinedButton(
                        onClick = onViewRetailers,
                        modifier = Modifier.weight(1f).height(50.dp).testTag("nav_retailers_button"),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Store, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Retailers", style = MaterialTheme.typography.labelMedium)
                    }
                }

                OutlinedButton(
                    onClick = onViewEmployees,
                    modifier = Modifier.fillMaxWidth().height(50.dp).testTag("nav_employees_button"),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Group, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Manage Staff & Reset Passwords", style = MaterialTheme.typography.labelLarge)
                }
            }

            // 120dp bottom padding so no content is obscured behind bottom navigation
            Spacer(Modifier.height(120.dp))
        }
    }
}

@Composable
private fun QuickActionButton(
    title: String,
    badge: String?,
    badgeColor: Color,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFF1F5F9)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.5.dp),
        shape = RoundedCornerShape(14.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = Color(0xFFEFF6FF),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.size(32.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(icon, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(18.dp))
                    }
                }
                if (badge != null) {
                    Surface(
                        color = badgeColor.copy(alpha = 0.12f),
                        shape = CircleShape,
                        border = BorderStroke(1.dp, badgeColor.copy(alpha = 0.3f))
                    ) {
                        Text(
                            text = badge,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Black,
                            color = badgeColor
                        )
                    }
                }
            }
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF0F172A),
                maxLines = 1
            )
        }
    }
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFF1F5F9)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.5.dp),
        shape = RoundedCornerShape(14.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    title,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B),
                    fontWeight = FontWeight.SemiBold
                )
                Surface(
                    color = color.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier.size(24.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(14.dp))
                    }
                }
            }
            Text(
                value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Black,
                color = if (color == Color(0xFFDC2626)) Color(0xFFDC2626) else Color(0xFF0F172A)
            )
        }
    }
}
