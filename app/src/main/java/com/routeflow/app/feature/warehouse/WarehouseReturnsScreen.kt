package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.AssignmentReturn
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto
import com.routeflow.app.core.network.dto.UndeliveredGoodsDto

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

    Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC))) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            text = "Returns & RMA",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Black,
                            color = Color(0xFF0F172A)
                        )
                        Text(text = "•", color = Color(0xFF94A3B8))
                        Text(
                            text = "वापसी निरीक्षण",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                    Text(
                        text = "Customer returns verification & driver undelivered items",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                IconButton(
                    onClick = { viewModel.loadData() },
                    modifier = Modifier.testTag("refresh_returns_button")
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF2563EB))
                }
            }

            // Clean 2 Tabs
            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = Color.White,
                contentColor = Color(0xFF2563EB)
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = {
                        Text(
                            text = "Customer Returns (${uiState.returns.size})",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal
                        )
                    },
                    modifier = Modifier.testTag("tab_customer_rma")
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = {
                        Text(
                            text = "Driver Returns (${uiState.undeliveredGoods.size})",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal
                        )
                    },
                    modifier = Modifier.testTag("tab_driver_returns")
                )
            }

            when {
                uiState.isLoading -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = RFColors.Primary)
                    }
                }

                selectedTab == 0 -> {
                    // Customer RMA Tab
                    if (uiState.returns.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(bottom = 120.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(24.dp)
                            ) {
                                Surface(
                                    color = Color(0xFFEFF6FF),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.size(52.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            Icons.AutoMirrored.Filled.AssignmentReturn,
                                            contentDescription = null,
                                            tint = Color(0xFF2563EB),
                                            modifier = Modifier.size(26.dp)
                                        )
                                    }
                                }
                                Text(
                                    text = "No pending return inspections",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF1E293B)
                                )
                                Text(
                                    text = "Customer return requests (RMA) will appear here for verification",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFF64748B),
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                                OutlinedButton(
                                    onClick = { viewModel.loadData() },
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.height(48.dp)
                                ) {
                                    Text("Refresh Returns", fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                                }
                            }
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)
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
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(bottom = 120.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(24.dp)
                            ) {
                                Surface(
                                    color = Color(0xFFEFF6FF),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.size(52.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            Icons.Default.LocalShipping,
                                            contentDescription = null,
                                            tint = Color(0xFF2563EB),
                                            modifier = Modifier.size(26.dp)
                                        )
                                    }
                                }
                                Text(
                                    text = "No driver-held undelivered goods",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF1E293B)
                                )
                                Text(
                                    text = "All undelivered items have been acknowledged or returned to godown.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFF64748B),
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                                OutlinedButton(
                                    onClick = { viewModel.loadData() },
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.height(48.dp)
                                ) {
                                    Text("Refresh Deliveries", fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                                }
                            }
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)
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
    val readableReason = formatReturnReason(item.reason)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("undelivered_card_${item.id}"),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = item.productName ?: item.productId,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleSmall,
                    color = Color(0xFF0F172A)
                )
                Surface(
                    color = Color(0xFFFEF2F2),
                    shape = RoundedCornerShape(4.dp),
                    border = BorderStroke(1.dp, Color(0xFFFECACA))
                ) {
                    Text(
                        text = "Held: $totalQty units",
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFDC2626),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            // Reason Chip & Driver
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = Color(0xFFEFF6FF),
                    shape = RoundedCornerShape(4.dp)
                ) {
                    Text(
                        text = readableReason,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF2563EB)
                    )
                }
                Text("•", color = Color(0xFF94A3B8))
                Text(
                    text = "Driver: ${item.driverName ?: item.driverId}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF475569)
                )
            }

            Text(
                text = "Retailer: ${item.retailerName ?: "Retail Kirana"} (${item.retailerAddress ?: ""})",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF64748B)
            )

            if (!item.notes.isNullOrBlank()) {
                Text(
                    text = "Notes: ${item.notes}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF64748B)
                )
            }

            if (!item.rescheduledFor.isNullOrBlank()) {
                Text(
                    text = "Rescheduled for: ${item.rescheduledFor}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF2563EB)
                )
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            Button(
                onClick = onAcknowledge,
                enabled = !isProcessing,
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .testTag("ack_button_${item.id}"),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF2563EB),
                    contentColor = Color.White
                )
            ) {
                if (isProcessing) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
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
private fun ReturnCard(
    returnRequest: ReturnRequestDto,
    isProcessing: Boolean,
    onInspect: () -> Unit
) {
    val readableStatus = com.routeflow.app.core.util.StatusMapper.statusLabel(returnRequest.status)

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = returnRequest.retailer_name ?: "Retailer ${returnRequest.retailer_id}",
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleSmall,
                    color = Color(0xFF0F172A)
                )
                Surface(
                    color = if (returnRequest.status.contains("PENDING")) Color(0xFFFEF3C7) else Color(0xFFDCFCE7),
                    shape = RoundedCornerShape(4.dp)
                ) {
                    Text(
                        text = readableStatus,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        fontWeight = FontWeight.Bold,
                        color = if (returnRequest.status.contains("PENDING")) Color(0xFFB45309) else Color(0xFF166534),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                returnRequest.items.forEach { item ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(item.product_name ?: item.product_id, style = MaterialTheme.typography.bodySmall, color = Color(0xFF334155))
                        Text("×${item.requested_quantity} units", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = Color(0xFF0F172A))
                    }
                }
            }

            if (returnRequest.status == "PENDING" || returnRequest.status == "PENDING_INSPECTION") {
                HorizontalDivider(color = Color(0xFFF1F5F9))

                Button(
                    onClick = onInspect,
                    enabled = !isProcessing,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    )
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Processing…", color = Color.White)
                    } else {
                        Icon(Icons.AutoMirrored.Filled.AssignmentReturn, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
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
        title = { Text("Inspect Return", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Retailer: ${returnRequest.retailer_name ?: returnRequest.retailer_id}", fontWeight = FontWeight.SemiBold)
                Text("Enter verified quantities for return disposition:", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))

                returnRequest.items.forEach { item ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                    ) {
                        Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("${item.product_name ?: item.product_id} (Requested: ${item.requested_quantity})", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.bodySmall)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedTextField(
                                    value = saleableQty[item.product_id] ?: "0",
                                    onValueChange = { saleableQty[item.product_id] = it },
                                    label = { Text("Saleable (Restock)") },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(8.dp),
                                    singleLine = true
                                )
                                OutlinedTextField(
                                    value = damagedQty[item.product_id] ?: "0",
                                    onValueChange = { damagedQty[item.product_id] = it },
                                    label = { Text("Damaged (Writeoff)") },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(8.dp),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Inspection Notes") },
                    placeholder = { Text("e.g. Seal intact on tea packs") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val inspectItems = returnRequest.items.map { item ->
                        val saleable = saleableQty[item.product_id]?.toIntOrNull() ?: 0
                        val damaged = damagedQty[item.product_id]?.toIntOrNull() ?: 0
                        InspectItemRequest(
                            productId = item.product_id,
                            saleableQuantity = saleable,
                            damagedQuantity = damaged,
                            saleableFreeQuantity = 0,
                            damagedFreeQuantity = 0
                        )
                    }
                    onApprove(inspectItems, notes.trim().ifEmpty { null })
                },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A)),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Approve Restock", fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                TextButton(
                    onClick = { onReject(notes.trim().ifEmpty { null }) },
                    modifier = Modifier.height(48.dp)
                ) {
                    Text("Reject Return", color = Color(0xFFDC2626), fontWeight = FontWeight.Bold)
                }
                TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                    Text("Cancel", color = Color(0xFF64748B))
                }
            }
        }
    )
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
        title = { Text(stringResource(R.string.acknowledge_return), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Product: ${item.productName ?: item.productId}", fontWeight = FontWeight.SemiBold)
                Text("Total Undelivered: $totalQty units", style = MaterialTheme.typography.bodyMedium, color = Color(0xFFDC2626), fontWeight = FontWeight.Bold)
                Text("Disposition must sum to total undelivered units:", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))

                OutlinedTextField(
                    value = saleableStr,
                    onValueChange = { saleableStr = it },
                    label = { Text(stringResource(R.string.saleable_restocked)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_saleable_input"),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )

                OutlinedTextField(
                    value = damagedStr,
                    onValueChange = { damagedStr = it },
                    label = { Text(stringResource(R.string.damaged_writeoff)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_damaged_input"),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )

                OutlinedTextField(
                    value = shortageStr,
                    onValueChange = { shortageStr = it },
                    label = { Text(stringResource(R.string.shortage_qty)) },
                    modifier = Modifier.fillMaxWidth().testTag("ack_shortage_input"),
                    shape = RoundedCornerShape(8.dp),
                    singleLine = true
                )

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text(stringResource(R.string.notes)) },
                    placeholder = { Text("e.g. Verified return from driver") },
                    modifier = Modifier.fillMaxWidth().testTag("ack_notes_input"),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(saleable, damaged, shortage, notes.trim().ifEmpty { null }) },
                enabled = isValid,
                shape = RoundedCornerShape(8.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                modifier = Modifier.height(48.dp).testTag("confirm_ack_button")
            ) {
                Text(stringResource(R.string.confirm), fontWeight = FontWeight.Bold, color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.height(48.dp)) {
                Text(stringResource(R.string.cancel), color = Color(0xFF64748B))
            }
        }
    )
}

private fun formatReturnReason(rawReason: String?): String {
    return when (rawReason?.uppercase()) {
        "SHOP_CLOSED" -> "Shop Closed"
        "DAMAGED" -> "Damaged"
        "WRONG_ITEM" -> "Wrong Item"
        "PARTIAL_RETURN" -> "Partial Return"
        "CUSTOMER_CANCELLED" -> "Customer Cancelled"
        "REJECTED" -> "Rejected"
        null -> "Return"
        else -> rawReason.replace("_", " ").lowercase().replaceFirstChar { it.uppercase() }
    }
}
