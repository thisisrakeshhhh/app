package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
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
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.ReturnItemDto
import com.routeflow.app.core.network.dto.ReturnRequestDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WarehouseReturnsScreen(
    currentLanguage: String = "en",
    onLanguageChange: (String) -> Unit = {},
    onLogout: () -> Unit = {},
    viewModel: WarehouseReturnsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var inspectingReturn by remember { mutableStateOf<ReturnRequestDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is ReturnEvent.InspectSuccess -> snackbarHostState.showSnackbar(event.message)
                is ReturnEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.tab_returns), fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = { viewModel.loadReturns() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        when {
            uiState.isLoading -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator(color = RFColors.Primary)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Loading return requests…")
                }
            }

            uiState.error != null -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text("Failed to load returns:", color = RFColors.Error)
                    Text(uiState.error ?: "", color = RFColors.TextSecondary, style = MaterialTheme.typography.bodySmall)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.loadReturns() }) { Text("Retry") }
                }
            }

            uiState.returns.isEmpty() -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        Icons.Default.AssignmentReturn,
                        contentDescription = null,
                        tint = RFColors.TextSecondary.copy(alpha = 0.4f),
                        modifier = Modifier.padding(24.dp)
                    )
                    Text(
                        "No pending return inspections",
                        style = MaterialTheme.typography.titleMedium,
                        color = RFColors.TextSecondary
                    )
                    Text(
                        "All returns have been inspected or there are no returns today.",
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }
            }

            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.returns, key = { it.id }) { returnReq ->
                        ReturnCard(
                            returnRequest = returnReq,
                            isProcessing = uiState.inspectingId == returnReq.id,
                            onInspect = { inspectingReturn = returnReq }
                        )
                    }
                }
            }
        }
    }

    // Inspection dialog
    inspectingReturn?.let { ret ->
        InspectionDialog(
            returnRequest = ret,
            onDismiss = { inspectingReturn = null },
            onApprove = { itemDecisions, notes ->
                inspectingReturn = null
                viewModel.inspectReturn(
                    returnId = ret.id,
                    action = "APPROVE",
                    items = itemDecisions,
                    notes = notes
                )
            },
            onReject = { notes ->
                inspectingReturn = null
                viewModel.inspectReturn(
                    returnId = ret.id,
                    action = "REJECT",
                    items = null,
                    notes = notes
                )
            }
        )
    }
}

@Composable
private fun ReturnCard(
    returnRequest: ReturnRequestDto,
    isProcessing: Boolean,
    onInspect: () -> Unit
) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        returnRequest.retailer_name ?: "Retailer ${returnRequest.retailer_id.takeLast(6)}",
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleMedium
                    )
                    Text(
                        "Order: ${returnRequest.order_id.takeLast(8)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                    Text(
                        fmt.format(Date(returnRequest.created_at)),
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }
                Text(
                    returnRequest.status,
                    style = MaterialTheme.typography.labelSmall,
                    color = when (returnRequest.status) {
                        "PENDING" -> Color(0xFFF57C00)
                        "APPROVED" -> RFColors.Success
                        "REJECTED" -> RFColors.Error
                        else -> RFColors.TextSecondary
                    }
                )
            }

            returnRequest.items.forEach { item ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        item.product_name ?: item.product_id,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        "×${item.requested_quantity}",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            if (returnRequest.status == "PENDING") {
                Button(
                    onClick = onInspect,
                    enabled = !isProcessing,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(modifier = Modifier.width(18.dp).height(18.dp), color = Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Processing…")
                    } else {
                        Icon(Icons.Default.AssignmentReturn, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Inspect Return")
                    }
                }
            }
        }
    }
}

@Composable
private fun InspectionDialog(
    returnRequest: ReturnRequestDto,
    onDismiss: () -> Unit,
    onApprove: (items: List<InspectItemRequest>, notes: String?) -> Unit,
    onReject: (notes: String?) -> Unit
) {
    // For each item, track saleable + damaged qty
    val saleableQty = remember { mutableStateMapOf<String, String>() }
    val damagedQty = remember { mutableStateMapOf<String, String>() }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Inspect Return",
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "Retailer: ${returnRequest.retailer_name ?: returnRequest.retailer_id}",
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    "For each item, enter saleable and damaged quantities (must sum to requested):",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )

                returnRequest.items.forEach { item ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFF5F5F5))
                    ) {
                        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                "${item.product_name ?: item.product_id}  ×${item.requested_quantity}",
                                fontWeight = FontWeight.SemiBold
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = saleableQty[item.product_id] ?: "0",
                                    onValueChange = { saleableQty[item.product_id] = it },
                                    label = { Text("Saleable") },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = damagedQty[item.product_id] ?: "0",
                                    onValueChange = { damagedQty[item.product_id] = it },
                                    label = { Text("Damaged") },
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Inspection notes (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val items = returnRequest.items.map { item ->
                        InspectItemRequest(
                            productId = item.product_id,
                            saleableQuantity = saleableQty[item.product_id]?.toIntOrNull() ?: 0,
                            damagedQuantity = damagedQty[item.product_id]?.toIntOrNull() ?: 0
                        )
                    }
                    onApprove(items, notes.trim().takeIf { it.isNotBlank() })
                },
                colors = ButtonDefaults.buttonColors(containerColor = RFColors.Success)
            ) {
                Icon(Icons.Default.Check, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text("Approve")
            }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        onReject(notes.trim().takeIf { it.isNotBlank() })
                    },
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Error)
                ) {
                    Icon(Icons.Default.Close, contentDescription = null)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Reject")
                }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        }
    )
}
