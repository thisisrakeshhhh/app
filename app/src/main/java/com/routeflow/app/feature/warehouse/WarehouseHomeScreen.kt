package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Employee

@Composable
fun WarehouseHomeScreen(
    employee: Employee,
    state: WarehouseDashboardState,
    onNavigateTab: (String) -> Unit,
    onScanBarcode: () -> Unit
) {
    if (state.isLoading) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = RFColors.Primary)
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF8FAFC))
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 14.dp)
                .padding(bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Compact Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Godown Desk / गोदाम",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Today's stock, picking & dispatch",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Surface(
                    color = Color(0xFFEFF6FF),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, Color(0xFFBFDBFE))
                ) {
                    Text(
                        text = employee.name.ifBlank { "Godown Staff" },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF2563EB)
                    )
                }
            }

            // Quick Action Grid (4 Primary Warehouse Tasks)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                GodownQuickActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Scan Product",
                    subtitle = "बारकोड स्कैन",
                    icon = Icons.Default.QrCodeScanner,
                    accentColor = Color(0xFF2563EB),
                    onClick = onScanBarcode
                )
                GodownQuickActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Add Inward",
                    subtitle = "माल आवक",
                    icon = Icons.Default.Inventory,
                    accentColor = Color(0xFF16A34A),
                    onClick = { onNavigateTab("warehouse/stock") }
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                GodownQuickActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Pick Orders",
                    subtitle = "पिकिंग लिस्ट",
                    icon = Icons.Default.Assignment,
                    accentColor = Color(0xFFEA580C),
                    onClick = { onNavigateTab("warehouse/picking") }
                )
                GodownQuickActionCard(
                    modifier = Modifier.weight(1f),
                    title = "Create Dispatch",
                    subtitle = "गाड़ी डिस्पैच",
                    icon = Icons.Default.LocalShipping,
                    accentColor = Color(0xFF0284C7),
                    onClick = { onNavigateTab("warehouse/dispatch") }
                )
            }

            // Operational KPI Grid (6 Dense Cards)
            Text(
                text = "Operational Metrics / संचालन स्थिति",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF334155)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.readyToPickCount.toString(),
                    label = "Ready to Pick",
                    hindi = "पिकिंग बाकी",
                    valueColor = if (state.readyToPickCount > 0) Color(0xFFEA580C) else Color(0xFF64748B)
                )
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.packedTodayCount.toString(),
                    label = "Packed Today",
                    hindi = "पैक तैयार",
                    valueColor = Color(0xFF0284C7)
                )
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.dispatchBatchesCount.toString(),
                    label = "Dispatch Ready",
                    hindi = "डिस्पैच तैयार",
                    valueColor = Color(0xFF16A34A)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.lowStockCount.toString(),
                    label = "Low Stock",
                    hindi = "कम स्टॉक",
                    valueColor = if (state.lowStockCount > 0) Color(0xFFD97706) else Color(0xFF64748B)
                )
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.nearExpiryCount.toString(),
                    label = "Near Expiry",
                    hindi = "जल्द एक्सपायरी",
                    valueColor = if (state.nearExpiryCount > 0) Color(0xFFDC2626) else Color(0xFF64748B)
                )
                DenseKpiCard(
                    modifier = Modifier.weight(1f),
                    value = state.damagedStockCount.toString(),
                    label = "Damaged / RMA",
                    hindi = "खराब / वापसी",
                    valueColor = if (state.damagedStockCount > 0) Color(0xFF991B1B) else Color(0xFF64748B)
                )
            }

            // Today's Work Queue
            Text(
                text = "Today's Work Queue / आज का कार्य",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF334155)
            )

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Queue Item 1: Picking Orders
                    QueueRowItem(
                        icon = Icons.Default.Assignment,
                        title = "Orders Waiting for Picking",
                        subtitle = "Pending warehouse pick list",
                        badgeCount = state.readyToPickCount,
                        badgeColor = Color(0xFFEA580C),
                        actionLabel = "Start Pick",
                        onClick = { onNavigateTab("warehouse/picking") }
                    )

                    HorizontalDivider(color = Color(0xFFF1F5F9))

                    // Queue Item 2: Packed Orders awaiting dispatch
                    QueueRowItem(
                        icon = Icons.Default.LocalShipping,
                        title = "Packed Orders Ready for Dispatch",
                        subtitle = "Assign delivery executive & route",
                        badgeCount = state.packedTodayCount,
                        badgeColor = Color(0xFF0284C7),
                        actionLabel = "Dispatch",
                        onClick = { onNavigateTab("warehouse/dispatch") }
                    )

                    HorizontalDivider(color = Color(0xFFF1F5F9))

                    // Queue Item 3: Return Inspections
                    QueueRowItem(
                        icon = Icons.Default.AssignmentReturn,
                        title = "Pending Return Inspections",
                        subtitle = "Driver returns and customer RMA",
                        badgeCount = state.pendingReturnsCount,
                        badgeColor = Color(0xFF7C3AED),
                        actionLabel = "Inspect",
                        onClick = { onNavigateTab("warehouse/returns") }
                    )
                }
            }

            // Godown Inventory Quick Link Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0))
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Godown Stock Ledger (स्टॉक बही)",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = "Search SKU, batch expiry, inward GRN & audit",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                    Button(
                        onClick = { onNavigateTab("warehouse/stock") },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(48.dp),
                        contentPadding = PaddingValues(horizontal = 14.dp)
                    ) {
                        Text("View Stock", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
private fun GodownQuickActionCard(
    modifier: Modifier = Modifier,
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentColor: Color,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .height(72.dp)
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Surface(
                color = accentColor.copy(alpha = 0.12f),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.size(40.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(imageVector = icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(22.dp))
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A)
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B)
                )
            }
        }
    }
}

@Composable
private fun DenseKpiCard(
    modifier: Modifier = Modifier,
    value: String,
    label: String,
    hindi: String,
    valueColor: Color
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = valueColor
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1E293B),
                maxLines = 1
            )
            Text(
                text = hindi,
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF64748B),
                maxLines = 1
            )
        }
    }
}

@Composable
private fun QueueRowItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    badgeCount: Int,
    badgeColor: Color,
    actionLabel: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Surface(
                color = Color(0xFFF1F5F9),
                shape = RoundedCornerShape(6.dp),
                modifier = Modifier.size(36.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(imageVector = icon, contentDescription = null, tint = Color(0xFF475569), modifier = Modifier.size(20.dp))
                }
            }
            Column {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF0F172A)
                    )
                    if (badgeCount > 0) {
                        Surface(
                            color = badgeColor.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = badgeCount.toString(),
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = badgeColor
                            )
                        }
                    }
                }
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B)
                )
            }
        }

        OutlinedButton(
            onClick = onClick,
            shape = RoundedCornerShape(6.dp),
            modifier = Modifier.height(36.dp),
            contentPadding = PaddingValues(horizontal = 10.dp)
        ) {
            Text(actionLabel, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
        }
    }
}
