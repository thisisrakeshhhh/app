package com.routeflow.app.feature.vansales

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors

/**
 * Van-Sales Mobile Screen for RouteFlow.
 * Provides vehicle-stock selection, spot billing, provisional orders,
 * credit status warnings, and stable offline outbox submission.
 *
 * Marked: Source corrected — not runtime-verified.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VanSalesScreen(
    state: VanSalesUiState,
    onBack: () -> Unit,
    onSearchChange: (String) -> Unit,
    onCategorySelect: (String?) -> Unit,
    onRetailerSelect: (String) -> Unit,
    onQuantityChange: (String, Int) -> Unit,
    onPaymentMethodChange: (String) -> Unit,
    onProvisionalToggle: (Boolean) -> Unit,
    onNotesChange: (String) -> Unit,
    onCreditOverrideReasonChange: (String) -> Unit,
    onRefreshTrip: () -> Unit,
    onSubmit: () -> Unit,
    onDismissResult: () -> Unit,
    onNewSale: () -> Unit
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Van Spot Sales",
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = if (state.isProvisional) "Provisional Order Booking" else "Direct Spot Billing & Stock Deduction",
                            style = MaterialTheme.typography.bodySmall,
                            color = if (state.isProvisional) Color(0xFFD97706) else Color(0xFF15803D),
                            fontSize = 11.sp
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White)
            )
        },
        bottomBar = {
            CartBottomPanel(
                state = state,
                onSubmit = onSubmit
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(Color(0xFFF8FAFC)),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // 1. Role Permission Guard
            if (!state.hasRolePermission) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                        border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = Color(0xFFDC2626))
                            Spacer(Modifier.width(10.dp))
                            Text(
                                text = "Permission Denied: Your current role (${state.activeEmployee?.role?.label ?: "Unknown"}) does not have permissions to execute van sales. Contact administrator.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color(0xFFB91C1C),
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }

            // 2. Active Trip / Vehicle Context
            item {
                TripContextCard(
                    isTripMissing = state.isTripMissing,
                    activeTrip = state.activeTrip,
                    onRefresh = onRefreshTrip
                )
            }

            // 3. Retailer Selection & Credit Exposure Card
            item {
                RetailerSelectionCard(
                    retailers = state.assignedRetailers,
                    selectedRetailer = state.selectedRetailer,
                    onRetailerSelect = onRetailerSelect,
                    cartTotalPaise = state.cartTotalEstimatePaise,
                    paymentMethod = state.paymentMethod,
                    isCreditLimitExceeded = state.isCreditLimitExceeded,
                    isCreditNearLimit = state.isCreditNearLimit
                )
            }

            // 4. Billing Options Card (Spot Bill vs Provisional + Payment Method)
            item {
                BillingOptionsCard(
                    paymentMethod = state.paymentMethod,
                    onPaymentMethodChange = onPaymentMethodChange,
                    isProvisional = state.isProvisional,
                    onProvisionalToggle = onProvisionalToggle,
                    notes = state.notes,
                    onNotesChange = onNotesChange,
                    showCreditOverride = state.isCreditLimitExceeded && state.paymentMethod == "CREDIT",
                    creditOverrideReason = state.creditOverrideReason,
                    onCreditOverrideReasonChange = onCreditOverrideReasonChange
                )
            }

            // 5. Vehicle Stock Catalog Header & Filters
            item {
                CatalogHeaderAndFilters(
                    searchQuery = state.searchQuery,
                    onSearchChange = onSearchChange,
                    categories = state.categories,
                    selectedCategory = state.selectedCategory,
                    onCategorySelect = onCategorySelect
                )
            }

            // 6. Vehicle Stock Items List
            if (state.products.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.Inventory2,
                                contentDescription = null,
                                tint = Color(0xFF94A3B8),
                                modifier = Modifier.size(40.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "No matching vehicle stock items found",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color(0xFF64748B)
                            )
                        }
                    }
                }
            } else {
                items(state.products, key = { it.product.id }) { item ->
                    VehicleStockProductCard(
                        item = item,
                        isTripMissing = state.isTripMissing,
                        onQuantityChange = { delta -> onQuantityChange(item.product.id, delta) }
                    )
                }
            }

            // Bottom Spacing for fixed Cart panel
            item {
                Spacer(Modifier.height(20.dp))
            }
        }
    }

    // 7. Submission Result Dialog / Success Confirmation
    if (state.submissionOrderId != null) {
        AlertDialog(
            onDismissRequest = onDismissResult,
            icon = {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF16A34A),
                    modifier = Modifier.size(48.dp)
                )
            },
            title = {
                Text(
                    text = if (state.submissionStatus == "DELIVERED") "Van Sale Delivered!" else "Van Sale Queued",
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Order ID: ${state.submissionOrderId}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF2563EB)
                    )
                    Text(
                        text = state.submissionMessage ?: "Order successfully recorded.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF475569),
                        textAlign = TextAlign.Center
                    )
                    Surface(
                        color = when (state.submissionStatus) {
                            "DELIVERED" -> Color(0xFFDCFCE7)
                            "SAVED_OFFLINE" -> Color(0xFFFEF3C7)
                            else -> Color(0xFFEFF6FF)
                        },
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "Status: ${state.submissionStatus ?: "ACCEPTED"}",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = when (state.submissionStatus) {
                                "DELIVERED" -> Color(0xFF15803D)
                                "SAVED_OFFLINE" -> Color(0xFF92400E)
                                else -> Color(0xFF1D4ED8)
                            },
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                        )
                    }
                    Text(
                        text = "Server Authoritative: Inventory allocations and ledger transactions have been recorded with unique idempotency protection.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B),
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        onDismissResult()
                        onNewSale()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("New Van Sale", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    onDismissResult()
                    onBack()
                }) {
                    Text("Return to Route", color = Color(0xFF64748B))
                }
            }
        )
    }

    // 8. Submission Error Alert
    if (state.errorMessage != null && state.submissionOrderId == null) {
        AlertDialog(
            onDismissRequest = onDismissResult,
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color(0xFFDC2626),
                    modifier = Modifier.size(40.dp)
                )
            },
            title = {
                Text("Van Sale Submission Error", fontWeight = FontWeight.Bold)
            },
            text = {
                Text(
                    text = state.errorMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color(0xFF334155)
                )
            },
            confirmButton = {
                Button(
                    onClick = onDismissResult,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Dismiss", fontWeight = FontWeight.Bold)
                }
            }
        )
    }
}

/**
 * Trip Context Banner: Verifies vehicle trip is active or alerts user that van sales are blocked.
 */
@Composable
private fun TripContextCard(
    isTripMissing: Boolean,
    activeTrip: com.routeflow.app.core.network.dto.TripDetailDto?,
    onRefresh: () -> Unit
) {
    if (isTripMissing) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
            border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
            shape = RoundedCornerShape(14.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = Color(0xFFDC2626),
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "Active Vehicle Trip Required",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF991B1B)
                        )
                    }
                    IconButton(onClick = onRefresh, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF991B1B))
                    }
                }
                Text(
                    text = "Van spot sales deduct physical inventory from vehicle allocations. You do not currently have an active trip in IN_TRANSIT or PLANNED state. Sales submission is disabled until a trip is started.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFB91C1C)
                )
            }
        }
    } else if (activeTrip != null) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)),
            border = BorderStroke(1.dp, Color(0xFFBBF7D0)),
            shape = RoundedCornerShape(14.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFDCFCE7)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocalShipping,
                            contentDescription = null,
                            tint = Color(0xFF16A34A),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Trip ${activeTrip.tripNumber}",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF14532D)
                            )
                            Spacer(Modifier.width(6.dp))
                            Surface(
                                color = Color(0xFFDCFCE7),
                                shape = RoundedCornerShape(4.dp)
                            ) {
                                Text(
                                    text = activeTrip.status,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF15803D),
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = "Vehicle: ${activeTrip.vehicleNumber ?: "Van Stock"} • Area: ${activeTrip.routeArea ?: "Default Route"}",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF166534)
                        )
                    }
                }
                IconButton(onClick = onRefresh, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = Color(0xFF16A34A))
                }
            }
        }
    }
}

/**
 * Retailer Selection & Real-Time Credit Health Card.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RetailerSelectionCard(
    retailers: List<com.routeflow.app.domain.model.Retailer>,
    selectedRetailer: com.routeflow.app.domain.model.Retailer?,
    onRetailerSelect: (String) -> Unit,
    cartTotalPaise: Long,
    paymentMethod: String,
    isCreditLimitExceeded: Boolean,
    isCreditNearLimit: Boolean
) {
    var expanded by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = "Target Retailer & Credit Status",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF64748B)
            )

            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = !expanded }
            ) {
                OutlinedTextField(
                    value = selectedRetailer?.name ?: "Select Retailer Shop",
                    onValueChange = {},
                    readOnly = true,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    leadingIcon = { Icon(Icons.Default.Store, contentDescription = null, tint = Color(0xFF2563EB)) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    shape = RoundedCornerShape(10.dp)
                )
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    retailers.forEach { retailer ->
                        DropdownMenuItem(
                            text = {
                                Column {
                                    Text(retailer.name, fontWeight = FontWeight.Bold)
                                    Text(
                                        text = retailer.address,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFF64748B)
                                    )
                                }
                            },
                            onClick = {
                                onRetailerSelect(retailer.id)
                                expanded = false
                            }
                        )
                    }
                }
            }

            if (selectedRetailer != null) {
                val outstanding = selectedRetailer.outstandingAmountPaise
                val limit = selectedRetailer.creditLimitPaise
                val remaining = (limit - outstanding).coerceAtLeast(0)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Balance status
                    Surface(
                        modifier = Modifier.weight(1f),
                        color = when {
                            outstanding > 0 -> Color(0xFFFEF2F2)
                            outstanding < 0 -> Color(0xFFF0FDF4)
                            else -> Color(0xFFF1F5F9)
                        },
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Column(Modifier.padding(8.dp)) {
                            Text(
                                text = when {
                                    outstanding > 0 -> "Pending Udhaar"
                                    outstanding < 0 -> "Advance Balance"
                                    else -> "Balance"
                                },
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF64748B)
                            )
                            Text(
                                text = CurrencyFormatter.formatPaise(if (outstanding < 0) -outstanding else outstanding),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = when {
                                    outstanding > 0 -> Color(0xFFDC2626)
                                    outstanding < 0 -> Color(0xFF16A34A)
                                    else -> Color(0xFF475569)
                                }
                            )
                        }
                    }

                    // Credit Limit
                    Surface(
                        modifier = Modifier.weight(1f),
                        color = Color(0xFFEFF6FF),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Column(Modifier.padding(8.dp)) {
                            Text("Credit Limit", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                            Text(
                                text = CurrencyFormatter.formatPaise(limit),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF1D4ED8)
                            )
                        }
                    }

                    // Available
                    Surface(
                        modifier = Modifier.weight(1f),
                        color = Color(0xFFF8FAFC),
                        shape = RoundedCornerShape(8.dp),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                    ) {
                        Column(Modifier.padding(8.dp)) {
                            Text("Available", style = MaterialTheme.typography.labelSmall, color = Color(0xFF64748B))
                            Text(
                                text = CurrencyFormatter.formatPaise(remaining),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF334155)
                            )
                        }
                    }
                }

                // Credit warnings
                if (isCreditLimitExceeded) {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color(0xFFFEF2F2),
                        border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFDC2626), modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = "Credit Limit Exceeded: Estimated total exceeds retailer's credit limit. Server rules require spot Cash/UPI payment or authorized credit override.",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF991B1B)
                            )
                        }
                    }
                } else if (isCreditNearLimit) {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color(0xFFFFFBEB),
                        border = BorderStroke(1.dp, Color(0xFFFDE68A)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = Color(0xFFD97706), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = "Notice: Retailer is near their credit threshold. Collect payment if feasible.",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF92400E)
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * Billing Options: Payment method chips, spot bill vs provisional order toggle, and notes.
 */
@Composable
private fun BillingOptionsCard(
    paymentMethod: String,
    onPaymentMethodChange: (String) -> Unit,
    isProvisional: Boolean,
    onProvisionalToggle: (Boolean) -> Unit,
    notes: String,
    onNotesChange: (String) -> Unit,
    showCreditOverride: Boolean,
    creditOverrideReason: String,
    onCreditOverrideReasonChange: (String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Billing & Payment Mode",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF64748B)
                )

                // Provisional Toggle
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (isProvisional) "Provisional Quote" else "Spot Billing",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (isProvisional) Color(0xFFD97706) else Color(0xFF16A34A)
                    )
                    Spacer(Modifier.width(6.dp))
                    Switch(
                        checked = !isProvisional,
                        onCheckedChange = { onProvisionalToggle(!it) },
                        modifier = Modifier.height(28.dp)
                    )
                }
            }

            // Payment method selector
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf("CASH" to "Spot Cash", "UPI" to "UPI / Online", "CREDIT" to "Credit (Udhaar)").forEach { (key, label) ->
                    val isSelected = paymentMethod == key
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .clickable { onPaymentMethodChange(key) },
                        color = if (isSelected) Color(0xFF2563EB) else Color(0xFFF1F5F9),
                        shape = RoundedCornerShape(10.dp),
                        border = if (isSelected) null else BorderStroke(1.dp, Color(0xFFE2E8F0))
                    ) {
                        Box(
                            modifier = Modifier.padding(vertical = 10.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = label,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isSelected) Color.White else Color(0xFF334155)
                            )
                        }
                    }
                }
            }

            OutlinedTextField(
                value = notes,
                onValueChange = onNotesChange,
                label = { Text("Order Notes (optional)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(10.dp)
            )

            if (showCreditOverride) {
                OutlinedTextField(
                    value = creditOverrideReason,
                    onValueChange = onCreditOverrideReasonChange,
                    label = { Text("Credit Override Reason (Required)") },
                    placeholder = { Text("e.g. Authorized by Owner via Phone") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFFDC2626),
                        unfocusedBorderColor = Color(0xFFFCA5A5)
                    )
                )
            }
        }
    }
}

/**
 * Filter header with search input and category chips.
 */
@Composable
private fun CatalogHeaderAndFilters(
    searchQuery: String,
    onSearchChange: (String) -> Unit,
    categories: List<String>,
    selectedCategory: String?,
    onCategorySelect: (String?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchChange,
            placeholder = { Text("Search vehicle products, SKU, or barcode…") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF64748B)) },
            trailingIcon = if (searchQuery.isNotEmpty()) {
                {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(Icons.Default.Clear, contentDescription = "Clear")
                    }
                }
            } else null,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color.White
            )
        )

        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            item {
                FilterChip(
                    selected = selectedCategory == null,
                    onClick = { onCategorySelect(null) },
                    label = { Text("All Products") },
                    shape = RoundedCornerShape(8.dp)
                )
            }
            items(categories) { cat ->
                FilterChip(
                    selected = selectedCategory == cat,
                    onClick = { onCategorySelect(if (selectedCategory == cat) null else cat) },
                    label = { Text(cat) },
                    shape = RoundedCornerShape(8.dp)
                )
            }
        }
    }
}

/**
 * Product item card showing unit price, vehicle stock count badge, and stepper.
 */
@Composable
private fun VehicleStockProductCard(
    item: VehicleStockItem,
    isTripMissing: Boolean,
    onQuantityChange: (Int) -> Unit
) {
    val product = item.product
    val available = item.vanStockQuantity
    val isOutOfStock = available <= 0

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, if (item.selectedQuantity > 0) Color(0xFF93C5FD) else Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = product.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                if (product.hindiName != null) {
                    Text(
                        text = product.hindiName,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "${CurrencyFormatter.formatPaise(product.pricePaise)} / ${product.unit}",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF2563EB)
                    )

                    Surface(
                        color = if (isOutOfStock) Color(0xFFFEF2F2) else Color(0xFFDCFCE7),
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            text = if (isOutOfStock) "Van: Out of stock" else "Van Stock: $available",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = if (isOutOfStock) Color(0xFFDC2626) else Color(0xFF166534),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            // Integer Quantity Stepper
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                IconButton(
                    onClick = { onQuantityChange(-1) },
                    enabled = item.selectedQuantity > 0 && !isTripMissing,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(if (item.selectedQuantity > 0 && !isTripMissing) Color(0xFFF1F5F9) else Color(0xFFF8FAFC))
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = "Decrease",
                        tint = if (item.selectedQuantity > 0) Color(0xFF1E293B) else Color(0xFF94A3B8),
                        modifier = Modifier.size(16.dp)
                    )
                }

                Text(
                    text = "${item.selectedQuantity}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    color = if (item.selectedQuantity > 0) Color(0xFF2563EB) else Color(0xFF64748B),
                    modifier = Modifier.widthIn(min = 24.dp),
                    textAlign = TextAlign.Center
                )

                IconButton(
                    onClick = { onQuantityChange(1) },
                    enabled = !isOutOfStock && item.selectedQuantity < available && !isTripMissing,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(if (!isOutOfStock && item.selectedQuantity < available && !isTripMissing) Color(0xFF2563EB) else Color(0xFFF1F5F9))
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Increase",
                        tint = if (!isOutOfStock && item.selectedQuantity < available && !isTripMissing) Color.White else Color(0xFF94A3B8),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

/**
 * Bottom Cart Panel with integer financial summary and prominent server-authoritative disclaimer.
 */
@Composable
private fun CartBottomPanel(
    state: VanSalesUiState,
    onSubmit: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = Color.White,
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        shadowElevation = 8.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Calculation breakdown & Provisional Estimate Disclaimer
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Subtotal: ${CurrencyFormatter.formatPaise(state.cartSubtotalPaise)} • Est. GST (18%): ${CurrencyFormatter.formatPaise(state.cartGstEstimatePaise)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF64748B),
                        fontSize = 11.sp
                    )
                    Text(
                        text = CurrencyFormatter.formatPaise(state.cartTotalEstimatePaise),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF2563EB)
                    )
                }

                Surface(
                    color = Color(0xFFEFF6FF),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, Color(0xFFBFDBFE))
                ) {
                    Text(
                        text = "${state.cartTotalUnits} units in cart",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF1D4ED8),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Non-authoritative disclaimer
            Text(
                text = "Provisional Estimate — Final line item pricing, taxes, schemes & inventory deductions are calculated authoritatively by the server.",
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF94A3B8),
                fontSize = 10.sp,
                lineHeight = 12.sp
            )

            // Submit Button
            Button(
                onClick = onSubmit,
                enabled = state.canSubmit,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (state.isProvisional) Color(0xFFD97706) else Color(0xFF16A34A),
                    disabledContainerColor = Color(0xFFE2E8F0),
                    contentColor = Color.White,
                    disabledContentColor = Color(0xFF94A3B8)
                )
            ) {
                if (state.isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("Submitting to Outbox…", fontWeight = FontWeight.Bold)
                } else {
                    Icon(
                        imageVector = if (state.isProvisional) Icons.Default.ShoppingCart else Icons.Default.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = when {
                            state.isTripMissing -> "Active Trip Required"
                            state.selectedRetailer == null -> "Select Retailer to Bill"
                            state.isCartEmpty -> "Add Items to Cart"
                            state.isProvisional -> "Record Provisional Order"
                            else -> "Confirm & Bill Van Sale"
                        },
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                }
            }
        }
    }
}
