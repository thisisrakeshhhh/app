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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.PickingOrderDto

@Composable
fun PickingScreen(
    orders: List<PickingOrderDto>,
    isLoading: Boolean,
    onRefresh: () -> Unit,
    onStartPicking: (String) -> Unit,
    onScanPick: (orderId: String, barcode: String) -> Unit,
    onMarkPacked: (orderId: String, cartonsCount: Int, notes: String?) -> Unit,
    onOpenScannerForOrder: (String) -> Unit
) {
    var packingOrder by remember { mutableStateOf<PickingOrderDto?>(null) }

    Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC))) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            text = "Picking & Packing",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Black,
                            color = Color(0xFF0F172A)
                        )
                        Text(text = "•", color = Color(0xFF94A3B8))
                        Text(
                            text = "पिक-पैक",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                    Text(
                        text = "Warehouse task list with FEFO batch recommendation",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF2563EB))
                }
            }

            if (isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (orders.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(bottom = 120.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(24.dp)
                    ) {
                        Surface(
                            color = Color(0xFFEFF6FF),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.size(52.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Default.Inventory2, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(26.dp))
                            }
                        }
                        Text(
                            text = "No picking orders in queue",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF1E293B)
                        )
                        Text(
                            text = "Approved distributor orders will appear here for godown picking",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                        OutlinedButton(
                            onClick = onRefresh,
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.height(48.dp)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Refresh Queue", fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    items(orders, key = { it.id }) { item ->
                        PickingOrderItemCard(
                            orderDto = item,
                            onStartPicking = { onStartPicking(item.id) },
                            onScanPick = { onOpenScannerForOrder(item.id) },
                            onMarkPacked = { packingOrder = item }
                        )
                    }
                }
            }
        }
    }

    // Dialog: Mark Order Packed
    packingOrder?.let { item ->
        WarehousePackDialog(
            order = item,
            onDismiss = { packingOrder = null },
            onConfirm = { cartons, notes ->
                onMarkPacked(item.id, cartons, notes)
                packingOrder = null
            }
        )
    }
}

@Composable
private fun PickingOrderItemCard(
    orderDto: PickingOrderDto,
    onStartPicking: () -> Unit,
    onScanPick: () -> Unit,
    onMarkPacked: () -> Unit
) {
    val isApproved = orderDto.status == "APPROVED"
    val isPicking = orderDto.status == "PICKING"
    val isPacked = orderDto.status == "PACKED"

    val statusBg = when {
        isPacked -> Color(0xFFDCFCE7)
        isPicking -> Color(0xFFE0F2FE)
        else -> Color(0xFFFEF3C7)
    }
    val statusText = when {
        isPacked -> "Packed"
        isPicking -> "In Picking"
        else -> "Ready to Pick"
    }
    val statusColor = when {
        isPacked -> Color(0xFF166534)
        isPicking -> Color(0xFF0369A1)
        else -> Color(0xFFB45309)
    }

    val pickedCount = orderDto.items.count { it.isPicked }
    val totalCount = orderDto.items.size

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Top Row: Retailer & Status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Order #${orderDto.id.takeLast(6).uppercase()}",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Retailer ID: ${orderDto.retailerId}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Surface(color = statusBg, shape = RoundedCornerShape(6.dp)) {
                    Text(
                        text = statusText,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = statusColor
                    )
                }
            }

            // Progress pill
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Items: $totalCount SKU(s)",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF475569),
                    fontWeight = FontWeight.SemiBold
                )

                Surface(
                    color = Color(0xFFF1F5F9),
                    shape = RoundedCornerShape(4.dp)
                ) {
                    Text(
                        text = "Progress: $pickedCount / $totalCount picked",
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (pickedCount == totalCount && totalCount > 0) Color(0xFF16A34A) else Color(0xFF2563EB)
                    )
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Item list with FEFO suggested batch
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                orderDto.items.forEach { item ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(if (item.isPicked) Color(0xFFF0FDF4) else Color(0xFFF8FAFC), RoundedCornerShape(6.dp))
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = item.productName ?: item.productId,
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF1E293B)
                            )
                            if (item.suggestedBatch != null) {
                                Text(
                                    text = "FEFO Batch: ${item.suggestedBatch.batchNo}${if (!item.suggestedBatch.rackBin.isNullOrBlank()) " • " + item.suggestedBatch.rackBin else ""}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color(0xFF2563EB),
                                    fontSize = 11.sp
                                )
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "${item.quantity} units",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            if (item.isPicked) {
                                Icon(
                                    Icons.Default.CheckCircle,
                                    contentDescription = "Picked",
                                    tint = Color(0xFF16A34A),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Action row with clear CTA and scan visual
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Secondary Scan button
                OutlinedButton(
                    onClick = onScanPick,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.height(48.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp)
                ) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = "Scan", modifier = Modifier.size(18.dp), tint = Color(0xFF2563EB))
                    Spacer(Modifier.width(4.dp))
                    Text("Scan to Pick", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                }

                // Primary action button
                if (isApproved) {
                    Button(
                        onClick = onStartPicking,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEA580C)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Start Picking", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                } else if (isPicking) {
                    Button(
                        onClick = onMarkPacked,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                    ) {
                        Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Mark Packed", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                } else {
                    Surface(
                        color = Color(0xFFF0FDF4),
                        shape = RoundedCornerShape(6.dp),
                        border = BorderStroke(1.dp, Color(0xFFBBF7D0)),
                        modifier = Modifier
                            .weight(1f)
                            .height(48.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = "Packed • Ready for Dispatch",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF15803D)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WarehousePackDialog(
    order: PickingOrderDto,
    onDismiss: () -> Unit,
    onConfirm: (cartonsCount: Int, notes: String?) -> Unit
) {
    var cartonsCountText by remember { mutableStateOf("1") }
    var notesText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Mark Order Packed", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Order #${order.id.takeLast(6).uppercase()} packed into cartons for dispatch.", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                OutlinedTextField(
                    value = cartonsCountText,
                    onValueChange = { cartonsCountText = it },
                    label = { Text("Number of Cartons / Crates") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Carton packing notes (optional)") },
                    placeholder = { Text("e.g. Fragile glass bottles inside") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val cartons = cartonsCountText.toIntOrNull() ?: 1
                    onConfirm(cartons, notesText.trim().ifEmpty { null })
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Confirm Packed", fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}
