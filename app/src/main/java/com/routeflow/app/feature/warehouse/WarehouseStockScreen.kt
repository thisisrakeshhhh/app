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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.CreateWarehouseBatchRequest
import com.routeflow.app.core.network.dto.WarehouseStockItemDto

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WarehouseStockScreen(
    state: WarehouseStockUiState,
    onSearchChange: (String) -> Unit,
    onFilterChange: (String) -> Unit,
    onOpenScanner: () -> Unit,
    onAdjustStock: (productId: String, changeQty: Int, reason: String, notes: String?, batchId: String?) -> Unit,
    onAuditStock: (productId: String, physicalCount: Int, notes: String?) -> Unit,
    onCreateBatch: (CreateWarehouseBatchRequest) -> Unit
) {
    var selectedProductForAdjustment by remember { mutableStateOf<WarehouseStockItemDto?>(null) }
    var selectedProductForInward by remember { mutableStateOf<WarehouseStockItemDto?>(null) }
    var selectedProductForAudit by remember { mutableStateOf<WarehouseStockItemDto?>(null) }
    var viewingProductDetails by remember { mutableStateOf<WarehouseStockItemDto?>(null) }

    Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC))) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
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
                            text = "Godown Stock",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Black,
                            color = Color(0xFF0F172A)
                        )
                        Text(text = "•", color = Color(0xFF94A3B8))
                        Text(
                            text = "गोदाम स्टॉक और बैच",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                    Text(
                        text = "Real-time stock counts, FEFO batches & inward GRN",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Spacer(Modifier.width(6.dp))

                Button(
                    onClick = onOpenScanner,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.height(48.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp)
                ) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = "Scan", tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Scan", fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
                }
            }

            // Search Bar (Sticky at top)
            OutlinedTextField(
                value = state.searchQuery,
                onValueChange = onSearchChange,
                placeholder = { Text("Search name, SKU, category or barcode...", color = Color(0xFF94A3B8), fontSize = 13.sp) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF64748B)) },
                trailingIcon = {
                    if (state.searchQuery.isNotEmpty()) {
                        IconButton(onClick = { onSearchChange("") }) {
                            Icon(Icons.Default.Close, contentDescription = "Clear")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp),
                singleLine = true
            )

            // Filter Chips
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                val filters = listOf(
                    "ALL" to "All Stock",
                    "LOW_STOCK" to "Low Stock",
                    "NEAR_EXPIRY" to "Near Expiry",
                    "OUT_OF_STOCK" to "Out of Stock",
                    "DAMAGED" to "Damaged"
                )
                items(filters) { (key, label) ->
                    val isSelected = state.activeFilter == key
                    FilterChip(
                        selected = isSelected,
                        onClick = { onFilterChange(key) },
                        label = { Text(label, style = MaterialTheme.typography.labelSmall, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
                        shape = RoundedCornerShape(6.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(0xFF2563EB),
                            selectedLabelColor = Color.White
                        )
                    )
                }
            }

            if (state.isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (state.products.isEmpty()) {
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
                            text = "No stock found. Add inward stock or sync godown data.",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF334155),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                        OutlinedButton(
                            onClick = {
                                onSearchChange("")
                                onFilterChange("ALL")
                            },
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.height(48.dp)
                        ) {
                            Text("Clear Filters", fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(bottom = 120.dp)
                ) {
                    items(state.products, key = { it.id }) { item ->
                        CompactProductStockRow(
                            item = item,
                            onClick = { viewingProductDetails = item }
                        )
                    }
                }
            }
        }
    }

    // Modal Bottom Sheet: Product Details & Batches
    viewingProductDetails?.let { item ->
        ProductDetailBottomSheet(
            item = item,
            onDismiss = { viewingProductDetails = null },
            onInward = {
                viewingProductDetails = null
                selectedProductForInward = item
            },
            onAdjust = {
                viewingProductDetails = null
                selectedProductForAdjustment = item
            }
        )
    }

    // Dialog: Inward Stock GRN / New Batch
    selectedProductForInward?.let { item ->
        WarehouseInwardDialog(
            item = item,
            onDismiss = { selectedProductForInward = null },
            onConfirm = { batchNo, qty, purchasePrice, mfgEpoch, expEpoch, rackBin, supplier ->
                onCreateBatch(
                    CreateWarehouseBatchRequest(
                        productId = item.id,
                        batchNo = batchNo,
                        receivedQuantity = qty,
                        purchasePricePaise = purchasePrice,
                        mfgDate = mfgEpoch,
                        expiryDate = expEpoch,
                        rackBin = rackBin,
                        supplierName = supplier
                    )
                )
                selectedProductForInward = null
            }
        )
    }

    // Dialog: Stock Adjustment (Damage / Correction)
    selectedProductForAdjustment?.let { item ->
        WarehouseStockAdjustDialog(
            item = item,
            onDismiss = { selectedProductForAdjustment = null },
            onConfirm = { changeQty, reason, notes, batchId ->
                onAdjustStock(item.id, changeQty, reason, notes, batchId)
                selectedProductForAdjustment = null
            }
        )
    }

    // Dialog: Physical Stock Audit
    selectedProductForAudit?.let { item ->
        WarehouseStockAuditDialog(
            item = item,
            onDismiss = { selectedProductForAudit = null },
            onConfirm = { physicalCount, notes ->
                onAuditStock(item.id, physicalCount, notes)
                selectedProductForAudit = null
            }
        )
    }
}

@Composable
private fun CompactProductStockRow(
    item: WarehouseStockItemDto,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.5.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Category / Thumbnail icon
            Surface(
                color = Color(0xFFF1F5F9),
                shape = RoundedCornerShape(6.dp),
                modifier = Modifier.size(38.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Default.Inventory2,
                        contentDescription = null,
                        tint = Color(0xFF475569),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Info column
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = item.name,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    if (item.stockQuantity <= 10) {
                        Surface(
                            color = Color(0xFFFEF3C7),
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Text(
                                text = "Low Stock",
                                modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFB45309),
                                fontSize = 10.sp
                            )
                        }
                    }
                }

                Text(
                    text = "${item.category} • SKU: ${item.sku ?: item.id.take(8)}${if (!item.barcode.isNullOrBlank()) " • " + item.barcode else ""}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "Available: ${item.availableQuantity}",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF16A34A)
                    )
                    Text(
                        text = "•",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFFCBD5E1)
                    )
                    Text(
                        text = "Reserved: ${item.reservedQuantity}",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF64748B)
                    )
                    if (item.batchCount > 0) {
                        Text(
                            text = "•",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFFCBD5E1)
                        )
                        Text(
                            text = "${item.batchCount} batches",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFF2563EB)
                        )
                    }
                }
            }

            // Total stock pill + Tap chevron
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Surface(
                    color = if (item.stockQuantity <= 10) Color(0xFFFFFBEB) else Color(0xFFF0FDF4),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, if (item.stockQuantity <= 10) Color(0xFFFDE68A) else Color(0xFFBBF7D0))
                ) {
                    Text(
                        text = "${item.stockQuantity}",
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                        color = if (item.stockQuantity <= 10) Color(0xFFB45309) else Color(0xFF15803D)
                    )
                }
                Text(
                    text = "Total Pcs",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF94A3B8),
                    fontSize = 10.sp
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProductDetailBottomSheet(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onInward: () -> Unit,
    onAdjust: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 10.dp)
                .navigationBarsPadding()
                .padding(bottom = 36.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = item.name,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Category: ${item.category} • Wholesale: ₹${item.pricePaise / 100}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF64748B)
                    )
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Stock Summary (3 cards)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                StockMetricCard(
                    modifier = Modifier.weight(1f),
                    label = "Total Stock",
                    value = "${item.stockQuantity}",
                    valueColor = Color(0xFF0F172A)
                )
                StockMetricCard(
                    modifier = Modifier.weight(1f),
                    label = "Available",
                    value = "${item.availableQuantity}",
                    valueColor = Color(0xFF16A34A)
                )
                StockMetricCard(
                    modifier = Modifier.weight(1f),
                    label = "Reserved",
                    value = "${item.reservedQuantity}",
                    valueColor = Color(0xFF0284C7)
                )
            }

            // Technical Details & Batch Status
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0))
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    DetailRow(label = "SKU", value = item.sku ?: item.id)
                    DetailRow(label = "Barcode", value = item.barcode ?: "Not assigned")
                    DetailRow(label = "Registered Batches", value = "${item.batchCount} active batch(es)")
                    if (item.damagedQuantity > 0) {
                        DetailRow(label = "Damaged / Quarantine", value = "${item.damagedQuantity} units", valueColor = Color(0xFF991B1B))
                    }
                    DetailRow(label = "Stock Status", value = if (item.stockQuantity <= 10) "Low Stock Alert" else "Healthy Stock", valueColor = if (item.stockQuantity <= 10) Color(0xFFB45309) else Color(0xFF15803D))
                }
            }

            // Primary Actions (Minimum 48dp touch height)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Button(
                    onClick = onInward,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A))
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("+ Add Inward Stock", fontWeight = FontWeight.Bold, color = Color.White)
                }

                OutlinedButton(
                    onClick = onAdjust,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, Color(0xFFEF4444))
                ) {
                    Text("Mark Damaged", fontWeight = FontWeight.Bold, color = Color(0xFFDC2626))
                }
            }
        }
    }
}

@Composable
private fun StockMetricCard(
    modifier: Modifier = Modifier,
    label: String,
    value: String,
    valueColor: Color
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
    ) {
        Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = valueColor)
            Text(label, style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B), maxLines = 1)
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String,
    valueColor: Color = Color(0xFF334155)
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
        Text(text = value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = valueColor)
    }
}

@Composable
private fun WarehouseInwardDialog(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onConfirm: (batchNo: String, qty: Int, purchasePrice: Long?, mfgEpoch: Long?, expEpoch: Long?, rackBin: String?, supplier: String?) -> Unit
) {
    var batchNo by remember { mutableStateOf("B-" + System.currentTimeMillis().toString().takeLast(5)) }
    var qtyText by remember { mutableStateOf("10") }
    var purchasePriceText by remember { mutableStateOf("") }
    var rackBinText by remember { mutableStateOf("RACK-A1") }
    var supplierText by remember { mutableStateOf("Main Factory Depot") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("Add Inward Stock (आवक)", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text("SKU: ${item.name}", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
            }
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = batchNo,
                    onValueChange = { batchNo = it },
                    label = { Text("Batch Number") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it },
                    label = { Text("Received Quantity (Units)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = purchasePriceText,
                    onValueChange = { purchasePriceText = it },
                    label = { Text("Purchase Price (₹, optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = rackBinText,
                    onValueChange = { rackBinText = it },
                    label = { Text("Godown Rack / Bin Location") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = supplierText,
                    onValueChange = { supplierText = it },
                    label = { Text("Supplier / Mill Source") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val qty = qtyText.toIntOrNull() ?: 1
                    val pricePaise = purchasePriceText.toDoubleOrNull()?.let { (it * 100).toLong() }
                    onConfirm(
                        batchNo.trim(),
                        qty,
                        pricePaise,
                        null,
                        null,
                        rackBinText.trim().ifEmpty { null },
                        supplierText.trim().ifEmpty { null }
                    )
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Confirm Inward (दर्ज करें)", fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}

@Composable
private fun WarehouseStockAdjustDialog(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onConfirm: (changeQty: Int, reason: String, notes: String?, batchId: String?) -> Unit
) {
    var changeQtyText by remember { mutableStateOf("-1") }
    var selectedReason by remember { mutableStateOf("DAMAGED") }
    var notesText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("Adjust Stock / Damage", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text(item.name, style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Reason for adjustment:", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    val reasons = listOf("DAMAGED" to "Damaged", "EXPIRED" to "Expired", "CORRECTION" to "Audit")
                    reasons.forEach { (code, label) ->
                        FilterChip(
                            selected = selectedReason == code,
                            onClick = { selectedReason = code },
                            label = { Text(label, style = MaterialTheme.typography.labelSmall) },
                            shape = RoundedCornerShape(6.dp)
                        )
                    }
                }
                OutlinedTextField(
                    value = changeQtyText,
                    onValueChange = { changeQtyText = it },
                    label = { Text("Quantity change (e.g. -2 or 5)") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Notes / Reason") },
                    placeholder = { Text("e.g. Carton wet in monsoon") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val qty = changeQtyText.toIntOrNull() ?: 0
                    if (qty != 0) {
                        onConfirm(qty, selectedReason, notesText.trim().ifEmpty { null }, null)
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626)),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Save Adjustment", fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}

@Composable
private fun WarehouseStockAuditDialog(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onConfirm: (physicalCount: Int, notes: String?) -> Unit
) {
    var countText by remember { mutableStateOf(item.stockQuantity.toString()) }
    var notesText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Physical Stock Audit", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("System Recorded: ${item.stockQuantity} units", style = MaterialTheme.typography.bodyMedium)
                OutlinedTextField(
                    value = countText,
                    onValueChange = { countText = it },
                    label = { Text("Physical Count on Rack") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Audit notes") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val count = countText.toIntOrNull() ?: item.stockQuantity
                    onConfirm(count, notesText.trim().ifEmpty { null })
                },
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Confirm Count", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text("Cancel")
            }
        }
    )
}
