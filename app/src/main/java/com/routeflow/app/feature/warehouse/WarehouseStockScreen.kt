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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory
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
import androidx.compose.ui.unit.dp
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
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Compact Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Godown Stock / स्टॉक बही",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                    Text(
                        text = "Inventory balance, batches & inward GRN",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Spacer(Modifier.width(8.dp))

                Button(
                    onClick = onOpenScanner,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.height(44.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.QrCodeScanner, contentDescription = "Scan", tint = Color.White, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Scan", fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1, softWrap = false)
                }
            }

            // Search Bar
            OutlinedTextField(
                value = state.searchQuery,
                onValueChange = onSearchChange,
                placeholder = { Text("Search name, SKU, category or barcode...") },
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
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                val filters = listOf(
                    "ALL" to "All Stock (सभी)",
                    "LOW_STOCK" to "Low Stock (कम)",
                    "NEAR_EXPIRY" to "Near Expiry (जल्द समाप्ति)",
                    "OUT_OF_STOCK" to "Out of Stock (खत्म)",
                    "DAMAGED" to "Damaged (खराब)"
                )
                items(filters) { (key, label) ->
                    val isSelected = state.activeFilter == key
                    FilterChip(
                        selected = isSelected,
                        onClick = { onFilterChange(key) },
                        label = { Text(label, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal) },
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
                        .padding(bottom = 96.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Surface(
                            color = Color(0xFFEFF6FF),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.size(56.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Default.Inventory, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(28.dp))
                            }
                        }
                        Text(
                            text = "No products found in godown",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF1E293B)
                        )
                        Text(
                            text = "Try clearing filters or search terms",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                        Button(
                            onClick = {
                                onSearchChange("")
                                onFilterChange("ALL")
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.height(48.dp)
                        ) {
                            Text("Reset Filters")
                        }
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(bottom = 96.dp)
                ) {
                    items(state.products, key = { it.id }) { item ->
                        WarehouseProductStockCard(
                            item = item,
                            onView = { viewingProductDetails = item },
                            onInward = { selectedProductForInward = item },
                            onAdjust = { selectedProductForAdjustment = item },
                            onAudit = { selectedProductForAudit = item }
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
private fun WarehouseProductStockCard(
    item: WarehouseStockItemDto,
    onView: () -> Unit,
    onInward: () -> Unit,
    onAdjust: () -> Unit,
    onAudit: () -> Unit
) {
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
                verticalAlignment = Alignment.Top
            ) {
                // Product Thumbnail Placeholder & Basic Info
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Surface(
                        color = Color(0xFFF1F5F9),
                        shape = RoundedCornerShape(6.dp),
                        modifier = Modifier.size(44.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Default.Inventory, contentDescription = null, tint = Color(0xFF475569), modifier = Modifier.size(24.dp))
                        }
                    }
                    Column {
                        Text(
                            text = item.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = "${item.category} • SKU: ${item.sku ?: item.id.take(8)}",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                        if (!item.barcode.isNullOrBlank()) {
                            Text(
                                text = "Barcode: ${item.barcode}",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF2563EB),
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }

                // Current Stock Badge
                val isLow = item.stockQuantity <= 10
                Surface(
                    color = if (isLow) Color(0xFFFEF3C7) else Color(0xFFDCFCE7),
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = "${item.stockQuantity} in stock",
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (isLow) Color(0xFFB45309) else Color(0xFF166534)
                    )
                }
            }

            // Reserved & Batches Info Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = Color(0xFFF8FAFC),
                    shape = RoundedCornerShape(4.dp),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Text(
                        text = "Available: ${item.availableQuantity} • Reserved: ${item.reservedQuantity}",
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF475569)
                    )
                }
                if (item.batchCount > 0) {
                    Surface(
                        color = Color(0xFFEFF6FF),
                        shape = RoundedCornerShape(4.dp)
                    ) {
                        Text(
                            text = "${item.batchCount} batch(es)",
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF2563EB)
                        )
                    }
                }
                if (item.damagedQuantity > 0) {
                    Surface(
                        color = Color(0xFFFEE2E2),
                        shape = RoundedCornerShape(4.dp)
                    ) {
                        Text(
                            text = "Damaged: ${item.damagedQuantity}",
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF991B1B)
                        )
                    }
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Action Buttons (View, Inward, Adjust)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = onView,
                    modifier = Modifier
                        .weight(0.9f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp)
                ) {
                    Icon(Icons.Default.Info, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("View", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                }

                Button(
                    onClick = onInward,
                    modifier = Modifier
                        .weight(1.3f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                    contentPadding = PaddingValues(horizontal = 8.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("+ Inward (आवक)", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
                }

                OutlinedButton(
                    onClick = onAdjust,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp)
                ) {
                    Text("Adjust", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                }
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
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
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

            HorizontalDivider(color = Color(0xFFE2E8F0))

            // Inventory Breakdown
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(8.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${item.stockQuantity}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = Color(0xFF0F172A))
                        Text("Total Stock", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                    }
                }
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(8.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${item.availableQuantity}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = Color(0xFF16A34A))
                        Text("Available", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                    }
                }
                Card(
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(8.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${item.reservedQuantity}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = Color(0xFF0284C7))
                        Text("Reserved", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                    }
                }
            }

            // Technical details
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("SKU: ${item.sku ?: item.id}", style = MaterialTheme.typography.bodyMedium, color = Color(0xFF334155))
                Text("Barcode: ${item.barcode ?: "Not assigned"}", style = MaterialTheme.typography.bodyMedium, color = Color(0xFF334155))
                Text("Active Batches: ${item.batchCount}", style = MaterialTheme.typography.bodyMedium, color = Color(0xFF334155))
                Text("Damaged/Quarantine: ${item.damagedQuantity} units", style = MaterialTheme.typography.bodyMedium, color = Color(0xFF991B1B))
            }

            // CTAs inside bottom sheet
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
                    Text("+ Add Inward Stock", fontWeight = FontWeight.Bold, color = Color.White)
                }

                Button(
                    onClick = onAdjust,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                ) {
                    Text("Mark Damaged / Audit", fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
        }
    }
}

@Composable
private fun WarehouseInwardDialog(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onConfirm: (batchNo: String, qty: Int, purchasePrice: Long?, mfgEpoch: Long?, expEpoch: Long?, rackBin: String?, supplier: String?) -> Unit
) {
    var batchNo by remember { mutableStateOf("B-" + System.currentTimeMillis().toString().takeLast(5)) }
    var qtyText by remember { mutableStateOf("50") }
    var daysToExpiryText by remember { mutableStateOf("180") }
    var rackBinText by remember { mutableStateOf("RACK-A1") }
    var supplierText by remember { mutableStateOf("Jaipur Wholesale Depot") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Inward Stock / आवक माल दर्ज करें", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(item.name, fontWeight = FontWeight.SemiBold, color = Color(0xFF2563EB))
                OutlinedTextField(
                    value = batchNo,
                    onValueChange = { batchNo = it },
                    label = { Text("Batch Number / बैच नंबर *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it },
                    label = { Text("Quantity Received / आवक मात्रा *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = daysToExpiryText,
                    onValueChange = { daysToExpiryText = it },
                    label = { Text("Expiry in Days / समाप्ति दिवस") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = rackBinText,
                    onValueChange = { rackBinText = it },
                    label = { Text("Rack / Bin Location / रैक स्थान") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = supplierText,
                    onValueChange = { supplierText = it },
                    label = { Text("Supplier Name / सप्लायर") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val qty = qtyText.toIntOrNull() ?: 1
                    val days = daysToExpiryText.toLongOrNull() ?: 90L
                    val expEpoch = (System.currentTimeMillis() / 1000) + (days * 86400L)
                    onConfirm(batchNo.trim(), qty, null, null, expEpoch, rackBinText.trim(), supplierText.trim())
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A))
            ) {
                Text("Confirm Inward (आवक करें)", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
private fun WarehouseStockAdjustDialog(
    item: WarehouseStockItemDto,
    onDismiss: () -> Unit,
    onConfirm: (changeQty: Int, reason: String, notes: String?, batchId: String?) -> Unit
) {
    var qtyText by remember { mutableStateOf("1") }
    var isDeduction by remember { mutableStateOf(true) }
    var reason by remember { mutableStateOf("DAMAGE") }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Stock Adjustment / स्टॉक सुधार", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("${item.name} (Current: ${item.stockQuantity})", fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { isDeduction = true },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isDeduction) Color(0xFFDC2626) else Color(0xFFE2E8F0)
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("- Deduct / घटायें", color = if (isDeduction) Color.White else Color.Black)
                    }
                    Button(
                        onClick = { isDeduction = false },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (!isDeduction) Color(0xFF16A34A) else Color(0xFFE2E8F0)
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("+ Add / जोड़ें", color = if (!isDeduction) Color.White else Color.Black)
                    }
                }
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it },
                    label = { Text("Quantity / मात्रा *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = reason,
                    onValueChange = { reason = it },
                    label = { Text("Reason (DAMAGE, EXPIRY, CORRECTION)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes / विवरण") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val rawQty = qtyText.toIntOrNull() ?: 1
                    val change = if (isDeduction) -rawQty else rawQty
                    onConfirm(change, reason.trim(), notes.trim().takeIf { it.isNotBlank() }, null)
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Save Adjustment", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
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
    var notes by remember { mutableStateOf("Physical godown audit count") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Physical Stock Audit / भौतिक गिनती", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(item.name, fontWeight = FontWeight.SemiBold)
                Text("System Book Quantity: ${item.stockQuantity}", color = Color(0xFF64748B))
                OutlinedTextField(
                    value = countText,
                    onValueChange = { countText = it },
                    label = { Text("Physical Count on Shelf / वास्तविक गिनती *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Audit Notes") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val count = countText.toIntOrNull() ?: item.stockQuantity
                    onConfirm(count, notes.trim())
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Reconcile Stock", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
