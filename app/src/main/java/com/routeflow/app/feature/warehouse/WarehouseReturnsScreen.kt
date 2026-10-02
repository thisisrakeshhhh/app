package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.material.icons.filled.LocalShipping
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
import androidx.compose.ui.platform.testTag
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
import com.routeflow.app.core.network.dto.UndeliveredGoodsDto
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
    var selectedTab by remember { mutableIntStateOf(0) }
    var inspectingReturn by remember { mutableStateOf<ReturnRequestDto?>(null) }
    var acknowledgingGoods by remember { mutableStateOf<UndeliveredGoodsDto?>(null) }

    LaunchedEffect(Unit) {
        viewModel.eventFlow.collect { event ->
            when (event) {
                is ReturnEvent.InspectSuccess -> snackbarHostState.showSnackbar(event.message)
                is ReturnEvent.UndeliveredSuccess -> snackbarHostState.showSnackbar(event.message)
                is ReturnEvent.Error -> snackbarHostState.showSnackbar("Error: ${event.error}")
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.tab_returns),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Black,
                    color = RFColors.TextPrimary
                )
                IconButton(
                    onClick = { viewModel.loadData() },
                    modifier = Modifier.testTag("refresh_returns_button")
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = RFColors.Primary)
                }
            }
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Customer RMA (${uiState.returns.size})", fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal) },
                    modifier = Modifier.testTag("tab_customer_rma")
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Driver Returns (${uiState.undeliveredGoods.size})", fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal) },
                    modifier = Modifier.testTag("tab_driver_returns")
                )
            }

            when {
                uiState.isLoading -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator(color = RFColors.Primary)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Loading requests…")
                    }
                }

                selectedTab == 0 -> {
                    // RMA Tab
                    if (uiState.returns.isEmpty()) {
                        Column(
                            modifier = Modifier.fillMaxSize().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                Icons.Default.AssignmentReturn,
                                contentDescription = null,
                                tint = RFColors.TextSecondary.copy(alpha = 0.4f),
                                modifier = Modifier.padding(24.dp)
                            )
                            Text("No pending return inspections", style = MaterialTheme.typography.titleMedium, color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(uiState.returns) { ret ->
                                ReturnCard(
                                    returnRequest = ret,
                                    isProcessing = uiState.inspectingId == ret.id,
                                    onInspect = { inspectingReturn = ret }
                                )
                            }
                        }
                    }
                }

                selectedTab == 1 -> {
                    // Driver Undelivered Returns Tab
                    if (uiState.undeliveredGoods.isEmpty()) {
                        Column(
                            modifier = Modifier.fillMaxSize().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                Icons.Default.LocalShipping,
                                contentDescription = null,
                                tint = RFColors.TextSecondary.copy(alpha = 0.4f),
                                modifier = Modifier.padding(24.dp)
                            )
                            Text("No driver-held undelivered goods", style = MaterialTheme.typography.titleMedium, color = RFColors.TextSecondary)
                            Text("All undelivered items have been acknowledged or returned.", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(uiState.undeliveredGoods) { item ->
                                UndeliveredGoodCard(
                                    item = item,
                                    isProcessing = uiState.acknowledgingId == item.id,
                                    onAcknowledge = { acknowledgingGoods = item }
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

    inspectingReturn?.let { ret ->
        InspectionDialog(
            returnRequest = ret,
            onDismiss = { inspectingReturn = null },
            onApprove = { items, notes ->
                inspectingReturn = null
                viewModel.inspectReturn(ret.id, "APPROVE", items, notes)
            },
            onReject = { notes ->
                inspectingReturn = null
                viewModel.inspectReturn(ret.id, "REJECT", null, notes)
            }
        )
    }

    acknowledgingGoods?.let { item ->
        AcknowledgeReturnDialog(
            item = item,
            onDismiss = { acknowledgingGoods = null },
            onConfirm = { saleable, damaged, shortage, notes ->
                acknowledgingGoods = null
                viewModel.acknowledgeUndelivered(
                    id = item.id,
                    status = "RETURNED_TO_WAREHOUSE",
                    saleableQuantity = saleable,
                    damagedQuantity = damaged,
                    shortageQuantity = shortage,
                    notes = notes
                )
            }
        )
    }
}

@Composable
private fun UndeliveredGoodCard(
    item: UndeliveredGoodsDto,
    isProcessing: Boolean,
    onAcknowledge: () -> Unit
) {
    val totalQty = item.undeliveredPaidQuantity + item.undeliveredFreeQuantity
    Card(
        modifier = Modifier.fillMaxWidth().testTag("undelivered_card_${item.id}"),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    item.productName ?: item.productId,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    "Held: $totalQty units",
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Error,
                    style = MaterialTheme.typography.titleSmall
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Driver: ${item.driverName ?: item.driverId}", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                Text("•", style = MaterialTheme.typography.bodySmall)
                Text("Reason: ${item.reason}", style = MaterialTheme.typography.bodySmall, color = RFColors.Error)
            }

            Text("Retailer: ${item.retailerName ?: "Unknown"} (${item.retailerAddress ?: ""})", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)

            if (!item.notes.isNullOrBlank()) {
                Text("Notes: ${item.notes}", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
            }

            if (!item.rescheduledFor.isNullOrBlank()) {
                Text("Rescheduled for: ${item.rescheduledFor}", style = MaterialTheme.typography.bodySmall, color = RFColors.Primary)
            }

            Spacer(modifier = Modifier.height(4.dp))

            Button(
                onClick = onAcknowledge,
                enabled = !isProcessing,
                modifier = Modifier.fillMaxWidth().testTag("ack_button_${item.id}"),
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.Primary,
                    contentColor = Color.White
                )
            ) {
                if (isProcessing) {
                    CircularProgressIndicator(modifier = Modifier.width(18.dp).height(18.dp), color = Color.White, strokeWidth = 2.dp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Processing…", color = Color.White)
                } else {
                    Text(stringResource(R.string.acknowledge_return), color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun AcknowledgeReturnDialog(
    item: UndeliveredGoodsDto,
    onDismiss: () -> Unit,
    onConfirm: (saleable: Int, damaged: Int, shortage: Int, notes: String?) -> Unit
) {
    val totalQty = item.undeliveredPaidQuantity + item.undeliveredFreeQuantity
    var saleableStr by remember { mutableStateOf(totalQty.toString()) }
    var damagedStr by remember { mutableStateOf("0") }
    var shortageStr by remember { mutableStateOf("0") }
    var notes by remember { mutableStateOf("") }

    val saleable = saleableStr.toIntOrNull() ?: 0
    val damaged = damagedStr.toIntOrNull() ?: 0
    val shortage = shortageStr.toIntOrNull() ?: 0
    val isValid = (saleable >= 0 && damaged >= 0 && shortage >= 0) && (saleable + damaged + shortage == totalQty)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.acknowledge_return), fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Product: ${item.productName ?: item.productId}", fontWeight = FontWeight.SemiBold)
                Text("Total Undelivered: $totalQty units", style = MaterialTheme.typography.bodyMedium, color = RFColors.Error)
                Text("Disposition must sum to total undelivered units:", style = MaterialTheme.typography.bodySmall)

                OutlinedTextField(
                    value = saleableStr,
                    onValueChange = { saleableStr = it },
                    label = { Text(stringResource(R.string.saleable_restocked)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_saleable_input")
                )

                OutlinedTextField(
                    value = damagedStr,
                    onValueChange = { damagedStr = it },
                    label = { Text(stringResource(R.string.damaged_writeoff)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_damaged_input")
                )

                OutlinedTextField(
                    value = shortageStr,
                    onValueChange = { shortageStr = it },
                    label = { Text(stringResource(R.string.shortage_qty)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_shortage_input")
                )

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text(stringResource(R.string.notes)) },
                    placeholder = { Text("e.g. Verified return from driver") },
                    modifier = Modifier.fillMaxWidth().testTag("ack_notes_input")
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(saleable, damaged, shortage, notes.trim().ifEmpty { null }) },
                enabled = isValid,
                modifier = Modifier.testTag("confirm_ack_button")
            ) {
                Text(stringResource(R.string.confirm))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun ReturnCard(
    returnRequest: ReturnRequestDto,
    isProcessing: Boolean,
    onInspect: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    returnRequest.retailer_name ?: "Retailer ${returnRequest.retailer_id}",
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    returnRequest.status,
                    fontWeight = FontWeight.Bold,
                    color = if (returnRequest.status == "PENDING") RFColors.Error else RFColors.Primary,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            returnRequest.items.forEach { item ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(item.product_name ?: item.product_id, style = MaterialTheme.typography.bodySmall)
                    Text("×${item.requested_quantity}", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                }
            }

            if (returnRequest.status == "PENDING") {
                Button(
                    onClick = onInspect,
                    enabled = !isProcessing,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    )
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(modifier = Modifier.width(18.dp).height(18.dp), color = Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Processing…", color = Color.White)
                    } else {
                        Icon(Icons.Default.AssignmentReturn, contentDescription = null, tint = Color.White)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Inspect Return", color = Color.White, fontWeight = FontWeight.Bold)
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
    val saleableQty = remember { mutableStateMapOf<String, String>() }
    val damagedQty = remember { mutableStateMapOf<String, String>() }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Inspect Return", fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Retailer: ${returnRequest.retailer_name ?: returnRequest.retailer_id}", fontWeight = FontWeight.SemiBold)
                Text("For each item, enter saleable and damaged quantities:", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)

                returnRequest.items.forEach { item ->
                    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFFF5F5F5))) {
                        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("${item.product_name ?: item.product_id}  ×${item.requested_quantity}", fontWeight = FontWeight.SemiBold)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = saleableQty[item.product_id] ?: "0",
                                    onValueChange = { saleableQty[item.product_id] = it },
                                    label = { Text("Saleable") },
                                    modifier = Modifier.weight(1f)
                                )
                                OutlinedTextField(
                                    value = damagedQty[item.product_id] ?: "0",
                                    onValueChange = { damagedQty[item.product_id] = it },
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
                    label = { Text("Notes (optional)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { onReject(notes.trim().ifEmpty { null }) }) {
                    Text("Reject")
                }
                Button(
                    onClick = {
                        val inspectItems = returnRequest.items.map { item ->
                            val s = saleableQty[item.product_id]?.toIntOrNull() ?: 0
                            val d = damagedQty[item.product_id]?.toIntOrNull() ?: 0
                            InspectItemRequest(productId = item.product_id, saleableQuantity = s, damagedQuantity = d)
                        }
                        onApprove(inspectItems, notes.trim().ifEmpty { null })
                    }
                ) {
                    Text("Approve")
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
