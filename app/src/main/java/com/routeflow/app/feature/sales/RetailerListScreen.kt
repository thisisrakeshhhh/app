package com.routeflow.app.feature.sales

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors

@Composable
fun RetailerListScreen(
    state: RetailerListState,
    onRetailerClick: (String) -> Unit,
    onStartShift: (() -> Unit)? = null,
    onAddRetailer: ((name: String, address: String, contact: String, lat: Double?, lng: Double?) -> Unit)? = null,
    onClearMessages: (() -> Unit)? = null,
    onSyncAgain: (() -> Unit)? = null
) {
    var showAddDialog by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.message, state.error) {
        state.message?.let { msg ->
            snackbarHostState.showSnackbar(msg)
            kotlinx.coroutines.delay(2000)
            onClearMessages?.invoke()
        }
        state.error?.let { err ->
            snackbarHostState.showSnackbar(err)
            kotlinx.coroutines.delay(2000)
            onClearMessages?.invoke()
        }
    }

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 120.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // 1. Compact Shift Status Banner (Off Duty warning if applicable)
                if (!state.isOnShift && onStartShift != null) {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                            border = BorderStroke(1.dp, Color(0xFFFECACA))
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFFDC2626))
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "Duty Off — Start shift for GPS",
                                        style = MaterialTheme.typography.bodySmall,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF991B1B)
                                    )
                                }

                                Button(
                                    onClick = onStartShift,
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                                    modifier = Modifier.height(36.dp)
                                ) {
                                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Start Duty", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // 2. Beat Header Card
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Row(
                                modifier = Modifier.weight(1f),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Route,
                                    contentDescription = null,
                                    tint = RFColors.Accent,
                                    modifier = Modifier.size(20.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = state.beatName,
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = RFColors.TextPrimary
                                    )
                                    val visitedCount = state.retailers.count { it.visitStatus == "VISITED" }
                                    Text(
                                        text = "${state.retailers.size} shops · $visitedCount visited",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = RFColors.TextSecondary
                                    )
                                }
                            }

                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                if (state.isOfflineCache && state.retailers.isNotEmpty()) {
                                    Surface(
                                        color = Color(0xFFFEF3C7),
                                        shape = RoundedCornerShape(8.dp),
                                        border = BorderStroke(1.dp, Color(0xFFFDE68A))
                                    ) {
                                        Text(
                                            text = "Offline",
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFFB45309),
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp)
                                        )
                                    }
                                }

                                if (onAddRetailer != null) {
                                    Button(
                                        onClick = {
                                            onClearMessages?.invoke()
                                            showAddDialog = true
                                        },
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                                        modifier = Modifier.height(40.dp)
                                    ) {
                                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(Modifier.width(4.dp))
                                        Text("Add Shop", fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                                    }
                                }
                            }
                        }
                    }
                }



                if (state.retailers.isEmpty()) {
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
                                    text = "No shops assigned yet. Contact owner/admin.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary,
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                                if (onSyncAgain != null) {
                                    Spacer(Modifier.height(16.dp))
                                    OutlinedButton(
                                        onClick = onSyncAgain,
                                        shape = RoundedCornerShape(8.dp),
                                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF2563EB))
                                    ) {
                                        Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text("Sync Again", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    items(state.retailers, key = { it.retailer.id }) { item ->
                        RetailerCard(item, onRetailerClick)
                    }
                }
            }



            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp)
            )
        }
    }

    if (showAddDialog && onAddRetailer != null) {
        AddShopDialog(
            isSaving = state.isSaving,
            onDismiss = { showAddDialog = false },
            onConfirm = { name, address, contact, lat, lng ->
                onAddRetailer(name, address, contact, lat, lng)
                showAddDialog = false
            }
        )
    }
}

@Composable
private fun AddShopDialog(
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (name: String, address: String, contact: String, lat: Double?, lng: Double?) -> Unit
) {
    val context = LocalContext.current
    var name by remember { mutableStateOf("") }
    var contactNumber by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var latitude by remember { mutableStateOf<Double?>(null) }
    var longitude by remember { mutableStateOf<Double?>(null) }
    var gpsStatus by remember { mutableStateOf("Tap to detect phone GPS") }
    var isDetectingGps by remember { mutableStateOf(false) }

    fun detectGps() {
        isDetectingGps = true
        gpsStatus = "Locating via GPS…"
        try {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            val fineOk = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarseOk = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (lm != null && (fineOk || coarseOk)) {
                val loc = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                if (loc != null) {
                    latitude = loc.latitude
                    longitude = loc.longitude
                    gpsStatus = "GPS locked: %.4f, %.4f (±%.0fm)".format(loc.latitude, loc.longitude, loc.accuracy)
                } else {
                    gpsStatus = "No location cached. Turn on device GPS."
                }
            } else {
                gpsStatus = "Location permission required."
            }
        } catch (e: Exception) {
            gpsStatus = "GPS error: ${e.message}"
        } finally {
            isDetectingGps = false
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { perms ->
        val granted = perms[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                perms[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) {
            detectGps()
        } else {
            gpsStatus = "Permission denied. GPS optional."
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Onboard New Retailer", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Shop Name *") },
                    placeholder = { Text("e.g. Gupta General Store") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp)
                )

                OutlinedTextField(
                    value = contactNumber,
                    onValueChange = { contactNumber = it },
                    label = { Text("Contact Mobile") },
                    placeholder = { Text("e.g. 9876543210") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp)
                )

                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("Shop Address") },
                    placeholder = { Text("e.g. Shop 12, Main Market, Sector 4") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp)
                )

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, if (latitude != null) Color(0xFF86EFAC) else Color(0xFFE2E8F0))
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.LocationOn,
                                    contentDescription = null,
                                    tint = if (latitude != null) Color(0xFF16A34A) else Color(0xFF2563EB),
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "Phone Location (GPS)",
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = if (latitude != null) Color(0xFF15803D) else Color(0xFF1E293B)
                                )
                            }

                            Button(
                                onClick = {
                                    val hasFine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                    val hasCoarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                    if (hasFine || hasCoarse) {
                                        detectGps()
                                    } else {
                                        permissionLauncher.launch(
                                            arrayOf(
                                                Manifest.permission.ACCESS_FINE_LOCATION,
                                                Manifest.permission.ACCESS_COARSE_LOCATION
                                            )
                                        )
                                    }
                                },
                                shape = RoundedCornerShape(8.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (latitude != null) Color(0xFF16A34A) else Color(0xFF2563EB)
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                modifier = Modifier.height(34.dp)
                            ) {
                                Text(if (latitude != null) "Update GPS" else "Detect GPS", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }

                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = gpsStatus,
                            style = MaterialTheme.typography.bodySmall,
                            color = if (latitude != null) Color(0xFF15803D) else Color(0xFF64748B)
                        )
                    }
                }
            }
        },
        confirmButton = {
            val isFormValid = name.trim().length >= 3 && address.trim().isNotBlank() && (contactNumber.trim().isEmpty() || contactNumber.trim().matches(Regex("^[0-9]{10}$")))
            Button(
                onClick = { onConfirm(name.trim(), address.trim(), contactNumber.trim(), latitude, longitude) },
                enabled = isFormValid && !isSaving,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text(if (isSaving) "Saving…" else "Save Shop", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}

@Composable
private fun RetailerCard(
    item: RetailerItemState,
    onRetailerClick: (String) -> Unit
) {
    val context = LocalContext.current

    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = { onRetailerClick(item.retailer.id) },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(
            1.dp,
            if (item.isHighCreditRisk) Color(0xFFFCA5A5) else Color(0xFFE2E8F0)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            // Header Row: Shop Name & Status Badge
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = item.retailer.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary,
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                VisitStatusBadge(item.visitStatus)
            }

            Spacer(Modifier.height(4.dp))

            // Address & Phone
            Text(
                text = item.retailer.address,
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            if (item.retailer.contactNumber.isNotBlank()) {
                Text(
                    text = "Ph: ${item.retailer.contactNumber}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B)
                )
            }

            Spacer(Modifier.height(10.dp))

            // Financial & Credit Risk Row
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    val outstanding = item.retailer.outstandingAmountPaise
                    val (label, amountText, color) = when {
                        outstanding < 0 -> Triple("Advance Balance", CurrencyFormatter.formatPaise(-outstanding), Color(0xFF15803D))
                        outstanding > 0 -> Triple("Pending Udhaar", CurrencyFormatter.formatPaise(outstanding), Color(0xFFDC2626))
                        else -> Triple("Balance", "No Due", Color(0xFF64748B))
                    }

                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelSmall,
                        color = RFColors.TextSecondary
                    )
                    Text(
                        text = amountText,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = color
                    )
                }

                if (item.isHighCreditRisk) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFFEF2F2),
                        border = BorderStroke(1.dp, Color(0xFFFCA5A5))
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        ) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFDC2626), modifier = Modifier.size(12.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(
                                text = "High Credit Risk",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFFDC2626)
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Field Action Buttons: Check In (>=48dp), Call, Map
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Call Button
                OutlinedButton(
                    onClick = {
                        val phone = item.retailer.contactNumber.trim()
                        if (phone.isNotBlank()) {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                            try { context.startActivity(intent) } catch (_: Exception) {}
                        }
                    },
                    modifier = Modifier.height(48.dp),
                    shape = RoundedCornerShape(10.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp)
                ) {
                    Icon(Icons.Default.Phone, contentDescription = "Call", modifier = Modifier.size(18.dp), tint = Color(0xFF2563EB))
                }

                // Map Button
                OutlinedButton(
                    onClick = {
                        val lat = item.retailer.latitude
                        val lng = item.retailer.longitude
                        val addr = item.retailer.address
                        val uri = if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                            Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(item.retailer.name)})")
                        } else {
                            Uri.parse("geo:0,0?q=${Uri.encode(addr)}")
                        }
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        try { context.startActivity(intent) } catch (_: Exception) {}
                    },
                    modifier = Modifier.height(48.dp),
                    shape = RoundedCornerShape(10.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp)
                ) {
                    Icon(Icons.Default.Map, contentDescription = "Map", modifier = Modifier.size(18.dp), tint = Color(0xFF16A34A))
                }

                // Primary Check In CTA
                Button(
                    onClick = { onRetailerClick(item.retailer.id) },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = stringResource(R.string.check_in_button),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                    Spacer(Modifier.width(6.dp))
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = Color.White
                    )
                }
            }
        }
    }
}

@Composable
private fun VisitStatusBadge(status: String) {
    val (text, bgColor, textColor) = when (status) {
        "ORDERED" -> Triple("Ordered", Color(0xFFDCFCE7), Color(0xFF15803D))
        "NO_ORDER" -> Triple("No Order", Color(0xFFF1F5F9), Color(0xFF475569))
        "VISITED" -> Triple("Visited", Color(0xFFDBEAFE), Color(0xFF1D4ED8))
        "IN_PROGRESS", "VISITING" -> Triple("In Progress", Color(0xFFFEF3C7), Color(0xFFD97706))
        else -> Triple("Pending", Color(0xFFFFFBEB), Color(0xFFB45309))
    }
    Surface(
        color = bgColor,
        shape = RoundedCornerShape(8.dp)
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = textColor
        )
    }
}
