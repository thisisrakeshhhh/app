package com.routeflow.app.feature.sales

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AssignmentTurnedIn
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Retailer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShopVisitScreen(
    state: ShopVisitState,
    onCheckIn: () -> Unit,
    onCheckOut: (notes: String?, noOrderReason: String?) -> Unit,
    onCreateOrder: () -> Unit,
    onStockCheck: () -> Unit,
    onCollectPayment: ((amountPaise: Long, method: String, reference: String) -> Unit)? = null
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()

    var showNoOrderDialog by remember { mutableStateOf(false) }
    var showCollectDialog by remember { mutableStateOf(false) }
    var showCheckoutConfirmDialog by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.collectionSuccessMessage) {
        state.collectionSuccessMessage?.let {
            snackbarHostState.showSnackbar(it)
        }
    }

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else if (state.retailer == null) {
        Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.Store, contentDescription = null, tint = Color(0xFF94A3B8), modifier = Modifier.size(56.dp))
                Spacer(Modifier.height(16.dp))
                Text("Shop Not Found", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = RFColors.TextPrimary)
                Spacer(Modifier.height(6.dp))
                Text("This retailer is not assigned to your beat or has been removed.", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    } else {
        val retailer = state.retailer
        val isCheckedIn = state.activeVisit != null

        Scaffold(
            snackbarHost = { SnackbarHost(snackbarHostState) }
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .verticalScroll(scrollState)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 1. Retailer Profile Header Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(Modifier.padding(18.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.Top
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(
                                    text = retailer.name,
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Black,
                                    color = RFColors.TextPrimary
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    text = retailer.address,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = RFColors.TextSecondary
                                )
                                if (retailer.contactNumber.isNotBlank()) {
                                    Spacer(Modifier.height(2.dp))
                                    Text(
                                        text = "Phone: ${retailer.contactNumber}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFF475569)
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (isCheckedIn) Color(0xFFDCFCE7) else Color(0xFFFEF3C7)
                            ) {
                                Text(
                                    text = if (isCheckedIn) "Checked In" else "Pending Visit",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isCheckedIn) Color(0xFF15803D) else Color(0xFF92400E),
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        Spacer(Modifier.height(14.dp))

                        // Quick Call & Map Action Buttons
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            if (retailer.contactNumber.isNotBlank()) {
                                OutlinedButton(
                                    onClick = {
                                        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${retailer.contactNumber}"))
                                        try { context.startActivity(intent) } catch (_: Exception) {}
                                    },
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(46.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    border = BorderStroke(1.dp, Color(0xFF93C5FD)),
                                    colors = ButtonDefaults.outlinedButtonColors(
                                        containerColor = Color(0xFFEFF6FF),
                                        contentColor = Color(0xFF1D4ED8)
                                    )
                                ) {
                                    Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text("Call Shop", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                }
                            }

                            OutlinedButton(
                                onClick = {
                                    val lat = retailer.latitude
                                    val lng = retailer.longitude
                                    val uri = if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                                        Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(retailer.name)})")
                                    } else {
                                        Uri.parse("geo:0,0?q=${Uri.encode(retailer.address)}")
                                    }
                                    val intent = Intent(Intent.ACTION_VIEW, uri)
                                    try { context.startActivity(intent) } catch (_: Exception) {}
                                },
                                modifier = Modifier
                                    .weight(1f)
                                    .height(46.dp),
                                shape = RoundedCornerShape(10.dp),
                                border = BorderStroke(1.dp, Color(0xFF86EFAC)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = Color(0xFFF0FDF4),
                                    contentColor = Color(0xFF15803D)
                                )
                            ) {
                                Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Directions", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                        }
                    }
                }

                // 2. Financial & Credit Dossier Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            text = "Account & Balance Details",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary
                        )

                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val outstanding = retailer.outstandingAmountPaise
                            val (label, text, color) = when {
                                outstanding < 0 -> Triple("Advance Balance", CurrencyFormatter.formatPaise(-outstanding), Color(0xFF15803D))
                                outstanding > 0 -> Triple("Pending Udhaar", CurrencyFormatter.formatPaise(outstanding), Color(0xFFDC2626))
                                else -> Triple("Balance", "No Due", Color(0xFF64748B))
                            }

                            Column {
                                Text(label, style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
                                Text(text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Black, color = color)
                            }

                            Column(horizontalAlignment = Alignment.End) {
                                Text("Credit Limit", style = MaterialTheme.typography.labelSmall, color = RFColors.TextSecondary)
                                Text(
                                    CurrencyFormatter.formatPaise(retailer.creditLimitPaise),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                            }
                        }

                        HorizontalDivider(color = Color(0xFFF1F5F9))

                        // Last Order & Purchasing History
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = Color(0xFF2563EB), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = state.lastOrderSummary ?: "No past orders",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF334155),
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }

                // 3. GPS Verification Status Card
                Surface(
                    color = Color(0xFFF8FAFC),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = Color(0xFF16A34A),
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "Phone GPS Active • Geotagging enabled (±5m)",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF15803D),
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                // 4. PRE-CHECK-IN vs POST-CHECK-IN WORKFLOW
                if (!isCheckedIn) {
                    // Ready to start visit card with prominent CTA
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
                        border = BorderStroke(1.dp, Color(0xFFBFDBFE))
                    ) {
                        Column(
                            Modifier.padding(20.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Arrived at ${retailer.name}?",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF1E40AF)
                            )
                            Text(
                                text = "Check in to record your visit location and unlock order booking, shelf audits, and collections.",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF3B82F6),
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )

                            Button(
                                onClick = onCheckIn,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(52.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFF2563EB),
                                    contentColor = Color.White
                                ),
                                elevation = ButtonDefaults.buttonElevation(defaultElevation = 3.dp)
                            ) {
                                Icon(Icons.Default.Store, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                                Spacer(Modifier.width(10.dp))
                                Text(
                                    text = "Check In",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    fontSize = 15.sp
                                )
                            }
                        }
                    }
                } else {
                    // Active Visit Card with Live Timer
                    val minutes = state.durationSeconds / 60
                    val seconds = state.durationSeconds % 60
                    val timeFormatted = String.format("%02d:%02d", minutes, seconds)

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)),
                        border = BorderStroke(1.dp, Color(0xFF86EFAC)),
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                    ) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(18.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(10.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFF16A34A))
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        text = "VISIT IN PROGRESS",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF15803D),
                                        letterSpacing = 1.sp
                                    )
                                }
                                Spacer(Modifier.height(4.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Timer, contentDescription = null, tint = Color(0xFF15803D), modifier = Modifier.size(22.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(
                                        text = timeFormatted,
                                        style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.Black,
                                        color = Color(0xFF14532D)
                                    )
                                }
                            }

                            OutlinedButton(
                                onClick = { showCheckoutConfirmDialog = true },
                                shape = RoundedCornerShape(10.dp),
                                border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = Color(0xFFFEF2F2),
                                    contentColor = Color(0xFFDC2626)
                                ),
                                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)
                            ) {
                                Text("Check Out", fontWeight = FontWeight.Bold, color = Color(0xFFDC2626))
                            }
                        }
                    }

                    // Field Actions Header
                    Text(
                        text = "Field Actions",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )

                    // 4 Field Action Cards (2x2 Grid)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        // Action 1: Book Order
                        VisitActionTile(
                            modifier = Modifier.weight(1f),
                            title = "Book Order",
                            subtitle = "Take retailer order",
                            icon = Icons.Default.ShoppingCart,
                            accentColor = Color(0xFF2563EB),
                            backgroundColor = Color(0xFFEFF6FF),
                            onClick = onCreateOrder
                        )

                        // Action 2: Stock Check
                        VisitActionTile(
                            modifier = Modifier.weight(1f),
                            title = "Stock Check",
                            subtitle = "Shelf audit & count",
                            icon = Icons.Default.Inventory2,
                            accentColor = Color(0xFF16A34A),
                            backgroundColor = Color(0xFFF0FDF4),
                            onClick = onStockCheck
                        )
                    }

                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        // Action 3: Collect Payment
                        VisitActionTile(
                            modifier = Modifier.weight(1f),
                            title = "Collect Payment",
                            subtitle = "Cash / UPI receipt",
                            icon = Icons.Default.Payments,
                            accentColor = Color(0xFFD97706),
                            backgroundColor = Color(0xFFFFFBEB),
                            onClick = { showCollectDialog = true }
                        )

                        // Action 4: No Order Reason
                        VisitActionTile(
                            modifier = Modifier.weight(1f),
                            title = "No Order",
                            subtitle = "Record reason & exit",
                            icon = Icons.Default.Block,
                            accentColor = Color(0xFF64748B),
                            backgroundColor = Color(0xFFF8FAFC),
                            onClick = { showNoOrderDialog = true }
                        )
                    }

                    Spacer(Modifier.height(8.dp))

                    // Final Big Check Out Button
                    Button(
                        onClick = { showCheckoutConfirmDialog = true },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF1E293B),
                            contentColor = Color.White
                        )
                    ) {
                        Icon(Icons.Default.AssignmentTurnedIn, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "Check Out",
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            style = MaterialTheme.typography.titleMedium
                        )
                    }
                }
            }
        }
    }

    // Modal: Collect Payment Dialog
    if (showCollectDialog && state.retailer != null) {
        val retailer = state.retailer
        var amountText by remember { mutableStateOf("") }
        var selectedMethod by remember { mutableStateOf("CASH") }
        var refText by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { showCollectDialog = false },
            title = { Text("Collect from ${retailer.name}", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Pending Udhaar: ₹${"%,d".format(retailer.outstandingAmountPaise / 100)}",
                        color = Color(0xFFDC2626),
                        fontWeight = FontWeight.Bold
                    )
                    OutlinedTextField(
                        value = amountText,
                        onValueChange = { amountText = it },
                        label = { Text("Amount (₹) *") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp)
                    )
                    Text("Payment Mode:")
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("CASH", "UPI", "CHEQUE").forEach { mode ->
                            FilterChip(
                                selected = selectedMethod == mode,
                                onClick = { selectedMethod = mode },
                                label = { Text(mode) }
                            )
                        }
                    }
                    OutlinedTextField(
                        value = refText,
                        onValueChange = { refText = it },
                        label = { Text("Receipt / Ref No. (Optional)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp)
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val amt = (amountText.toDoubleOrNull() ?: 0.0) * 100
                        onCollectPayment?.invoke(amt.toLong(), selectedMethod, refText.trim())
                        showCollectDialog = false
                    },
                    enabled = (amountText.toDoubleOrNull() ?: 0.0) > 0.0,
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
                ) {
                    Text("Save Receipt", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCollectDialog = false }) {
                    Text("Cancel", color = Color(0xFF64748B))
                }
            }
        )
    }

    // Modal: No Order Reason Dialog
    if (showNoOrderDialog) {
        val reasons = listOf(
            "Shop Closed / दुकान बंद है",
            "Stock Already Sufficient / पर्याप्त स्टॉक है",
            "Owner Not Available / मालिक उपलब्ध नहीं",
            "Payment Dispute / पिछला हिसाब बाकी",
            "Price Issue / दाम ज्यादा है",
            "Other / अन्य कारण"
        )
        var selectedReason by remember { mutableStateOf(reasons[0]) }

        AlertDialog(
            onDismissRequest = { showNoOrderDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Block, contentDescription = null, tint = Color(0xFFDC2626))
                    Spacer(Modifier.width(8.dp))
                    Text("Reason for No Order", fontWeight = FontWeight.Bold)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Select why no order was booked during this visit:",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                    reasons.forEach { reason ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedReason = reason }
                                .padding(vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedReason == reason,
                                onClick = { selectedReason = reason }
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(reason, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        onCheckOut(null, selectedReason)
                        showNoOrderDialog = false
                    },
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                ) {
                    Text("Save & Check Out", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showNoOrderDialog = false }) {
                    Text("Cancel", color = Color(0xFF64748B))
                }
            }
        )
    }

    // Modal: Checkout Confirmation Dialog
    if (showCheckoutConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showCheckoutConfirmDialog = false },
            title = { Text("Complete Shop Visit?", fontWeight = FontWeight.Bold) },
            text = {
                Text("This will record check-out time and finalize the visit report for this retailer.")
            },
            confirmButton = {
                Button(
                    onClick = {
                        onCheckOut(null, null)
                        showCheckoutConfirmDialog = false
                    },
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
                ) {
                    Text("Confirm Check Out", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCheckoutConfirmDialog = false }) {
                    Text("Keep Visiting", color = Color(0xFF64748B))
                }
            }
        )
    }
}

@Composable
private fun VisitActionTile(
    modifier: Modifier = Modifier,
    title: String,
    subtitle: String,
    icon: ImageVector,
    accentColor: Color,
    backgroundColor: Color,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .height(108.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(14.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(backgroundColor),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(20.dp))
            }

            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = RFColors.TextSecondary,
                    fontSize = 11.sp
                )
            }
        }
    }
}
