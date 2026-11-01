package com.routeflow.app.feature.owner

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.Storefront
import com.routeflow.app.core.design.RFColors
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.domain.model.Retailer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun OwnerRetailersScreen(
    state: OwnerMasterState,
    onCreateRetailer: (name: String, beatId: String, address: String, contact: String, creditLimitPaise: Long, paymentTermsDays: Int) -> Unit,
    onUpdateRetailer: (id: String, creditLimitPaise: Long, paymentTermsDays: Int, isActive: Boolean) -> Unit,
    onLoadStockChecks: (retailerId: String) -> Unit = {},
    onClearMessages: () -> Unit,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var showAddDialog by remember { mutableStateOf(false) }
    var editingRetailer by remember { mutableStateOf<Retailer?>(null) }
    var viewingStockCheckRetailer by remember { mutableStateOf<Retailer?>(null) }
    var viewingLedgerRetailer by remember { mutableStateOf<Retailer?>(null) }

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Retailer Network", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text("${state.retailers.size} shops registered across active beats", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
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
                verticalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                items(state.retailers, key = { it.id }) { retailer ->
                    val isCreditOver = retailer.outstandingAmountPaise > retailer.creditLimitPaise
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            // Retailer Store Header
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Surface(
                                    modifier = Modifier.size(44.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    color = if (isCreditOver) RFColors.DangerSurface else RFColors.InfoSurface
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            Icons.Default.Storefront,
                                            contentDescription = null,
                                            tint = if (isCreditOver) RFColors.Danger else RFColors.Primary,
                                            modifier = Modifier.size(24.dp)
                                        )
                                    }
                                }

                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(
                                        text = retailer.name,
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = RFColors.TextPrimary
                                    )
                                    Text(
                                        text = "${retailer.address} · ${retailer.contactNumber}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = RFColors.TextSecondary
                                    )
                                }

                                Surface(
                                    color = if (isCreditOver) RFColors.DangerSurface else RFColors.SuccessSurface,
                                    shape = CircleShape,
                                    border = BorderStroke(1.dp, if (isCreditOver) RFColors.Danger.copy(alpha = 0.3f) else RFColors.Success.copy(alpha = 0.3f))
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(5.dp)
                                                .background(if (isCreditOver) RFColors.Danger else RFColors.Success, CircleShape)
                                        )
                                        Text(
                                            text = if (isCreditOver) "Over Limit" else "Credit OK",
                                            style = MaterialTheme.typography.labelSmall,
                                            fontWeight = FontWeight.Bold,
                                            color = if (isCreditOver) RFColors.Danger else RFColors.Success
                                        )
                                    }
                                }
                            }

                            // Financial Summary Surface
                            Surface(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(12.dp),
                                color = RFColors.NeutralLight,
                                border = BorderStroke(1.dp, RFColors.Border.copy(alpha = 0.6f))
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp).fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Text("Credit Limit", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
                                        Text(
                                            CurrencyFormatter.formatPaise(retailer.creditLimitPaise),
                                            style = MaterialTheme.typography.bodyMedium,
                                            fontWeight = FontWeight.SemiBold,
                                            color = RFColors.TextPrimary
                                        )
                                    }
                                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                        Text("Outstanding Udhaar", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
                                        Text(
                                            CurrencyFormatter.formatPaise(retailer.outstandingAmountPaise),
                                            style = MaterialTheme.typography.titleSmall,
                                            fontWeight = FontWeight.Bold,
                                            color = if (isCreditOver) RFColors.Danger else RFColors.Primary
                                        )
                                    }
                                }
                            }

                            HorizontalDivider(color = RFColors.Border.copy(alpha = 0.6f))

                            // Action buttons: Call, WhatsApp, Ledger, Stock Audit, Edit
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    // Call Shortcut
                                    Surface(
                                        shape = CircleShape,
                                        color = RFColors.SuccessSurface,
                                        modifier = Modifier.size(34.dp)
                                    ) {
                                        IconButton(
                                            onClick = {
                                                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${retailer.contactNumber}"))
                                                context.startActivity(dialIntent)
                                            }
                                        ) {
                                            Icon(Icons.Default.Phone, contentDescription = "Call", tint = RFColors.Success, modifier = Modifier.size(16.dp))
                                        }
                                    }

                                    // WhatsApp Shortcut
                                    Surface(
                                        shape = CircleShape,
                                        color = RFColors.InfoSurface,
                                        modifier = Modifier.size(34.dp)
                                    ) {
                                        IconButton(
                                            onClick = {
                                                val cleanPhone = retailer.contactNumber.replace("+91", "").replace(" ", "").replace("-", "").trim()
                                                val waIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/91$cleanPhone"))
                                                context.startActivity(waIntent)
                                            }
                                        ) {
                                            Icon(Icons.Default.Send, contentDescription = "WhatsApp", tint = RFColors.Primary, modifier = Modifier.size(16.dp))
                                        }
                                    }

                                    // Quick Ledger
                                    OutlinedButton(
                                        onClick = { viewingLedgerRetailer = retailer },
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 2.dp),
                                        shape = CircleShape,
                                        border = BorderStroke(1.dp, RFColors.Border),
                                        modifier = Modifier.height(34.dp)
                                    ) {
                                        Icon(Icons.Default.ReceiptLong, contentDescription = null, tint = RFColors.TextPrimary, modifier = Modifier.size(14.dp))
                                        Spacer(Modifier.width(4.dp))
                                        Text("Ledger", style = MaterialTheme.typography.labelSmall, color = RFColors.TextPrimary)
                                    }
                                }

                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Surface(
                                        shape = CircleShape,
                                        color = RFColors.InfoSurface,
                                        modifier = Modifier.size(34.dp)
                                    ) {
                                        IconButton(
                                            onClick = {
                                                viewingStockCheckRetailer = retailer
                                                onLoadStockChecks(retailer.id)
                                            },
                                            modifier = Modifier.testTag("stock_checks_${retailer.id}")
                                        ) {
                                            Icon(Icons.Default.Inventory, contentDescription = "Shelf Stock", tint = RFColors.Primary, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                    Surface(
                                        shape = CircleShape,
                                        color = RFColors.NeutralLight,
                                        border = BorderStroke(1.dp, RFColors.Border),
                                        modifier = Modifier.size(34.dp)
                                    ) {
                                        IconButton(
                                            onClick = { editingRetailer = retailer },
                                            modifier = Modifier.testTag("edit_retailer_${retailer.id}")
                                        ) {
                                            Icon(Icons.Default.Edit, contentDescription = "Edit Retailer", tint = RFColors.TextSecondary, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { showAddDialog = true },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(bottom = 90.dp, end = 16.dp)
                .testTag("onboard_retailer_fab"),
            containerColor = MaterialTheme.colorScheme.primary
        ) {
            Icon(Icons.Default.Add, contentDescription = "Onboard Retailer", tint = Color.White)
        }
    }

    if (showAddDialog) {
        OnboardRetailerDialog(
            beats = state.beats,
            onDismiss = { showAddDialog = false },
            onConfirm = { name, beat, addr, contact, limit, terms ->
                onCreateRetailer(name, beat, addr, contact, limit, terms)
                showAddDialog = false
            }
        )
    }

    editingRetailer?.let { ret ->
        EditRetailerDialog(
            retailer = ret,
            onDismiss = { editingRetailer = null },
            onConfirm = { limit, terms, active ->
                onUpdateRetailer(ret.id, limit, terms, active)
                editingRetailer = null
            }
        )
    }

    viewingStockCheckRetailer?.let { ret ->
        RetailerStockCheckHistoryDialog(
            retailer = ret,
            stockChecks = state.stockChecks[ret.id] ?: emptyList(),
            isLoading = state.isLoadingStockChecks,
            onDismiss = { viewingStockCheckRetailer = null }
        )
    }

    viewingLedgerRetailer?.let { ret ->
        RetailerLedgerDialog(
            retailer = ret,
            onDismiss = { viewingLedgerRetailer = null }
        )
    }
}

@Composable
private fun RetailerLedgerDialog(
    retailer: Retailer,
    onDismiss: () -> Unit
) {
    val headroom = maxOf(0L, retailer.creditLimitPaise - retailer.outstandingAmountPaise)
    val isOver = retailer.outstandingAmountPaise > retailer.creditLimitPaise

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("${retailer.name} · Khata Summary", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "${retailer.address} · Beat: ${retailer.beatId}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary
                )

                HorizontalDivider()

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Current Outstanding (Udhaar):", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        CurrencyFormatter.formatPaise(retailer.outstandingAmountPaise),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isOver) Color(0xFFDC2626) else Color(0xFF2563EB)
                    )
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Sanctioned Credit Limit:", style = MaterialTheme.typography.bodyMedium)
                    Text(CurrencyFormatter.formatPaise(retailer.creditLimitPaise), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Available Credit Headroom:", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        CurrencyFormatter.formatPaise(headroom),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isOver) Color(0xFFDC2626) else Color(0xFF16A34A)
                    )
                }

                HorizontalDivider()

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Credit Health Status:", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        if (isOver) "Limit Exceeded" else "Normal Standing",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isOver) Color(0xFFDC2626) else Color(0xFF16A34A)
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Close", fontWeight = FontWeight.Bold)
            }
        }
    )
}

@Composable
private fun RetailerStockCheckHistoryDialog(
    retailer: Retailer,
    stockChecks: List<com.routeflow.app.core.network.dto.RetailerStockCheckItemDto>,
    isLoading: Boolean,
    onDismiss: () -> Unit
) {
    val dateFormat = remember { SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text("Shelf Stock Audit", fontWeight = FontWeight.Bold)
                Text(retailer.name, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
            }
        },
        text = {
            Box(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else if (stockChecks.isEmpty()) {
                    Text(
                        "No in-store stock checks reported for this retailer yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.secondary,
                        modifier = Modifier.padding(16.dp)
                    )
                } else {
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(stockChecks) { item ->
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                            ) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(item.productName, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                                        Text("${item.quantity} units", fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.primary)
                                    }
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text("Shelf Stock Audit", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                                        Text(dateFormat.format(Date(item.createdAt)), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                                    }

                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Close", fontWeight = FontWeight.Bold)
            }
        }
    )
}

@Composable
private fun OnboardRetailerDialog(
    beats: List<com.routeflow.app.core.network.dto.BeatDto> = emptyList(),
    onDismiss: () -> Unit,
    onConfirm: (name: String, beatId: String, address: String, contact: String, creditLimitPaise: Long, paymentTermsDays: Int) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var beatId by remember { mutableStateOf(beats.firstOrNull()?.id ?: "BEAT-01") }
    var address by remember { mutableStateOf("") }
    var contact by remember { mutableStateOf("") }
    var creditLimitRs by remember { mutableStateOf("50000") }
    var paymentTermsDays by remember { mutableStateOf("15") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Onboard New Retailer", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Shop / Business Name *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = contact, onValueChange = { contact = it }, label = { Text("Contact Phone *") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone), modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = address, onValueChange = { address = it }, label = { Text("Market / Address *") }, singleLine = true, modifier = Modifier.fillMaxWidth())

                if (beats.isNotEmpty()) {
                    Text("Beat Assignment:", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                    beats.forEach { beat ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(
                                selected = beatId == beat.id,
                                onClick = { beatId = beat.id }
                            )
                            Text(beat.name, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                } else {
                    OutlinedTextField(value = beatId, onValueChange = { beatId = it }, label = { Text("Beat ID") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = creditLimitRs, onValueChange = { creditLimitRs = it }, label = { Text("Credit Limit (₹)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.weight(1f))
                    OutlinedTextField(value = paymentTermsDays, onValueChange = { paymentTermsDays = it }, label = { Text("Terms (Days)") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val limitPaise = ((creditLimitRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    val terms = paymentTermsDays.toIntOrNull() ?: 15
                    if (name.isNotBlank() && contact.isNotBlank() && address.isNotBlank()) {
                        onConfirm(name, beatId, address, contact, limitPaise, terms)
                    }
                }
            ) {
                Text("Onboard Shop")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
private fun EditRetailerDialog(
    retailer: Retailer,
    onDismiss: () -> Unit,
    onConfirm: (creditLimitPaise: Long, paymentTermsDays: Int, isActive: Boolean) -> Unit
) {
    var creditLimitRs by remember { mutableStateOf((retailer.creditLimitPaise / 100.0).toString()) }
    var paymentTermsDays by remember { mutableStateOf("15") }
    var isActive by remember { mutableStateOf(true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit: ${retailer.name}", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = creditLimitRs,
                    onValueChange = { creditLimitRs = it },
                    label = { Text("Credit Limit (₹)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = paymentTermsDays,
                    onValueChange = { paymentTermsDays = it },
                    label = { Text("Payment Terms (Days)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Shop Active in Territory", fontWeight = FontWeight.Medium)
                    Switch(checked = isActive, onCheckedChange = { isActive = it })
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val limitPaise = ((creditLimitRs.toDoubleOrNull() ?: 0.0) * 100).toLong()
                    val terms = paymentTermsDays.toIntOrNull() ?: 15
                    onConfirm(limitPaise, terms, isActive)
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
