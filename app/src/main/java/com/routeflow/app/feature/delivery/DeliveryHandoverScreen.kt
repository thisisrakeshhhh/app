package com.routeflow.app.feature.delivery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.CashHandoverDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeliveryHandoverScreen(
    viewModel: DeliveryHandoverViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showSubmitDialog by remember { mutableStateOf(false) }
    var handoverNotes by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is HandoverEvent.Success -> snackbarHostState.showSnackbar(event.message)
                is HandoverEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.tab_cash), fontWeight = FontWeight.Bold) }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        if (uiState.isLoading) {
            Column(
                modifier = Modifier.fillMaxSize().padding(padding),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                CircularProgressIndicator(color = RFColors.Primary)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Loading handover summary…")
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Cash held summary card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Primary),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Text(
                            text = "Cash to Hand Over",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.White.copy(alpha = 0.8f)
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "₹${"%,d".format(uiState.cashHeldPaise / 100)}",
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Collected: ₹${"%,d".format(uiState.totalCollectedPaise / 100)}  |  Settled: ₹${"%,d".format(uiState.totalSettledPaise / 100)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.9f)
                        )
                    }
                }

                // Pending handover banner
                uiState.pendingHandover?.let { pending ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0))
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.HourglassTop, contentDescription = null, tint = Color(0xFFF57C00))
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    "Handover Pending Approval",
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFF57C00)
                                )
                                Text(
                                    "₹${"%,d".format(pending.amount_paise / 100)} submitted — awaiting owner acknowledgement",
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }
                    }
                }

                // Error display
                uiState.error?.let { err ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE))
                    ) {
                        Text(
                            "Could not load summary: $err",
                            modifier = Modifier.padding(16.dp),
                            color = RFColors.Error
                        )
                    }
                }

                // Submit handover button
                Button(
                    onClick = { showSubmitDialog = true },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !uiState.isSubmitting && uiState.pendingHandover == null && uiState.cashHeldPaise > 0,
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    if (uiState.isSubmitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.width(20.dp).height(20.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Submitting…")
                    } else {
                        Icon(Icons.Default.AccountBalanceWallet, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Submit Handover for Reconciliation", fontWeight = FontWeight.Bold)
                    }
                }

                // Recent handovers history
                if (uiState.recentHandovers.isNotEmpty()) {
                    Text(
                        "Recent Handovers",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    uiState.recentHandovers.forEach { h ->
                        HandoverHistoryCard(h)
                    }
                }
            }
        }
    }

    // Submit dialog
    if (showSubmitDialog) {
        val cashHeld = uiState.cashHeldPaise
        AlertDialog(
            onDismissRequest = { showSubmitDialog = false },
            title = { Text("Submit Cash Handover", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "Cash to hand over: ₹${"%,d".format(cashHeld / 100)}",
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.Primary
                    )
                    Text(
                        "This will create a handover record. The owner must acknowledge the physical cash before it is marked settled.",
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                    OutlinedTextField(
                        value = handoverNotes,
                        onValueChange = { handoverNotes = it },
                        label = { Text("Notes (optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 3
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showSubmitDialog = false
                        viewModel.submitHandover(cashHeld, handoverNotes.trim().takeIf { it.isNotBlank() })
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Text("Submit ₹${"%,d".format(cashHeld / 100)}")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSubmitDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun HandoverHistoryCard(handover: CashHandoverDto) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    val statusColor = when (handover.status) {
        "ACCEPTED" -> RFColors.Success
        "REJECTED" -> RFColors.Error
        "PENDING" -> Color(0xFFF57C00)
        else -> RFColors.TextSecondary
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("₹${"%,d".format(handover.amount_paise / 100)}", fontWeight = FontWeight.Bold)
                Text(handover.status, color = statusColor, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelMedium)
            }
            Text(
                fmt.format(Date(handover.submitted_at)),
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )
            handover.discrepancy_paise?.takeIf { it != 0L }?.let { disc ->
                val sign = if (disc > 0) "+" else ""
                Text(
                    "Discrepancy: $sign₹${"%,d".format(disc / 100)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (disc != 0L) RFColors.Error else RFColors.Success
                )
            }
        }
    }
}
