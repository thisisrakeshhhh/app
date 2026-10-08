package com.routeflow.app.feature.sales

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Retailer
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesCollectionsScreen(
    retailers: List<Retailer>,
    onCollectPayment: (retailerId: String, amountPaise: Long, method: String, reference: String) -> Unit = { _, _, _, _ -> }
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var selectedRetailerForCollection by remember { mutableStateOf<Retailer?>(null) }
    var selectedRetailerForLedger by remember { mutableStateOf<Retailer?>(null) }

    val positiveDuePaise = retailers.filter { it.outstandingAmountPaise > 0 }.sumOf { it.outstandingAmountPaise }
    val advancePaise = retailers.filter { it.outstandingAmountPaise < 0 }.sumOf { -it.outstandingAmountPaise }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = stringResource(R.string.tab_collections),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Black,
                color = RFColors.TextPrimary
            )

            // Total Outstanding & Advance Summary Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF1E3A8A)),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Total Beat Pending Udhaar",
                                style = MaterialTheme.typography.labelMedium,
                                color = Color.White.copy(alpha = 0.85f)
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "₹${"%,d".format(positiveDuePaise / 100)}",
                                style = MaterialTheme.typography.headlineMedium,
                                fontWeight = FontWeight.Black,
                                color = Color.White
                            )
                        }

                        Surface(
                            color = Color(0xFF2563EB).copy(alpha = 0.5f),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Text(
                                text = "${retailers.count { it.outstandingAmountPaise > 0 }} Shops Due",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }

                    if (advancePaise > 0) {
                        Spacer(modifier = Modifier.height(10.dp))
                        HorizontalDivider(color = Color.White.copy(alpha = 0.2f))
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = "Total Advance Credit Held:",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.8f)
                            )
                            Text(
                                text = "₹${"%,d".format(advancePaise / 100)}",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF86EFAC)
                            )
                        }
                    }
                }
            }

            Text(
                text = "Retailer Khata & Udhaar Ledger",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = RFColors.TextPrimary
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (retailers.isEmpty()) {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(32.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Store,
                                    contentDescription = null,
                                    tint = Color(0xFF94A3B8),
                                    modifier = Modifier.size(48.dp)
                                )
                                Spacer(Modifier.height(12.dp))
                                Text(
                                    text = "No shops assigned yet",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = "Ask Owner/Admin to assign your beat.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary,
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                            }
                        }
                    }
                } else {
                    items(retailers, key = { it.id }) { retailer ->
                        RetailerCollectionCard(
                            retailer = retailer,
                            onCollect = { selectedRetailerForCollection = retailer },
                            onViewLedger = { selectedRetailerForLedger = retailer }
                        )
                    }
                }
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }

    // Modal: Collect Payment Dialog
    selectedRetailerForCollection?.let { retailer ->
        CollectPaymentDialog(
            retailer = retailer,
            onDismiss = { selectedRetailerForCollection = null },
            onConfirm = { amountPaise, method, ref ->
                onCollectPayment(retailer.id, amountPaise, method, ref)
                selectedRetailerForCollection = null
                scope.launch {
                    snackbarHostState.showSnackbar("Payment of ₹${amountPaise / 100} recorded for ${retailer.name}")
                }
            }
        )
    }

    // Modal: View Ledger Statement Dialog
    selectedRetailerForLedger?.let { retailer ->
        ViewLedgerDialog(
            retailer = retailer,
            onDismiss = { selectedRetailerForLedger = null }
        )
    }
}

@Composable
private fun RetailerCollectionCard(
    retailer: Retailer,
    onCollect: () -> Unit,
    onViewLedger: () -> Unit
) {
    val outstanding = retailer.outstandingAmountPaise
    val isAdvance = outstanding < 0
    val isPendingDue = outstanding > 0

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(
            1.dp,
            if (isPendingDue && outstanding > (retailer.creditLimitPaise * 0.8)) Color(0xFFFCA5A5) else Color(0xFFE2E8F0)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            // Header Row: Shop Name & Credit Limit
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        text = retailer.name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                    Text(
                        text = retailer.address,
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary,
                        maxLines = 1
                    )
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color(0xFFF8FAFC),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Text(
                        text = "Limit: ₹${"%,d".format(retailer.creditLimitPaise / 100)}",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF475569),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(Modifier.height(10.dp))

            // Outstanding vs Advance Display Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    val (label, amountText, color) = when {
                        isAdvance -> Triple("Advance Balance", "₹${"%,d".format(-outstanding / 100)}", Color(0xFF15803D))
                        isPendingDue -> Triple("Pending Udhaar", "₹${"%,d".format(outstanding / 100)}", Color(0xFFDC2626))
                        else -> Triple("Balance", "No Due", Color(0xFF64748B))
                    }
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelSmall,
                        color = RFColors.TextSecondary
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = amountText,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Black,
                        color = color
                    )
                }

                if (isPendingDue && outstanding > (retailer.creditLimitPaise * 0.8)) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFFEF2F2),
                        border = BorderStroke(1.dp, Color(0xFFFCA5A5))
                    ) {
                        Text(
                            text = "High Risk",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFDC2626),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // Action Buttons: View Ledger & Collect Payment
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedButton(
                    onClick = onViewLedger,
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, Color(0xFFCBD5E1))
                ) {
                    Icon(Icons.Default.Description, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFF475569))
                    Spacer(Modifier.width(6.dp))
                    Text("View Ledger", fontWeight = FontWeight.Bold, color = Color(0xFF475569), fontSize = 13.sp)
                }

                Button(
                    onClick = onCollect,
                    modifier = Modifier
                        .weight(1f)
                        .height(46.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isPendingDue) Color(0xFF2563EB) else Color(0xFF0D9488),
                        contentColor = Color.White
                    )
                ) {
                    Icon(Icons.Default.Payments, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = if (isAdvance) "Add Deposit" else "Collect",
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun CollectPaymentDialog(
    retailer: Retailer,
    onDismiss: () -> Unit,
    onConfirm: (amountPaise: Long, method: String, reference: String) -> Unit
) {
    val outstanding = retailer.outstandingAmountPaise
    val defaultAmount = if (outstanding > 0) (outstanding / 100).toString() else ""
    var amountText by remember { mutableStateOf(defaultAmount) }
    var selectedMethod by remember { mutableStateOf("CASH") }
    var referenceText by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Collect from ${retailer.name}", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (outstanding > 0) {
                    Text(
                        text = "Pending Udhaar: ₹${"%,d".format(outstanding / 100)}",
                        color = Color(0xFFDC2626),
                        fontWeight = FontWeight.Bold
                    )
                } else if (outstanding < 0) {
                    Text(
                        text = "Customer has Advance: ₹${"%,d".format(-outstanding / 100)}",
                        color = Color(0xFF15803D),
                        fontWeight = FontWeight.Bold
                    )
                }

                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it },
                    label = { Text("Collection Amount (₹) *") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp)
                )

                Text("Payment Mode:", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("CASH", "UPI", "CHEQUE").forEach { mode ->
                        FilterChip(
                            selected = selectedMethod == mode,
                            onClick = { selectedMethod = mode },
                            label = { Text(mode, fontWeight = FontWeight.Bold) }
                        )
                    }
                }

                OutlinedTextField(
                    value = referenceText,
                    onValueChange = { referenceText = it },
                    label = { Text("Receipt / Ref Number (Optional)") },
                    placeholder = { Text("e.g. UPI-12345 or Cheque #") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val amt = amountText.toLongOrNull() ?: 0L
                    onConfirm(amt * 100, selectedMethod, referenceText.trim())
                },
                enabled = (amountText.toLongOrNull() ?: 0L) > 0,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Record Receipt", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = Color(0xFF64748B)) }
        }
    )
}

@Composable
private fun ViewLedgerDialog(
    retailer: Retailer,
    onDismiss: () -> Unit
) {
    val outstanding = retailer.outstandingAmountPaise

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, tint = Color(0xFF2563EB))
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(retailer.name, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Text("Khata & Ledger Statement", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                }
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Key Metrics Box
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Credit Limit:", color = Color(0xFF64748B), style = MaterialTheme.typography.bodySmall)
                            Text(CurrencyFormatter.formatPaise(retailer.creditLimitPaise), fontWeight = FontWeight.Bold)
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Payment Terms:", color = Color(0xFF64748B), style = MaterialTheme.typography.bodySmall)
                            Text("7 Days (Standard)", fontWeight = FontWeight.Bold)
                        }
                        HorizontalDivider(color = Color(0xFFE2E8F0))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Current Balance:", fontWeight = FontWeight.Bold)
                            Text(
                                text = when {
                                    outstanding < 0 -> "Advance: " + CurrencyFormatter.formatPaise(-outstanding)
                                    outstanding > 0 -> "Due: " + CurrencyFormatter.formatPaise(outstanding)
                                    else -> "₹0 (Settled)"
                                },
                                fontWeight = FontWeight.Black,
                                color = when {
                                    outstanding < 0 -> Color(0xFF15803D)
                                    outstanding > 0 -> Color(0xFFDC2626)
                                    else -> Color(0xFF64748B)
                                }
                            )
                        }
                    }
                }

                Text(
                    text = "Recent Transactions Overview",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )

                Surface(
                    color = Color(0xFFF1F5F9),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Text(
                            text = "• Invoices & receipts are synced with central distributor books.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF475569)
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = "• WhatsApp statement PDF is accessible from the web dashboard Reports tab.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF475569)
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = onDismiss,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Close", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    )
}
