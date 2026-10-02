package com.routeflow.app.feature.owner

import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.CashHandoverDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerHandoversScreen(
    onBack: () -> Unit,
    viewModel: OwnerHandoversViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var selectedTab by remember { mutableIntStateOf(0) }
    var acceptingHandover by remember { mutableStateOf<CashHandoverDto?>(null) }
    var rejectingHandover by remember { mutableStateOf<CashHandoverDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is HandoverActionEvent.Success -> snackbarHostState.showSnackbar(event.message)
                is HandoverActionEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                    Text(stringResource(R.string.handover_title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
                IconButton(onClick = { viewModel.loadHandovers() }) {
                    Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                }
            }

            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = {
                        Text(
                            "Pending (${state.pendingHandovers.size})",
                            fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = {
                        Text(
                            "History (${state.completedHandovers.size})",
                            fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal
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
                        Text("Failed to load handovers: ${state.error}", color = RFColors.Error)
                        Spacer(Modifier.height(12.dp))
                        Button(onClick = { viewModel.loadHandovers() }) { Text(stringResource(R.string.retry)) }
                    }
                }

                selectedTab == 0 -> {
                    // Pending tab
                    if (state.pendingHandovers.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text(
                                "No pending cash handovers awaiting acknowledgement.",
                                color = RFColors.TextSecondary,
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            item {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = CardDefaults.cardColors(containerColor = RFColors.Primary.copy(alpha = 0.08f))
                                ) {
                                    Row(
                                        modifier = Modifier.padding(16.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column {
                                            Text("Total Cash Awaiting Acceptance", style = MaterialTheme.typography.labelMedium, color = RFColors.TextSecondary)
                                            Text(
                                                CurrencyFormatter.formatPaise(state.pendingTotalPaise),
                                                style = MaterialTheme.typography.headlineSmall,
                                                fontWeight = FontWeight.Bold,
                                                color = RFColors.Primary
                                            )
                                        }
                                        Icon(Icons.Default.AccountBalanceWallet, contentDescription = null, tint = RFColors.Primary)
                                    }
                                }
                            }

                            items(state.pendingHandovers, key = { it.id }) { item ->
                                PendingHandoverCard(
                                    handover = item,
                                    isProcessing = state.processingId == item.id,
                                    onAccept = { acceptingHandover = item },
                                    onReject = { rejectingHandover = item }
                                )
                            }
                        }
                    }
                }

                else -> {
                    // History tab
                    if (state.completedHandovers.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No past handover records found.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.completedHandovers, key = { it.id }) { item ->
                                CompletedHandoverCard(handover = item)
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

    // Accept Dialog with discrepancy calculation
    acceptingHandover?.let { item ->
        AcceptHandoverDialog(
            handover = item,
            onDismiss = { acceptingHandover = null },
            onConfirm = { receivedPaise, notes ->
                acceptingHandover = null
                viewModel.acknowledgeHandover(
                    id = item.id,
                    action = "ACCEPT",
                    receivedPaise = receivedPaise,
                    notes = notes
                )
            }
        )
    }

    // Reject Dialog
    rejectingHandover?.let { item ->
        RejectHandoverDialog(
            handover = item,
            onDismiss = { rejectingHandover = null },
            onConfirm = { reason ->
                rejectingHandover = null
                viewModel.acknowledgeHandover(
                    id = item.id,
                    action = "REJECT",
                    receivedPaise = null,
                    notes = reason
                )
            }
        )
    }
}

@Composable
private fun PendingHandoverCard(
    handover: CashHandoverDto,
    isProcessing: Boolean,
    onAccept: () -> Unit,
    onReject: () -> Unit
) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Text(
                        handover.employee_name ?: handover.user_id,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        handover.employee_role ?: "FIELD_STAFF",
                        style = MaterialTheme.typography.labelSmall,
                        color = RFColors.TextSecondary
                    )
                }
                Text(
                    CurrencyFormatter.formatPaise(handover.amount_paise),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Primary
                )
            }

            Text(
                "Submitted: ${fmt.format(Date(handover.submitted_at))}",
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            if (!handover.notes.isNullOrBlank()) {
                Text(
                    "Notes: ${handover.notes}",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextPrimary
                )
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
                    onClick = onAccept,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1.5f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    )
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.width(4.dp))
                    Text("Accept Cash", color = Color.White)
                }
            }
        }
    }
}

@Composable
private fun CompletedHandoverCard(handover: CashHandoverDto) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    val isAccepted = handover.status == "ACCEPTED"
    val statusColor = if (isAccepted) RFColors.Success else RFColors.Error

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(
                    handover.employee_name ?: handover.user_id,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    handover.status,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = statusColor
                )
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Declared: ${CurrencyFormatter.formatPaise(handover.amount_paise)}", style = MaterialTheme.typography.bodySmall)
                if (handover.received_amount_paise != null) {
                    Text(
                        "Received: ${CurrencyFormatter.formatPaise(handover.received_amount_paise)}",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            if (handover.discrepancy_paise != null && handover.discrepancy_paise != 0L) {
                Text(
                    "Discrepancy: ${CurrencyFormatter.formatPaise(handover.discrepancy_paise)}",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Error
                )
            }

            if (!handover.resolution_notes.isNullOrBlank()) {
                Text(
                    "Resolution: ${handover.resolution_notes}",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }

            handover.acknowledged_at?.let { ackTime ->
                Text(
                    "Acknowledged: ${fmt.format(Date(ackTime))}",
                    style = MaterialTheme.typography.labelSmall,
                    color = RFColors.TextSecondary
                )
            }
        }
    }
}

@Composable
private fun AcceptHandoverDialog(
    handover: CashHandoverDto,
    onDismiss: () -> Unit,
    onConfirm: (receivedPaise: Long, notes: String) -> Unit
) {
    val declaredRupees = handover.amount_paise / 100
    var receivedInput by remember { mutableStateOf(declaredRupees.toString()) }
    var notes by remember { mutableStateOf("") }
    val receivedRupees = receivedInput.toLongOrNull() ?: 0L
    val discrepancy = receivedRupees - declaredRupees
    val hasDiscrepancy = discrepancy != 0L

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Accept Cash Handover") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("From: ${handover.employee_name ?: handover.user_id}")
                Text("Declared Amount: ₹$declaredRupees", fontWeight = FontWeight.Bold)

                OutlinedTextField(
                    value = receivedInput,
                    onValueChange = { receivedInput = it.filter { ch -> ch.isDigit() } },
                    label = { Text("Physically Received Amount (₹)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                if (hasDiscrepancy) {
                    val alertText = if (discrepancy < 0) {
                        "Shortage: ₹${-discrepancy} less than declared!"
                    } else {
                        "Excess: ₹$discrepancy more than declared!"
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Warning, contentDescription = null, tint = RFColors.Error)
                        Spacer(Modifier.width(6.dp))
                        Text(alertText, color = RFColors.Error, fontWeight = FontWeight.Bold)
                    }
                }

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text(if (hasDiscrepancy) "Discrepancy Reason *" else "Resolution Notes (Optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(receivedRupees * 100, notes) },
                enabled = receivedRupees in 0..declaredRupees && (!hasDiscrepancy || notes.isNotBlank()),
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.Primary,
                    contentColor = Color.White
                )
            ) {
                Text("Confirm Acceptance", color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}

@Composable
private fun RejectHandoverDialog(
    handover: CashHandoverDto,
    onDismiss: () -> Unit,
    onConfirm: (reason: String) -> Unit
) {
    var reason by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Reject Cash Handover") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Reject handover of ${CurrencyFormatter.formatPaise(handover.amount_paise)} from ${handover.employee_name ?: handover.user_id}?")
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
                onClick = { onConfirm(reason) },
                enabled = reason.isNotBlank(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.Error,
                    contentColor = Color.White
                )
            ) {
                Text("Confirm Rejection", color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}
