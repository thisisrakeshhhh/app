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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.AssignmentReturn
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.QrCodeScanner
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
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Employee
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun WarehouseHomeScreen(
    employee: Employee,
    state: WarehouseDashboardState,
    onNavigateTab: (String) -> Unit,
    onScanBarcode: () -> Unit
) {
    if (state.isLoading) {
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = RFColors.Primary)
        }
    } else {
        val todayStr = rememberFormattedDate()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF8FAFC))
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 14.dp, vertical = 12.dp)
                .padding(bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. Top Section: Godown Desk Header
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text(
                                    text = "Godown Desk",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Black,
                                    color = Color(0xFF0F172A)
                                )
                                Text(
                                    text = "•",
                                    color = Color(0xFF94A3B8)
                                )
                                Text(
                                    text = "गोदाम डेस्क",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFF64748B)
                                )
                            }
                            Text(
                                text = employee.name.ifBlank { "Godown Manager" },
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF334155)
                            )
                        }

                        // Shift / Online pill
                        Surface(
                            color = Color(0xFFF0FDF4),
                            shape = RoundedCornerShape(6.dp),
                            border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(7.dp)
                                        .background(Color(0xFF16A34A), CircleShape)
                                )
                                Text(
                                    text = "On Duty",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF15803D)
                                )
                            }
                        }
                    }

                    HorizontalDivider(color = Color(0xFFF1F5F9))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = todayStr,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFF64748B)
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Color(0xFF16A34A),
                                modifier = Modifier.size(13.dp)
                            )
                            Text(
                                text = "Synced with Central Office",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF15803D),
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            // 2. Compact 2x2 Action Grid
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Quick Operations / त्वरित कार्य",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF475569)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    GodownCompactActionTile(
                        modifier = Modifier.weight(1f),
                        title = "Scan",
                        subtitle = "बारकोड स्कैन",
                        icon = Icons.Default.QrCodeScanner,
                        accentColor = Color(0xFF2563EB),
                        onClick = onScanBarcode
                    )
                    GodownCompactActionTile(
                        modifier = Modifier.weight(1f),
                        title = "Inward",
                        subtitle = "माल आवक GRN",
                        icon = Icons.Default.Inventory2,
                        accentColor = Color(0xFF16A34A),
                        onClick = { onNavigateTab("warehouse/stock") }
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    GodownCompactActionTile(
                        modifier = Modifier.weight(1f),
                        title = "Pick",
                        subtitle = "पिकिंग लिस्ट",
                        icon = Icons.Default.Assignment,
                        accentColor = Color(0xFFEA580C),
                        onClick = { onNavigateTab("warehouse/picking") }
                    )
                    GodownCompactActionTile(
                        modifier = Modifier.weight(1f),
                        title = "Dispatch",
                        subtitle = "गाड़ी डिस्पैच",
                        icon = Icons.Default.LocalShipping,
                        accentColor = Color(0xFF0284C7),
                        onClick = { onNavigateTab("warehouse/dispatch") }
                    )
                }
            }

            // 3. Premium Operational KPI Section (6 dense metrics in 2 rows of 3)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Godown Status / गोदाम स्थिति",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF475569)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.readyToPickCount,
                        label = "Ready to Pick",
                        hindi = "पिकिंग बाकी",
                        highlightColor = if (state.readyToPickCount > 0) Color(0xFFEA580C) else Color(0xFF64748B)
                    )
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.packedTodayCount,
                        label = "Packed",
                        hindi = "पैक तैयार",
                        highlightColor = Color(0xFF0284C7)
                    )
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.dispatchBatchesCount,
                        label = "Dispatch Ready",
                        hindi = "डिस्पैच तैयार",
                        highlightColor = Color(0xFF16A34A)
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.lowStockCount,
                        label = "Low Stock",
                        hindi = "कम स्टॉक",
                        highlightColor = if (state.lowStockCount > 0) Color(0xFFD97706) else Color(0xFF64748B)
                    )
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.nearExpiryCount,
                        label = "Near Expiry",
                        hindi = "जल्द एक्सपायरी",
                        highlightColor = if (state.nearExpiryCount > 0) Color(0xFFDC2626) else Color(0xFF64748B)
                    )
                    GodownKpiCard(
                        modifier = Modifier.weight(1f),
                        count = state.damagedStockCount,
                        label = "Damaged",
                        hindi = "खराब माल",
                        highlightColor = if (state.damagedStockCount > 0) Color(0xFF991B1B) else Color(0xFF64748B)
                    )
                }
            }

            // 4. Today's Work Queue (3 compact rows)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Today's Work Queue / आज का कार्य",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF475569)
                )

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        // Row 1: Picking Queue
                        WorkQueueRow(
                            icon = Icons.Default.Assignment,
                            title = "Picking Queue",
                            subtitle = "Orders waiting for batch pick",
                            count = state.readyToPickCount,
                            urgencyColor = if (state.readyToPickCount > 0) Color(0xFFEA580C) else Color(0xFF64748B),
                            actionText = "Start Pick",
                            onClick = { onNavigateTab("warehouse/picking") }
                        )

                        HorizontalDivider(color = Color(0xFFF1F5F9))

                        // Row 2: Dispatch Queue
                        WorkQueueRow(
                            icon = Icons.Default.LocalShipping,
                            title = "Dispatch Queue",
                            subtitle = "Cartons ready for vehicle handover",
                            count = state.packedTodayCount,
                            urgencyColor = if (state.packedTodayCount > 0) Color(0xFF0284C7) else Color(0xFF64748B),
                            actionText = "Dispatch",
                            onClick = { onNavigateTab("warehouse/dispatch") }
                        )

                        HorizontalDivider(color = Color(0xFFF1F5F9))

                        // Row 3: Returns Queue
                        WorkQueueRow(
                            icon = Icons.AutoMirrored.Filled.AssignmentReturn,
                            title = "Returns Queue",
                            subtitle = "Customer RMA & driver undelivered items",
                            count = state.pendingReturnsCount,
                            urgencyColor = if (state.pendingReturnsCount > 0) Color(0xFF7C3AED) else Color(0xFF64748B),
                            actionText = "Inspect",
                            onClick = { onNavigateTab("warehouse/returns") }
                        )
                    }
                }
            }

            // 5. Stock Ledger Quick Entry Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateTab("warehouse/stock") },
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.weight(1f)
                    ) {
                        Surface(
                            color = Color(0xFFEFF6FF),
                            shape = RoundedCornerShape(6.dp),
                            modifier = Modifier.size(38.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Default.Inventory2,
                                    contentDescription = null,
                                    tint = Color(0xFF2563EB),
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Column {
                            Text(
                                text = "Godown Stock Ledger",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = "गोदाम स्टॉक और बैच • View all inventory & SKU",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF64748B)
                            )
                        }
                    }

                    Button(
                        onClick = { onNavigateTab("warehouse/stock") },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(48.dp),
                        contentPadding = PaddingValues(horizontal = 14.dp)
                    ) {
                        Text(
                            text = "View Stock",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun GodownCompactActionTile(
    modifier: Modifier = Modifier,
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentColor: Color,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .height(58.dp)
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Surface(
                color = accentColor.copy(alpha = 0.1f),
                shape = RoundedCornerShape(6.dp),
                modifier = Modifier.size(34.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = accentColor,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A),
                    maxLines = 1
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B),
                    maxLines = 1,
                    fontSize = 11.sp
                )
            }
        }
    }
}

@Composable
private fun GodownKpiCard(
    modifier: Modifier = Modifier,
    count: Int,
    label: String,
    hindi: String,
    highlightColor: Color
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = highlightColor
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
                maxLines = 1,
                fontSize = 10.sp
            )
        }
    }
}

@Composable
private fun WorkQueueRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    count: Int,
    urgencyColor: Color,
    actionText: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
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
                modifier = Modifier.size(34.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = Color(0xFF475569),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF0F172A)
                    )
                    Surface(
                        color = urgencyColor.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(4.dp)
                    ) {
                        Text(
                            text = count.toString(),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = urgencyColor
                        )
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
            modifier = Modifier.height(48.dp),
            contentPadding = PaddingValues(horizontal = 10.dp),
            border = BorderStroke(1.dp, Color(0xFFCBD5E1))
        ) {
            Text(
                text = actionText,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF2563EB)
            )
        }
    }
}

private fun rememberFormattedDate(): String {
    return SimpleDateFormat("EEE, dd MMM yyyy", Locale.ENGLISH).format(Date())
}
