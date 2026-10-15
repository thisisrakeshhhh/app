package com.routeflow.app.feature.owner

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Employee

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
                .background(Color(0xFFF8FAFC))
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .padding(bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. Header Card
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Distributor Control Room",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Wholesale Operations & Decision Desk",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B),
                        fontWeight = FontWeight.SemiBold
                    )
                }
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF2563EB))
                }
            }

            // 2. Primary Owner Action: Review Pending Orders Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onViewApprovals)
                    .testTag("primary_action_approvals"),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (state.pendingApprovalsCount > 0) Color(0xFFEFF6FF) else Color.White
                ),
                border = BorderStroke(
                    1.5.dp,
                    if (state.pendingApprovalsCount > 0) Color(0xFF2563EB) else Color(0xFFE2E8F0)
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Surface(
                            shape = CircleShape,
                            color = if (state.pendingApprovalsCount > 0) Color(0xFFDBEAFE) else Color(0xFFF1F5F9),
                            modifier = Modifier.size(44.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    Icons.Default.PendingActions,
                                    contentDescription = null,
                                    tint = if (state.pendingApprovalsCount > 0) Color(0xFF1D4ED8) else Color(0xFF64748B),
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }

                        Column {
                            Text(
                                text = "Review Pending Orders",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = if (state.pendingApprovalsCount > 0)
                                    "${state.pendingApprovalsCount} order(s) waiting for approval"
                                else
                                    "No pending orders. Queue is clear.",
                                style = MaterialTheme.typography.bodySmall,
                                color = if (state.pendingApprovalsCount > 0) Color(0xFF2563EB) else Color(0xFF64748B),
                                fontWeight = if (state.pendingApprovalsCount > 0) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    }

                    Icon(
                        Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                        tint = if (state.pendingApprovalsCount > 0) Color(0xFF2563EB) else Color(0xFF94A3B8)
                    )
                }
            }

            // 3. Exactly Four Summary Cards (2x2 Grid)
            Text(
                text = "Key Operations Metrics",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF475569)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                CleanMetricCard(
                    modifier = Modifier.weight(1f),
                    title = "Today's Sales",
                    value = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                    icon = Icons.Default.TrendingUp,
                    accentColor = Color(0xFF16A34A)
                )
                CleanMetricCard(
                    modifier = Modifier.weight(1f),
                    title = "Today's Collection",
                    value = CurrencyFormatter.formatPaise(state.cashCollectedTodayPaise),
                    icon = Icons.Default.Payments,
                    accentColor = Color(0xFF2563EB)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                CleanMetricCard(
                    modifier = Modifier.weight(1f),
                    title = "Pending Udhaar",
                    value = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                    icon = Icons.Default.Warning,
                    accentColor = Color(0xFFDC2626)
                )
                CleanMetricCard(
                    modifier = Modifier.weight(1f),
                    title = "Pending Approvals",
                    value = "${state.pendingApprovalsCount}",
                    icon = Icons.Default.PendingActions,
                    accentColor = if (state.pendingApprovalsCount > 0) Color(0xFFEA580C) else Color(0xFF64748B)
                )
            }

            // 4. Secondary Action Tiles
            Text(
                text = "Secondary Actions",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF475569)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SecondaryActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Settle Cash",
                    badge = if (state.pendingHandoverCount > 0) "${state.pendingHandoverCount}" else null,
                    badgeColor = Color(0xFF2563EB),
                    icon = Icons.Default.AccountBalanceWallet,
                    onClick = onViewHandovers
                )
                SecondaryActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Stock Alerts",
                    badge = if (state.lowStockCount > 0) "${state.lowStockCount}" else null,
                    badgeColor = Color(0xFFEA580C),
                    icon = Icons.Default.Warning,
                    onClick = onViewProducts
                )
                SecondaryActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Exceptions",
                    badge = if (state.failedDeliveriesCount > 0) "${state.failedDeliveriesCount}" else null,
                    badgeColor = Color(0xFFDC2626),
                    icon = Icons.Default.Warning,
                    onClick = onViewReturns
                )
            }

            // 5. Important Alerts / Operational Status
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "Operational Pulse",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A)
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Staff on Duty", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                        Text("${state.staffOnDutyCount} active", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = Color(0xFF16A34A))
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Low Stock Warning", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                        Text("${state.lowStockCount} items", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = if (state.lowStockCount > 0) Color(0xFFEA580C) else Color(0xFF64748B))
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Pending Cash Handovers", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                        Text("${state.pendingHandoverCount} drivers", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = if (state.pendingHandoverCount > 0) Color(0xFF2563EB) else Color(0xFF64748B))
                    }
                }
            }
        }
    }
}

@Composable
private fun CleanMetricCard(
    modifier: Modifier = Modifier,
    title: String,
    value: String,
    icon: ImageVector,
    accentColor: Color
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B),
                    fontWeight = FontWeight.SemiBold
                )
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(16.dp)
                )
            }
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Black,
                color = Color(0xFF0F172A)
            )
        }
    }
}

@Composable
private fun SecondaryActionCard(
    modifier: Modifier = Modifier,
    title: String,
    badge: String?,
    badgeColor: Color,
    icon: ImageVector,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .height(56.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color(0xFF334155))
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF1E293B),
                    fontSize = 11.sp
                )
            }
            if (badge != null) {
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = badgeColor
                ) {
                    Text(
                        text = badge,
                        color = Color.White,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp),
                        fontSize = 10.sp
                    )
                }
            }
        }
    }
}
