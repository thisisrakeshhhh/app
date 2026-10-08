package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
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
                .padding(horizontal = 20.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Godown Desk / गोदाम",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Wholesale Inventory & Dispatch Hub",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Surface(
                    color = Color(0xFFEFF6FF),
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, Color(0xFFBFDBFE))
                ) {
                    Text(
                        text = employee.name.ifBlank { "Staff" },
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF2563EB)
                    )
                }
            }

            // Quick Scan Barcode Floating CTA
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onScanBarcode() },
                colors = CardDefaults.cardColors(containerColor = Color(0xFF1E293B)),
                shape = RoundedCornerShape(16.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Row(
                    modifier = Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .background(Color(0xFF3B82F6), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.QrCodeScanner,
                            contentDescription = "Scan Barcode",
                            tint = Color.White
                        )
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Scan Barcode / QR Code",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "बारकोड स्कैन करें • Instant stock check & pick",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF94A3B8)
                        )
                    }
                }
            }

            // Godown Operations Summary
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0))
            ) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(Icons.Default.Inventory, contentDescription = null, tint = RFColors.Primary)
                        Text("Today's Godown Queue", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    }

                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        WarehouseMetricCard(
                            label = "To Pick",
                            subLabel = "पिकिंग बाकी",
                            value = state.readyToPickCount.toString(),
                            color = Color(0xFFEA580C)
                        )
                        WarehouseMetricCard(
                            label = "Packed",
                            subLabel = "पैक तैयार",
                            value = state.packedTodayCount.toString(),
                            color = Color(0xFF0284C7)
                        )
                        WarehouseMetricCard(
                            label = "Dispatch Batches",
                            subLabel = "डिस्पैच",
                            value = state.dispatchBatchesCount.toString(),
                            color = Color(0xFF16A34A)
                        )
                    }
                }
            }

            // Inventory Warnings (Near Expiry, Low Stock, Damaged)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                WarningMetricPill(
                    modifier = Modifier.weight(1f),
                    title = "Near Expiry",
                    count = state.nearExpiryCount,
                    accentColor = Color(0xFFDC2626)
                )
                WarningMetricPill(
                    modifier = Modifier.weight(1f),
                    title = "Low Stock",
                    count = state.lowStockCount,
                    accentColor = Color(0xFFD97706)
                )
                WarningMetricPill(
                    modifier = Modifier.weight(1f),
                    title = "Damaged",
                    count = state.damagedStockCount,
                    accentColor = Color(0xFF6B7280)
                )
            }

            // Primary Navigation Shortcuts
            Text(
                text = "Quick Actions",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1E293B)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                WarehouseNavActionCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.Assignment,
                    title = "Start Picking",
                    hindi = "पिकिंग करें",
                    onClick = { onNavigateTab("warehouse/picking") }
                )
                WarehouseNavActionCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.LocalShipping,
                    title = "Dispatch Batches",
                    hindi = "गाड़ी डिस्पैच",
                    onClick = { onNavigateTab("warehouse/dispatch") }
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                WarehouseNavActionCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.Inventory,
                    title = "Godown Stock",
                    hindi = "स्टॉक इनवर्ड",
                    onClick = { onNavigateTab("warehouse/stock") }
                )
                WarehouseNavActionCard(
                    modifier = Modifier.weight(1f),
                    icon = Icons.Default.AssignmentReturn,
                    title = "Returns / RMA",
                    hindi = "वापसी माल",
                    onClick = { onNavigateTab("warehouse/returns") }
                )
            }

            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun WarehouseMetricCard(label: String, subLabel: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black, color = color)
        Text(text = label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
        Text(text = subLabel, style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
    }
}

@Composable
private fun WarningMetricPill(modifier: Modifier = Modifier, title: String, count: Int, accentColor: Color) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = count.toString(),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = if (count > 0) accentColor else Color(0xFF64748B)
            )
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF64748B)
            )
        }
    }
}

@Composable
private fun WarehouseNavActionCard(
    modifier: Modifier = Modifier,
    icon: ImageVector,
    title: String,
    hindi: String,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier.clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(imageVector = icon, contentDescription = null, tint = RFColors.Primary, modifier = Modifier.size(28.dp))
            Text(text = title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = Color(0xFF0F172A))
            Text(text = hindi, style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
        }
    }
}
