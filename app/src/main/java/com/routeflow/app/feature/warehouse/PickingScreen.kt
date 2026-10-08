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
import androidx.compose.material.icons.filled.AssignmentTurnedIn
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
import androidx.compose.material3.Checkbox
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Picking & Packing / पिक-पैक",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "FEFO picking & carton packing for dispatch",
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
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("No orders pending picking or packing.", color = Color(0xFF64748B))
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
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

    // Dialog: Mark Order Packed (Cartons count, crates, notes)
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
        isPacked -> "PACKED (पैक हो गया)"
        isPicking -> "IN PICKING (पिकिंग चालू)"
        else -> "READY TO PICK (तैयार)"
    }
    val statusColor = when {
        isPacked -> Color(0xFF166534)
        isPicking -> Color(0xFF0369A1)
        else -> Color(0xFFB45309)
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Top: Order ID & Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = orderDto.id,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Retailer ID: ${orderDto.retailerId}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Surface(color = statusBg, shape = RoundedCornerShape(8.dp)) {
                    Text(
                        text = statusText,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = statusColor
                    )
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Items to pick
            Text(
                text = "Items in Order (${orderDto.items.size}):",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF334155)
            )

            orderDto.items.forEach { item ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = item.productName ?: item.productId,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF1E293B)
                        )
                        if (item.suggestedBatch != null) {
                            Text(
                                text = "FEFO Suggested Batch: ${item.suggestedBatch.batchNo}",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF2563EB)
                            )
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "${item.quantity} units",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        if (item.isPicked) {
                            Spacer(Modifier.width(6.dp))
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = "Picked",
                                tint = Color(0xFF16A34A),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }

            if (isPacked && orderDto.cartonsCount > 0) {
                Surface(
                    color = Color(0xFFF0FDF4),
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                ) {
                    Text(
                        text = "Packed: ${orderDto.cartonsCount} carton(s) ready for dispatch",
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF166534),
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Action CTAs
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (isApproved) {
                    Button(
                        onClick = onStartPicking,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White)
                        Spacer(Modifier.width(6.dp))
                        Text("Start Picking (पिकिंग शुरू करें)", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                } else if (isPicking) {
                    Button(
                        onClick = onScanPick,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.QrCodeScanner, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Scan Pick", fontWeight = FontWeight.Bold, color = Color.White)
                    }

                    Button(
                        onClick = onMarkPacked,
                        modifier = Modifier.weight(1.3f),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.Inventory2, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Mark Packed (पैक करें)", fontWeight = FontWeight.Bold, color = Color.White)
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
    onConfirm: (cartons: Int, notes: String?) -> Unit
) {
    var cartonsText by remember { mutableStateOf("1") }
    var notesText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Pack Order / कार्टन पैकिंग दर्ज करें", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Order: ${order.id}", fontWeight = FontWeight.SemiBold, color = Color(0xFF2563EB))
                OutlinedTextField(
                    value = cartonsText,
                    onValueChange = { cartonsText = it },
                    label = { Text("Number of Cartons / Crates *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Packing Notes (e.g., Heavy box, fragile glass)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val c = cartonsText.toIntOrNull() ?: 1
                    onConfirm(c, notesText.trim().takeIf { it.isNotBlank() })
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A))
            ) {
                Text("Confirm Packed (पैक सुरक्षित करें)", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
