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
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
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
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerReturnsScreen(
    onBack: () -> Unit,
    viewModel: OwnerReturnsViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var selectedTab by remember { mutableIntStateOf(0) }
    var authorizingReturn by remember { mutableStateOf<Pair<ReturnRequestDto, String>?>(null) } // pair of return to action ("APPROVE" or "REJECT")
    var inspectingReturn by remember { mutableStateOf<ReturnRequestDto?>(null) }
    var creditingReturn by remember { mutableStateOf<ReturnRequestDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is OwnerReturnEvent.Success -> snackbarHostState.showSnackbar(event.message)
                is OwnerReturnEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Returns & Credit Notes", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.loadReturns() }) {
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
                            "Authorize (${state.pendingAuthorization.size})",
                            fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = {
                        val count = state.pendingReceiving.size + state.pendingInspection.size
                        Text(
                            "Receive/Inspect ($count)",
                            fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = {
                        val count = state.pendingCredit.size + state.creditedOrApproved.size
                        Text(
                            "Credit Notes ($count)",
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
                        Text("Failed to load returns: ${state.error}", color = RFColors.Error)
                        Spacer(Modifier.height(12.dp))
                        Button(onClick = { viewModel.loadReturns() }) { Text(stringResource(R.string.retry)) }
                    }
                }

                selectedTab == 0 -> {
                    // Authorize Tab
                    if (state.pendingAuthorization.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No returns pending authorization.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.pendingAuthorization, key = { it.id }) { item ->
                                AuthorizeReturnCard(
                                    returnReq = item,
                                    isProcessing = state.processingId == item.id,
                                    onApprove = { authorizingReturn = item to "APPROVE" },
                                    onReject = { authorizingReturn = item to "REJECT" }
                                )
                            }
                        }
                    }
                }

                selectedTab == 1 -> {
                    // Receive & Inspect Tab
                    val inProgressReturns = state.pendingReceiving + state.pendingInspection
                    if (inProgressReturns.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No returns pending receipt or inspection.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(inProgressReturns, key = { it.id }) { item ->
                                ReceiveOrInspectCard(
                                    returnReq = item,
                                    isProcessing = state.processingId == item.id,
                                    onReceive = { viewModel.receiveReturn(item.id, "Received at warehouse") },
                                    onInspect = { inspectingReturn = item }
                                )
                            }
                        }
                    }
                }

                else -> {
                    // Credit Notes Tab
                    val creditReturns = state.pendingCredit + state.creditedOrApproved
                    if (creditReturns.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text("No credit notes pending approval.", color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(creditReturns, key = { it.id }) { item ->
                                CreditReturnCard(
                                    returnReq = item,
                                    isProcessing = state.processingId == item.id,
                                    onApproveCredit = { creditingReturn = item }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Authorize Dialog
    authorizingReturn?.let { (ret, action) ->
        val isApprove = action == "APPROVE"
        var notes by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { authorizingReturn = null },
            title = { Text(if (isApprove) "Authorize Return Request" else "Reject Return Request") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Retailer: ${ret.retailer_name ?: ret.retailer_id}", fontWeight = FontWeight.Bold)
                    Text("Order: ${ret.order_id}")
                    if (!ret.notes.isNullOrBlank()) Text("Requested reason: ${ret.notes}")
                    OutlinedTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        label = { Text("Authorization Notes / Reason *") },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        authorizingReturn = null
                        viewModel.authorizeReturn(ret.id, action, notes)
                    },
                    enabled = notes.isNotBlank(),
                    colors = if (isApprove) ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                    else ButtonDefaults.buttonColors(containerColor = RFColors.Error)
                ) {
                    Text(if (isApprove) "Confirm Approval" else "Confirm Rejection")
                }
            },
            dismissButton = {
                TextButton(onClick = { authorizingReturn = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }

    // Inspection Dialog
    inspectingReturn?.let { ret ->
        InspectionDialog(
            returnRequest = ret,
            onDismiss = { inspectingReturn = null },
            onConfirm = { items, notes ->
                inspectingReturn = null
                viewModel.inspectReturn(ret.id, "APPROVE", items, notes)
            }
        )
    }

    // Credit Note Approval Dialog
    creditingReturn?.let { ret ->
        var notes by remember { mutableStateOf("Credit note approved following inspection") }
        AlertDialog(
            onDismissRequest = { creditingReturn = null },
            title = { Text("Approve Credit Note") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Retailer: ${ret.retailer_name ?: ret.retailer_id}", fontWeight = FontWeight.Bold)
                    Text("Credit Amount: ${CurrencyFormatter.formatPaise(ret.credit_paise ?: 0L)}", color = RFColors.Success, fontWeight = FontWeight.Bold)
                    Text("This will deduct ${CurrencyFormatter.formatPaise(ret.credit_paise ?: 0L)} from retailer outstanding and record a credit note on the original invoice.")
                    OutlinedTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        label = { Text("Credit Approval Notes *") },
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        creditingReturn = null
                        viewModel.creditReturn(ret.id, notes)
                    },
                    enabled = notes.isNotBlank()
                ) {
                    Text("Issue Credit Note")
                }
            },
            dismissButton = {
                TextButton(onClick = { creditingReturn = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

@Composable
private fun AuthorizeReturnCard(
    returnReq: ReturnRequestDto,
    isProcessing: Boolean,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    val fmt = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault())
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(returnReq.retailer_name ?: returnReq.retailer_id, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text("STATUS: ${returnReq.status}", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = RFColors.Warning)
            }
            Text("Order ID: ${returnReq.order_id}", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            Text("Requested: ${fmt.format(Date(returnReq.created_at))}", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            if (!returnReq.notes.isNullOrBlank()) {
                Text("Reason: ${returnReq.notes}", style = MaterialTheme.typography.bodySmall)
            }

            Text("Items to return: ${returnReq.items.size}", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)

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
                    onClick = onApprove,
                    enabled = !isProcessing,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Icon(Icons.Default.Check, contentDescription = null)
                    Spacer(Modifier.width(4.dp))
                    Text("Authorize")
                }
            }
        }
    }
}

@Composable
private fun ReceiveOrInspectCard(
    returnReq: ReturnRequestDto,
    isProcessing: Boolean,
    onReceive: () -> Unit,
    onInspect: () -> Unit
) {
    val isAuthorized = returnReq.status == "AUTHORIZED"
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(returnReq.retailer_name ?: returnReq.retailer_id, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(returnReq.status, style = MaterialTheme.typography.labelSmall, color = RFColors.Primary, fontWeight = FontWeight.Bold)
            }
            Text("Order: ${returnReq.order_id}", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)

            if (isAuthorized) {
                Button(
                    onClick = onReceive,
                    enabled = !isProcessing,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Mark Received at Warehouse")
                }
            } else {
                Button(
                    onClick = onInspect,
                    enabled = !isProcessing,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Inspect Items (Saleable / Damaged)")
                }
            }
        }
    }
}

@Composable
private fun CreditReturnCard(
    returnReq: ReturnRequestDto,
    isProcessing: Boolean,
    onApproveCredit: () -> Unit
) {
    val isCredited = returnReq.status == "CREDITED" || returnReq.status == "APPROVED"
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(returnReq.retailer_name ?: returnReq.retailer_id, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(returnReq.status, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = if (isCredited) RFColors.Success else RFColors.Primary)
            }
            Text("Credit Note: ${CurrencyFormatter.formatPaise(returnReq.credit_paise ?: 0L)}", fontWeight = FontWeight.Bold, color = RFColors.Success)

            if (!isCredited) {
                Button(
                    onClick = onApproveCredit,
                    enabled = !isProcessing,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text("Approve & Issue Credit Note")
                }
            }
        }
    }
}

@Composable
private fun InspectionDialog(
    returnRequest: ReturnRequestDto,
    onDismiss: () -> Unit,
    onConfirm: (List<InspectItemRequest>, String) -> Unit
) {
    val saleableMap = remember {
        mutableStateMapOf<String, Int>().apply {
            returnRequest.items.forEach { put(it.id, it.requested_quantity) }
        }
    }
    val damagedMap = remember {
        mutableStateMapOf<String, Int>().apply {
            returnRequest.items.forEach { put(it.id, 0) }
        }
    }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Inspect Return Items") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                returnRequest.items.forEach { item ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                    ) {
                        Column(Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(item.product_name ?: item.product_id, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
                            Text("Requested: ${item.requested_quantity}", style = MaterialTheme.typography.labelSmall)

                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = (saleableMap[item.id] ?: 0).toString(),
                                    onValueChange = { saleableMap[item.id] = it.toIntOrNull() ?: 0 },
                                    label = { Text("Saleable") },
                                    modifier = Modifier.weight(1f)
                                )
                                OutlinedTextField(
                                    value = (damagedMap[item.id] ?: 0).toString(),
                                    onValueChange = { damagedMap[item.id] = it.toIntOrNull() ?: 0 },
                                    label = { Text("Damaged") },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Inspection Notes") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val requests = returnRequest.items.map { item ->
                        InspectItemRequest(
                            productId = item.product_id,
                            saleableQuantity = saleableMap[item.id] ?: 0,
                            damagedQuantity = damagedMap[item.id] ?: 0
                        )
                    }
                    onConfirm(requests, notes)
                }
            ) {
                Text("Complete Inspection")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}
