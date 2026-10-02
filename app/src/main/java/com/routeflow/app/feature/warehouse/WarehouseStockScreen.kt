package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Product
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WarehouseStockScreen(
    products: List<Product>,
    onAdjustStock: (productId: String, changeQty: Int, reason: String, notes: String?) -> Unit,
    onCreateBatch: ((productId: String, batchNo: String, qty: Int, expiryDate: Long?, rackBin: String?) -> Unit)? = null
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var selectedProductForAdjustment by remember { mutableStateOf<Product?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = stringResource(R.string.tab_stock),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Black,
                color = RFColors.TextPrimary
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(products, key = { it.id }) { product ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = product.name,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Text(
                                    text = "${product.category} · ₹${product.pricePaise / 100} / unit",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary
                                )
                                Text(
                                    text = "Stock: ${product.stockQuantity} units available",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (product.stockQuantity > 20) RFColors.Success else RFColors.Warning
                                )
                            }

                            Button(
                                onClick = { selectedProductForAdjustment = product },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = RFColors.Primary,
                                    contentColor = Color.White
                                )
                            ) {
                                Text(
                                    text = "Inbound / Receipt",
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }
            }
        }
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }

    selectedProductForAdjustment?.let { product ->
        StockReceiptDialog(
            product = product,
            onDismiss = { selectedProductForAdjustment = null },
            onConfirm = { batchNo, qty, expiryDays, rackBin, notes ->
                if (!batchNo.isNullOrBlank() && onCreateBatch != null) {
                    val expiryEpoch = expiryDays?.let { days ->
                        (System.currentTimeMillis() / 1000) + (days * 86400L)
                    }
                    onCreateBatch(product.id, batchNo.trim(), qty, expiryEpoch, rackBin?.trim()?.takeIf { it.isNotBlank() })
                    scope.launch {
                        snackbarHostState.showSnackbar("Batch $batchNo ($qty units) received for ${product.name}")
                    }
                } else {
                    onAdjustStock(product.id, qty, "PURCHASE_RECEIPT", notes)
                    scope.launch {
                        snackbarHostState.showSnackbar("Received $qty units of ${product.name}")
                    }
                }
                selectedProductForAdjustment = null
            }
        )
    }
}

@Composable
private fun StockReceiptDialog(
    product: Product,
    onDismiss: () -> Unit,
    onConfirm: (batchNo: String?, qty: Int, expiryDays: Int?, rackBin: String?, notes: String?) -> Unit
) {
    var batchNoText by remember { mutableStateOf("") }
    var qtyText by remember { mutableStateOf("") }
    var rackBinText by remember { mutableStateOf("") }
    var expiryDaysText by remember { mutableStateOf("") }
    var notesText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Goods Receipt (GRN): ${product.name}", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Current Stock: ${product.stockQuantity} units", color = RFColors.TextSecondary)
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it },
                    label = { Text("Received Quantity (Units) *") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = batchNoText,
                    onValueChange = { batchNoText = it },
                    label = { Text("Batch / Lot No. * (e.g. B-2026-01)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = rackBinText,
                    onValueChange = { rackBinText = it },
                    label = { Text("Rack / Bin Location (e.g. A2-Bin4)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = expiryDaysText,
                    onValueChange = { expiryDaysText = it },
                    label = { Text("Shelf Life in Days (e.g. 180)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = notesText,
                    onValueChange = { notesText = it },
                    label = { Text("Supplier Challan No. / Notes (Optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val qty = qtyText.toIntOrNull() ?: 0
                    val expiryDays = expiryDaysText.toIntOrNull()
                    onConfirm(
                        batchNoText.trim().takeIf { it.isNotBlank() },
                        qty,
                        expiryDays,
                        rackBinText.trim().takeIf { it.isNotBlank() },
                        notesText.trim().takeIf { it.isNotBlank() }
                    )
                },
                enabled = (qtyText.toIntOrNull() ?: 0) > 0,
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.Primary,
                    contentColor = Color.White
                )
            ) {
                Text("Record GRN", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
