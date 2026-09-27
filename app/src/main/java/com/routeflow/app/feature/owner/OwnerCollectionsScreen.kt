package com.routeflow.app.feature.owner

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.CollectionDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerCollectionsScreen(
    onBack: () -> Unit,
    viewModel: OwnerCollectionsViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var selectedTab by remember { mutableIntStateOf(0) }
    var verifyingCollection by remember { mutableStateOf<CollectionDto?>(null) }
    var rejectingCollection by remember { mutableStateOf<CollectionDto?>(null) }
    var reversingCollection by remember { mutableStateOf<CollectionDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is CollectionActionEvent.Success -> snackbarHostState.showSnackbar(event.message)
                is CollectionActionEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Payment Review & Clearance", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.loadCollections() }) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = {
                        Text(
                            "Verification (${state.pendingReviewCollections.size})",
                            fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = {
                        Text(
                            "Settled (${state.settledCollections.size})",
                            fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = {
                        Text(
                            "Reversed (${state.reversedOrRejectedCollections.size})",
                            fontWeight = if (selectedTab == 2) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
            }

            when {
                state.isLoading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = RFColors.Primary)
                    }
                }

                state.error != null -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text("Failed to load collections: ${state.error}", color = RFColors.Error)
                        Spacer(Modifier.height(12.dp))
                        Button(onClick = { viewModel.loadCollections() }) { Text(stringResource(R.string.retry)) }
                    }
                }

                selectedTab == 0 -> {
                    // Pending verification tab
                    if (state.pendingReviewCollections.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No collections pending verification or clearance.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.pendingReviewCollections, key = { it.id }) { item ->
                                PendingReviewCard(
                                    collection = item,
                                    isProcessing = state.processingId == item.id,
                                    onVerify = { verifyingCollection = item },
                                    onReject = { rejectingCollection = item }
                                )
                            }
                        }
                    }
                }

                selectedTab == 1 -> {
                    // Settled tab
                    if (state.settledCollections.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No settled payments recorded.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.settledCollections, key = { it.id }) { item ->
                                SettledPaymentCard(
                                    collection = item,
                                    isProcessing = state.processingId == item.id,
                                    onReverse = { reversingCollection = item }
                                )
                            }
                        }
                    }
                }

                else -> {
                    // Reversed / Rejected tab
                    if (state.reversedOrRejectedCollections.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No reversed or rejected payments.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.reversedOrRejectedCollections, key = { it.id }) { item ->
                                AuditPaymentCard(collection = item)
                            }
                        }
                    }
                }
            }
        }
    }

    // Verify / Clear Dialog
    verifyingCollection?.let { col ->
        val isCheque = col.payment_method == "CHEQUE"
        val actionVerb = if (isCheque) "CLEAR" else "VERIFY"
        val titleText = if (isCheque) "Clear Cheque Payment" else "Verify UPI / Bank Payment"
        var reason by remember { mutableStateOf(if (isCheque) "Cheque cleared with bank" else "UPI transaction verified against bank statement") }

        AlertDialog(
            onDismissRequest = { verifyingCollection = null },
            title = { Text(titleText) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Retailer: ${col.retailer_name ?: col.retailer_id}", fontWeight = FontWeight.Bold)
                    Text("Amount: ${CurrencyFormatter.formatPaise(col.amount_paise)}")
                    Text("Method: ${col.payment_method}")
                    if (!col.reference.isNullOrBlank()) Text("Reference / Receipt: ${col.reference}")

                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("Verification Notes / Clearance Ref *") },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        verifyingCollection = null
                        viewModel.reviewPayment(col.id, actionVerb, reason)
                    },
                    enabled = reason.isNotBlank()
                ) {
                    Text(if (isCheque) "Clear Cheque" else "Verify Payment")
                }
            },
            dismissButton = {
                TextButton(onClick = { verifyingCollection = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // Reject Dialog
    rejectingCollection?.let { col ->
        var reason by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { rejectingCollection = null },
            title = { Text("Reject Payment") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Reject payment of ${CurrencyFormatter.formatPaise(col.amount_paise)} for ${col.retailer_name ?: col.retailer_id}?")
                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("Rejection Reason *") },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        rejectingCollection = null
                        viewModel.reviewPayment(col.id, "REJECT", reason)
                    },
                    enabled = reason.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Error)
                ) {
                    Text("Confirm Rejection")
                }
            },
            dismissButton = {
                TextButton(onClick = { rejectingCollection = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // Reverse Dialog
    reversingCollection?.let { col ->
        var reason by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { reversingCollection = null },
            title = { Text("Reverse Settled Payment") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Are you sure you want to reverse this payment of ${CurrencyFormatter.formatPaise(col.amount_paise)}?",
                        color = RFColors.Error,
                        fontWeight = FontWeight.Bold
                    )
                    Text("This will increase retailer outstanding by ${CurrencyFormatter.formatPaise(col.amount_paise)}, restore invoice unpaid balance, and record a reversal in the payment ledger.")
                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("Mandatory Audit Reversal Reason *") },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        reversingCollection = null
                        viewModel.reviewPayment(col.id, "REVERSE", reason)
                    },
                    enabled = reason.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Error)
                ) {
                    Text("Confirm Reversal")
                }
            },
            dismissButton = {
                TextButton(onClick = { reversingCollection = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

@Composable
private fun PendingReviewCard(
    collection: CollectionDto,
    isProcessing: Boolean,
    onVerify: () -> Unit,
    onReject: () -> Unit
) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    val isCheque = collection.payment_method == "CHEQUE"
    val verifyLabel = if (isCheque) "Clear Cheque" else "Verify"

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Text(collection.retailer_name ?: collection.retailer_id, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text("Receipt: ${collection.receipt_id}", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
                }
                Text(
                    CurrencyFormatter.formatPaise(collection.amount_paise),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Primary
                )
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Method: ${collection.payment_method}", fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodySmall)
                Text(fmt.format(Date(collection.created_at)), style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            }

            if (!collection.reference.isNullOrBlank()) {
                Text("Ref: ${collection.reference}", style = MaterialTheme.typography.bodySmall)
            }

            if (!collection.notes.isNullOrBlank()) {
                Text("Notes: ${collection.notes}", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = onReject,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Error)
                ) {
                    Icon(Icons.Default.Close, contentDescription = null)
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource(R.string.returns_reject_button))
                }

                Button(
                    onClick = onVerify,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1.5f),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null)
                    Spacer(Modifier.width(4.dp))
                    Text(verifyLabel)
                }
            }
        }
    }
}

@Composable
private fun SettledPaymentCard(
    collection: CollectionDto,
    isProcessing: Boolean,
    onReverse: () -> Unit
) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(collection.retailer_name ?: collection.retailer_id, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(
                    CurrencyFormatter.formatPaise(collection.amount_paise),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Success
                )
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${collection.payment_method} • ${collection.status}", style = MaterialTheme.typography.bodySmall, color = RFColors.Success)
                Text(fmt.format(Date(collection.created_at)), style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            }

            Text("Receipt: ${collection.receipt_id}", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)

            OutlinedButton(
                onClick = onReverse,
                enabled = !isProcessing,
                modifier = Modifier.align(Alignment.End),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Error)
            ) {
                Icon(Icons.Default.Undo, contentDescription = null)
                Spacer(Modifier.width(4.dp))
                Text("Reverse")
            }
        }
    }
}

@Composable
private fun AuditPaymentCard(collection: CollectionDto) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    val isReversed = collection.status == "REVERSED"

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(collection.retailer_name ?: collection.retailer_id, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(
                    collection.status,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = if (isReversed) RFColors.Error else RFColors.TextSecondary
                )
            }
            Text("Amount: ${CurrencyFormatter.formatPaise(collection.amount_paise)} • ${collection.payment_method}", style = MaterialTheme.typography.bodySmall)
            Text("Date: ${fmt.format(Date(collection.created_at))}", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
        }
    }
}
