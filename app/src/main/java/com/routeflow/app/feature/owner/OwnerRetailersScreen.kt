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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import com.routeflow.app.domain.model.Retailer

@Composable
fun OwnerRetailersScreen(
    state: OwnerMasterState,
    onCreateRetailer: (name: String, beatId: String, address: String, contact: String, creditLimitPaise: Long, paymentTermsDays: Int) -> Unit,
    onUpdateRetailer: (id: String, creditLimitPaise: Long, paymentTermsDays: Int, isActive: Boolean) -> Unit,
    onClearMessages: () -> Unit,
    onBack: () -> Unit
) {
    var showAddDialog by remember { mutableStateOf(false) }
    var editingRetailer by remember { mutableStateOf<Retailer?>(null) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                modifier = Modifier.testTag("onboard_retailer_fab"),
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Onboard Retailer", tint = Color.White)
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
                    Text("Retailer Network", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text("${state.retailers.size} shops registered across beats", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
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
                items(state.retailers, key = { it.id }) { retailer ->
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
                                Text(retailer.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                                Text("${retailer.address} · ${retailer.contactNumber}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                                Spacer(Modifier.height(4.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                    Text("Credit Limit: ${CurrencyFormatter.formatPaise(retailer.creditLimitPaise)}", style = MaterialTheme.typography.bodySmall)
                                    Text(
                                        "Outstanding: ${CurrencyFormatter.formatPaise(retailer.outstandingAmountPaise)}",
                                        style = MaterialTheme.typography.bodySmall,
                                        fontWeight = FontWeight.Bold,
                                        color = if (retailer.outstandingAmountPaise > retailer.creditLimitPaise) Color(0xFFDC2626) else MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                            IconButton(onClick = { editingRetailer = retailer }, modifier = Modifier.testTag("edit_retailer_${retailer.id}")) {
                                Icon(Icons.Default.Edit, contentDescription = "Edit Retailer", tint = MaterialTheme.colorScheme.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAddDialog) {
        OnboardRetailerDialog(
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
}

@Composable
private fun OnboardRetailerDialog(
    onDismiss: () -> Unit,
    onConfirm: (name: String, beatId: String, address: String, contact: String, creditLimitPaise: Long, paymentTermsDays: Int) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var beatId by remember { mutableStateOf("BEAT-04") }
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
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(value = beatId, onValueChange = { beatId = it }, label = { Text("Beat ID") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(value = paymentTermsDays, onValueChange = { paymentTermsDays = it }, label = { Text("Terms (Days)") }, modifier = Modifier.weight(1f), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
                }
                OutlinedTextField(value = creditLimitRs, onValueChange = { creditLimitRs = it }, label = { Text("Credit Limit (₹)") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true, modifier = Modifier.fillMaxWidth())
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
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Account Active", style = MaterialTheme.typography.bodyMedium)
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
                Text("Save Terms")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
