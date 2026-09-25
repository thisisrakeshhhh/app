package com.routeflow.app.feature.owner

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.domain.model.Product

@Composable
fun OwnerProductsScreen(
    state: OwnerMasterState,
    onCreateProduct: (name: String, category: String, pricePaise: Long, mrpPaise: Long, stock: Int, unit: String, sku: String?) -> Unit,
    onUpdateProduct: (id: String, name: String, category: String, pricePaise: Long, mrpPaise: Long, unit: String, isActive: Boolean) -> Unit,
    onAdjustStock: (productId: String, type: String, qty: Int, reason: String, notes: String) -> Unit,
    onClearMessages: () -> Unit,
    onBack: () -> Unit
) {
    var showAddDialog by remember { mutableStateOf(false) }
    var editingProduct by remember { mutableStateOf<Product?>(null) }
    var adjustingProduct by remember { mutableStateOf<Product?>(null) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                modifier = Modifier.testTag("add_product_fab"),
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Product", tint = Color.White)
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Product Catalog", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text("${state.products.size} products registered", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                }
                OutlinedButton(onClick = onBack) {
                    Text("Back")
                }
            }

            if (state.successMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFECFDF5)),
                    border = BorderStroke(1.dp, Color(0xFF10B981))
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF10B981))
                        Text(state.successMessage, style = MaterialTheme.typography.bodyMedium, color = Color(0xFF065F46), modifier = Modifier.weight(1f))
                        IconButton(onClick = onClearMessages) { Text("×", fontWeight = FontWeight.Bold) }
                    }
                }
            }

            if (state.errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                    border = BorderStroke(1.dp, Color(0xFFEF4444))
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = Color(0xFFEF4444))
                        Text(state.errorMessage, style = MaterialTheme.typography.bodyMedium, color = Color(0xFF991B1B), modifier = Modifier.weight(1f))
                        IconButton(onClick = onClearMessages) { Text("×", fontWeight = FontWeight.Bold) }
                    }
                }
            }

            if (state.isLoading) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                    CircularProgressIndicator(Modifier.size(24.dp))
                }
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(state.products, key = { it.id }) { product ->
                    ProductItemCard(
                        product = product,
                        onEdit = { editingProduct = product },
                        onAdjustStock = { adjustingProduct = product }
                    )
                }
            }
        }
    }

    if (showAddDialog) {
        AddProductDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { name, cat, price, mrp, stock, unit, sku ->
                onCreateProduct(name, cat, price, mrp, stock, unit, sku)
                showAddDialog = false
            }
        )
    }

    editingProduct?.let { prod ->
        EditProductDialog(
            product = prod,
            onDismiss = { editingProduct = null },
            onConfirm = { name, cat, price, mrp, unit, active ->
                onUpdateProduct(prod.id, name, cat, price, mrp, unit, active)
                editingProduct = null
            }
        )
    }

    adjustingProduct?.let { prod ->
        AdjustStockDialog(
            product = prod,
            onDismiss = { adjustingProduct = null },
            onConfirm = { type, qty, reason, notes ->
                onAdjustStock(prod.id, type, qty, reason, notes)
                adjustingProduct = null
            }
        )
    }
}

@Composable
private fun ProductItemCard(
    product: Product,
    onEdit: () -> Unit,
    onAdjustStock: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier.padding(14.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(product.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text("${product.category} · ${product.unit}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Wholesale: ${CurrencyFormatter.formatPaise(product.pricePaise)}", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                    Text("Stock: ${product.stockQuantity}", style = MaterialTheme.typography.bodySmall, color = if (product.stockQuantity < 20) Color(0xFFDC2626) else Color(0xFF16A34A), fontWeight = FontWeight.Bold)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(onClick = onAdjustStock, modifier = Modifier.testTag("adjust_stock_${product.id}")) {
                    Icon(Icons.Default.Inventory, contentDescription = "Adjust Stock", tint = MaterialTheme.colorScheme.primary)
                }
                IconButton(onClick = onEdit, modifier = Modifier.testTag("edit_product_${product.id}")) {
                    Icon(Icons.Default.Edit, contentDescription = "Edit Product", tint = MaterialTheme.colorScheme.secondary)
                }
            }
        }
    }
}

@Composable
private fun AddProductDialog(
    onDismiss: () -> Unit,
    onConfirm: (name: String, category: String, pricePaise: Long, mrpPaise: Long, stock: Int, unit: String, sku: String?) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var sku by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("Groceries") }
    var unit by remember { mutableStateOf("Pack") }
    var priceRs by remember { mutableStateOf("") }
    var mrpRs by remember { mutableStateOf("") }
    var initialStock by remember { mutableStateOf("50") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add New Product", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Product Name *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = sku, onValueChange = { sku = it }, label = { Text("SKU / Barcode") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = category, onValueChange = { category = it }, label = { Text("Category") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(value = unit, onValueChange = { unit = it }, label = { Text("Unit (Pack/kg)") }, modifier = Modifier.weight(1f), singleLine = true)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = priceRs, onValueChange = { priceRs = it }, label = { Text("Wholesale Price (₹) *") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                    OutlinedTextField(value = mrpRs, onValueChange = { mrpRs = it }, label = { Text("MRP (₹)") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                }
                OutlinedTextField(value = initialStock, onValueChange = { initialStock = it }, label = { Text("Initial Stock Qty") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val pricePaise = ((priceRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    val mrpPaise = ((mrpRs.toDoubleOrNull() ?: priceRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    val stock = initialStock.toIntOrNull() ?: 0
                    if (name.isNotBlank() && pricePaise > 0) {
                        onConfirm(name, category, pricePaise, mrpPaise, stock, unit, sku.ifBlank { null })
                    }
                }
            ) {
                Text("Create Product")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
private fun EditProductDialog(
    product: Product,
    onDismiss: () -> Unit,
    onConfirm: (name: String, category: String, pricePaise: Long, mrpPaise: Long, unit: String, isActive: Boolean) -> Unit
) {
    var name by remember { mutableStateOf(product.name) }
    var category by remember { mutableStateOf(product.category) }
    var unit by remember { mutableStateOf(product.unit) }
    var priceRs by remember { mutableStateOf((product.pricePaise / 100.0).toString()) }
    var mrpRs by remember { mutableStateOf((product.pricePaise / 100.0 * 1.2).toString()) }
    var isActive by remember { mutableStateOf(true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Product", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = category, onValueChange = { category = it }, label = { Text("Category") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(value = unit, onValueChange = { unit = it }, label = { Text("Unit") }, modifier = Modifier.weight(1f), singleLine = true)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = priceRs, onValueChange = { priceRs = it }, label = { Text("Wholesale ₹") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                    OutlinedTextField(value = mrpRs, onValueChange = { mrpRs = it }, label = { Text("MRP ₹") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                }
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Active for Sales Orders", style = MaterialTheme.typography.bodyMedium)
                    Switch(checked = isActive, onCheckedChange = { isActive = it })
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val pricePaise = ((priceRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    val mrpPaise = ((mrpRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    if (name.isNotBlank() && pricePaise > 0) {
                        onConfirm(name, category, pricePaise, mrpPaise, unit, isActive)
                    }
                }
            ) {
                Text("Save Changes")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
private fun AdjustStockDialog(
    product: Product,
    onDismiss: () -> Unit,
    onConfirm: (type: String, qty: Int, reason: String, notes: String) -> Unit
) {
    var adjustmentType by remember { mutableStateOf("RECEIPT") } // RECEIPT or CORRECTION
    var qtyText by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("STOCK_RECEIPT") }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Stock Audit: ${product.name}", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Current Stock: ${product.stockQuantity} ${product.unit}", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { 
                            adjustmentType = "RECEIPT"
                            reason = "STOCK_RECEIPT"
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (adjustmentType == "RECEIPT") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Add Stock (+)")
                    }
                    Button(
                        onClick = { 
                            adjustmentType = "CORRECTION"
                            reason = "AUDIT_CORRECTION"
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (adjustmentType == "CORRECTION") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.surfaceVariant
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Audit (- / +)")
                    }
                }
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it },
                    label = { Text(if (adjustmentType == "RECEIPT") "Quantity Received *" else "Adjustment Delta (+/-) *") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Audit Note / Invoice Reference *") },
                    placeholder = { Text("e.g. Supplier Inv #4829 or Physical count discrepancy") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val qty = qtyText.toIntOrNull() ?: 0
                    if (qty != 0 && notes.isNotBlank()) {
                        onConfirm(adjustmentType, qty, reason, notes)
                    }
                }
            ) {
                Text("Confirm Audit")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
