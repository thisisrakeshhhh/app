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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
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
import androidx.compose.runtime.mutableStateListOf
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
import com.routeflow.app.core.network.dto.DispatchBatchDto
import com.routeflow.app.core.network.dto.PickingOrderDto

@Composable
fun DispatchBatchScreen(
    state: WarehouseDispatchUiState,
    onRefresh: () -> Unit,
    onCreateBatch: (orderIds: List<String>, driverId: String?, notes: String?) -> Unit,
    onHandover: (batchId: String) -> Unit
) {
    var isCreateDialogOpen by remember { mutableStateOf(false) }

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
                    Text(
                        text = "Dispatch Batches",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Trip manifests & driver vehicle handover",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    IconButton(onClick = onRefresh, modifier = Modifier.size(40.dp)) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF2563EB), modifier = Modifier.size(20.dp))
                    }
                    Button(
                        onClick = { isCreateDialogOpen = true },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(48.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp)
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("New Batch", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                    }
                }
            }

            if (state.isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (state.dispatchBatches.isEmpty()) {
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
                                Icon(Icons.Default.LocalShipping, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(26.dp))
                            }
                        }
                        Text(
                            text = "No dispatch batches today",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF1E293B)
                        )
                        Text(
                            text = if (state.packedOrders.isNotEmpty()) "${state.packedOrders.size} packed orders ready to dispatch" else "Pack orders first, then assign delivery driver",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                        Button(
                            onClick = { isCreateDialogOpen = true },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.height(48.dp)
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null, tint = Color.White)
                            Spacer(Modifier.width(6.dp))
                            Text("Create Dispatch Batch", fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    items(state.dispatchBatches, key = { it.id }) { batch ->
                        DispatchManifestCard(
                            batch = batch,
                            onHandover = { onHandover(batch.id) }
                        )
                    }
                }
            }
        }
    }

    if (isCreateDialogOpen) {
        CreateDispatchBatchDialog(
            packedOrders = state.packedOrders,
            drivers = state.deliveryExecutives,
            onDismiss = { isCreateDialogOpen = false },
            onConfirm = { selectedOrderIds, driverId, notes ->
                onCreateBatch(selectedOrderIds, driverId, notes)
                isCreateDialogOpen = false
            }
        )
    }
}

@Composable
private fun DispatchManifestCard(
    batch: DispatchBatchDto,
    onHandover: () -> Unit
) {
    val isHandedOver = batch.status == "HANDED_OVER"
    val isDelivered = batch.status == "DELIVERED"

    val statusBg = when {
        isDelivered -> Color(0xFFDCFCE7)
        isHandedOver -> Color(0xFFE0F2FE)
        else -> Color(0xFFFEF3C7)
    }
    val statusText = when {
        isDelivered -> "Delivered"
        isHandedOver -> "Out for Delivery"
        else -> "Ready for Dispatch"
    }
    val statusColor = when {
        isDelivered -> Color(0xFF166534)
        isHandedOver -> Color(0xFF0369A1)
        else -> Color(0xFFB45309)
    }

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
            // Header row with Batch code & Status badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Surface(
                        color = Color(0xFFEFF6FF),
                        shape = RoundedCornerShape(6.dp),
                        modifier = Modifier.size(36.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.LocalShipping, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(20.dp))
                        }
                    }
                    Column {
                        Text(
                            text = "Trip Manifest: ${batch.batchCode}",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = "${batch.totalOrders} order(s) • ${batch.totalCartons} carton(s)",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
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

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Driver assignment info row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF64748B), modifier = Modifier.size(16.dp))
                    Text(
                        text = if (batch.deliveryExecutiveName != null) "Assigned: ${batch.deliveryExecutiveName}" else "Unassigned Driver",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF334155)
                    )
                }

                Surface(
                    color = Color(0xFFF8FAFC),
                    shape = RoundedCornerShape(4.dp),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Text(
                        text = "Route 04 (Jaipur Beat)",
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF64748B),
                        fontSize = 11.sp
                    )
                }
            }

            if (!batch.notes.isNullOrBlank()) {
                Text(
                    text = "Notes: ${batch.notes}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF64748B)
                )
            }

            // Handover button
            if (!isHandedOver && !isDelivered) {
                Button(
                    onClick = onHandover,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(Icons.Default.LocalShipping, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Handover to Driver", fontWeight = FontWeight.Bold, color = Color.White)
                }
            } else if (isHandedOver) {
                Surface(
                    color = Color(0xFFF0FDF4),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, Color(0xFFBBF7D0)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF16A34A), modifier = Modifier.size(16.dp))
                        Text(
                            text = "Handed over to driver. Currently out for delivery.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF166534),
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateDispatchBatchDialog(
    packedOrders: List<PickingOrderDto>,
    drivers: List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto>,
    onDismiss: () -> Unit,
    onConfirm: (selectedOrderIds: List<String>, driverId: String?, notes: String?) -> Unit
) {
    val selectedOrders = remember { mutableStateListOf<String>() }
    var selectedDriverId by remember { mutableStateOf(drivers.firstOrNull()?.id) }
    var notesText by remember { mutableStateOf("") }
    var isDriverExpanded by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create Dispatch Batch", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Select packed orders to include in batch:", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                if (packedOrders.isEmpty()) {
                    Text("No orders currently marked Packed. Pack orders first in Picking tab.", color = Color(0xFFDC2626), style = MaterialTheme.typography.bodySmall)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        packedOrders.forEach { orderDto ->
                            val isChecked = selectedOrders.contains(orderDto.id)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        if (isChecked) selectedOrders.remove(orderDto.id)
                                        else selectedOrders.add(orderDto.id)
                                    }
                                    .background(if (isChecked) Color(0xFFEFF6FF) else Color.Transparent, RoundedCornerShape(6.dp))
                                    .padding(vertical = 4.dp, horizontal = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Checkbox(
                                    checked = isChecked,
                                    onCheckedChange = {
                                        if (it) selectedOrders.add(orderDto.id)
                                        else selectedOrders.remove(orderDto.id)
                                    }
                                )
                                Spacer(Modifier.width(4.dp))
                                Column {
                                    Text("Order #${orderDto.id.takeLast(6).uppercase()}", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                                    Text("${orderDto.items.size} SKU(s)", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                                }
                            }
                        }
                    }
                }

                Text("Assign Delivery Driver:", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                ExposedDropdownMenuBox(
                    expanded = isDriverExpanded,
                    onExpandedChange = { isDriverExpanded = it }
                ) {
                    val driverName = drivers.find { it.id == selectedDriverId }?.fullName ?: "Select Driver"
                    OutlinedTextField(
                        value = driverName,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isDriverExpanded) },
                        modifier = Modifier
                            .menuAnchor()
                            .fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp)
                    )
                    ExposedDropdownMenu(
                        expanded = isDriverExpanded,
                        onDismissRequest = { isDriverExpanded = false }
                    ) {
                        drivers.forEach { driver ->
                            DropdownMenuItem(
                                text = { Text(driver.fullName) },
                                onClick = {
                                    selectedDriverId = driver.id
                                    isDriverExpanded = false
                                }
                            )
                        }
                    }
                }

                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Trip / Vehicle Notes") },
                    placeholder = { Text("e.g. Loading into Van #RJ-14-1234") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onConfirm(selectedOrders.toList(), selectedDriverId, notesText.trim().ifEmpty { null })
                },
                enabled = selectedOrders.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Confirm Batch", fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}
