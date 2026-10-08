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
                        text = "Dispatch Batches / डिस्पैच",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Group packed orders, assign driver & handover",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF2563EB))
                    }
                    Button(
                        onClick = { isCreateDialogOpen = true },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("+ Create Batch", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
            }

            if (state.isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (state.dispatchBatches.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("No dispatch batches created today.", color = Color(0xFF64748B))
                        Button(
                            onClick = { isCreateDialogOpen = true },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
                        ) {
                            Text("Create First Dispatch Batch")
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    items(state.dispatchBatches, key = { it.id }) { batch ->
                        DispatchBatchCard(
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
private fun DispatchBatchCard(
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
        isDelivered -> "DELIVERED"
        isHandedOver -> "HANDED OVER (OUT FOR DELIVERY)"
        else -> "READY FOR HANDOVER"
    }
    val statusColor = when {
        isDelivered -> Color(0xFF166534)
        isHandedOver -> Color(0xFF0369A1)
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = batch.batchCode,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Orders: ${batch.totalOrders} • Cartons: ${batch.totalCartons}",
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

            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF64748B), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    text = if (batch.deliveryExecutiveName != null) "Assigned Driver: ${batch.deliveryExecutiveName}" else "Unassigned Driver",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF334155)
                )
            }

            if (!batch.notes.isNullOrBlank()) {
                Text(
                    text = "Notes: ${batch.notes}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF64748B)
                )
            }

            if (!isHandedOver && !isDelivered) {
                Button(
                    onClick = onHandover,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.LocalShipping, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Handover to Driver (गाड़ी रवाना करें)", fontWeight = FontWeight.Bold, color = Color.White)
                }
            } else if (isHandedOver) {
                Surface(
                    color = Color(0xFFF0FDF4),
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                ) {
                    Text(
                        text = "✓ Handed over to driver. Driver will deliver via delivery route.",
                        modifier = Modifier.padding(10.dp),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF166534),
                        fontWeight = FontWeight.Medium
                    )
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
        title = { Text("Create Dispatch Batch / डिस्पैच बैच बनायें", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Select packed orders to include in batch:", fontWeight = FontWeight.SemiBold)
                if (packedOrders.isEmpty()) {
                    Text("No orders currently marked PACKED. Pack orders first in Pick/Pack tab.", color = Color(0xFFDC2626))
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        packedOrders.forEach { orderDto ->
                            val isChecked = selectedOrders.contains(orderDto.id)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        if (isChecked) selectedOrders.remove(orderDto.id)
                                        else selectedOrders.add(orderDto.id)
                                    },
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Checkbox(
                                    checked = isChecked,
                                    onCheckedChange = { check ->
                                        if (check) selectedOrders.add(orderDto.id)
                                        else selectedOrders.remove(orderDto.id)
                                    }
                                )
                                Column(Modifier.padding(start = 6.dp)) {
                                    Text(orderDto.id, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                                    Text("Retailer: ${orderDto.retailerId} (${orderDto.cartonsCount} cartons)", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                                }
                            }
                        }
                    }
                }

                // Driver selector dropdown
                if (drivers.isNotEmpty()) {
                    Text("Assign Delivery Driver:", fontWeight = FontWeight.SemiBold)
                    ExposedDropdownMenuBox(
                        expanded = isDriverExpanded,
                        onExpandedChange = { isDriverExpanded = !isDriverExpanded }
                    ) {
                        val currentDriverName = drivers.find { it.id == selectedDriverId }?.fullName ?: "Select driver"
                        OutlinedTextField(
                            value = currentDriverName,
                            onValueChange = {},
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = isDriverExpanded) },
                            modifier = Modifier.menuAnchor().fillMaxWidth()
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
                }

                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Dispatch Route Notes (e.g. Malviya Nagar morning)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onConfirm(selectedOrders.toList(), selectedDriverId, notesText.trim().takeIf { it.isNotBlank() })
                },
                enabled = selectedOrders.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Create Dispatch Batch", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
