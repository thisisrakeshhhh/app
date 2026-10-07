package com.routeflow.app.feature.sales

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Retailer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesTodayScreen(
    state: SalesTodayState,
    onStartShift: () -> Unit,
    onEndShift: () -> Unit,
    onRetailerClick: (String) -> Unit,
    onClearMessages: () -> Unit
) {
    val snackbarHostState = remember { SnackbarHostState() }
    var blockedVisitRetailerName by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(state.message, state.errorMessage) {
        state.message?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
        state.errorMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
    }

    val isOnShift = state.activeShift != null && state.activeShift.status == "ON_SHIFT"
    val activeVisitRetailer = state.activeVisit?.let { active ->
        state.retailers.find { it.id == active.retailerId }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = stringResource(R.string.sales_today_shops),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Black,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = "Beat Route & Retailer Visits",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                    if (com.routeflow.app.BuildConfig.STAGING_MODE) {
                        Surface(
                            color = Color(0xFFEFF6FF),
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, Color(0xFFBFDBFE))
                        ) {
                            Text(
                                text = "Step 2/8 • Demo",
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF2563EB)
                            )
                        }
                    }
                }
            }

            // 1. Shift Tracking Banner
            item {
                ShiftControlCard(
                    isOnShift = isOnShift,
                    onStartShift = onStartShift,
                    onEndShift = onEndShift,
                    isLoading = state.isLoading
                )
            }

            // 2. Active Visit Warning Banner
            if (activeVisitRetailer != null) {
                item {
                    ActiveVisitBanner(
                        retailer = activeVisitRetailer,
                        onClick = { onRetailerClick(activeVisitRetailer.id) }
                    )
                }
            }

            // 3. Section Title & Progress
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.assigned_shops_header, state.retailers.size),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                    Surface(
                        color = Color(0xFFEFF6FF),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.visited_progress, state.completedVisitRetailerIds.size, state.retailers.size),
                            style = MaterialTheme.typography.labelSmall,
                            color = RFColors.Accent,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            // 4. Retailers list
            if (state.retailers.isEmpty() && state.isLoading) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().height(120.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
            } else if (state.retailers.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                    ) {
                        Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                            Text(
                                text = "No shops assigned to your beat.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = RFColors.TextSecondary
                            )
                        }
                    }
                }
            } else {
                items(state.retailers, key = { it.id }) { retailer ->
                    val isCurrentActive = state.activeVisit?.retailerId == retailer.id
                    val isCompleted = state.completedVisitRetailerIds.contains(retailer.id)

                    ShopRowCard(
                        retailer = retailer,
                        isCurrentActive = isCurrentActive,
                        isCompleted = isCompleted,
                        onClick = {
                            if (state.activeVisit != null && !isCurrentActive) {
                                blockedVisitRetailerName = activeVisitRetailer?.name ?: "an active shop"
                            } else {
                                onRetailerClick(retailer.id)
                            }
                        }
                    )
                }
            }
        }
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }

    blockedVisitRetailerName?.let { activeName ->
        AlertDialog(
            onDismissRequest = { blockedVisitRetailerName = null },
            title = { Text(stringResource(R.string.active_visit_alert_title), fontWeight = FontWeight.Bold) },
            text = {
                Text(stringResource(R.string.active_visit_alert_body, activeName))
            },
            confirmButton = {
                Button(
                    onClick = {
                        val activeId = state.activeVisit?.retailerId
                        blockedVisitRetailerName = null
                        if (activeId != null) {
                            onRetailerClick(activeId)
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    )
                ) {
                    Text(stringResource(R.string.go_to_active_visit), color = Color.White, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { blockedVisitRetailerName = null }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }
}

@Composable
private fun ShiftControlCard(
    isOnShift: Boolean,
    onStartShift: () -> Unit,
    onEndShift: () -> Unit,
    isLoading: Boolean
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isOnShift) Color(0xFFF0FDF4) else Color.White
        ),
        border = BorderStroke(
            1.dp,
            if (isOnShift) Color(0xFFBBF7D0) else Color(0xFFE2E8F0)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(if (isOnShift) Color(0xFF16A34A) else Color(0xFF94A3B8))
                )
                Spacer(modifier = Modifier.width(8.dp))
                Column {
                    Text(
                        text = if (isOnShift) stringResource(R.string.on_shift) else stringResource(R.string.off_shift),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (isOnShift) Color(0xFF15803D) else RFColors.TextPrimary
                    )
                    Text(
                        text = if (isOnShift) "Live GPS Active" else "Tap Start to track route",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isOnShift) Color(0xFF16A34A) else Color(0xFF64748B)
                    )
                }
            }

            if (isOnShift) {
                OutlinedButton(
                    onClick = onEndShift,
                    modifier = Modifier.height(40.dp),
                    enabled = !isLoading,
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = Color(0xFFFEF2F2),
                        contentColor = Color(0xFFDC2626)
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFDC2626))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = stringResource(R.string.end_shift),
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFDC2626),
                        fontSize = 13.sp
                    )
                }
            } else {
                Button(
                    onClick = onStartShift,
                    modifier = Modifier.height(40.dp),
                    enabled = !isLoading,
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    ),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = stringResource(R.string.start_shift),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun ActiveVisitBanner(
    retailer: Retailer,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
        border = BorderStroke(1.dp, Color(0xFFBFDBFE)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.active_visit_banner),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF1D4ED8),
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = retailer.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = stringResource(R.string.tap_to_view_or_checkout),
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF3B82F6)
                )
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Color(0xFF2563EB))
        }
    }
}

@Composable
private fun ShopRowCard(
    retailer: Retailer,
    isCurrentActive: Boolean,
    isCompleted: Boolean,
    onClick: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val isHighCreditRisk = retailer.outstandingAmountPaise > (retailer.creditLimitPaise * 0.8) && retailer.creditLimitPaise > 0

    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(
            1.dp,
            when {
                isCurrentActive -> Color(0xFF93C5FD)
                isCompleted -> Color(0xFF86EFAC)
                isHighCreditRisk -> Color(0xFFFCA5A5)
                else -> Color(0xFFE2E8F0)
            }
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(
                                when {
                                    isCurrentActive -> Color(0xFFDBEAFE)
                                    isCompleted -> Color(0xFFDCFCE7)
                                    else -> Color(0xFFF1F5F9)
                                }
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        when {
                            isCurrentActive -> Icon(Icons.Default.Schedule, contentDescription = null, tint = Color(0xFF1D4ED8), modifier = Modifier.size(20.dp))
                            isCompleted -> Icon(Icons.Default.Check, contentDescription = null, tint = Color(0xFF15803D), modifier = Modifier.size(20.dp))
                            else -> Icon(Icons.Default.Store, contentDescription = null, tint = Color(0xFF64748B), modifier = Modifier.size(20.dp))
                        }
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column {
                        Text(
                            text = retailer.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = retailer.address,
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary,
                            maxLines = 1
                        )
                    }
                }

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = when {
                        isCurrentActive -> Color(0xFFDBEAFE)
                        isCompleted -> Color(0xFFDCFCE7)
                        else -> Color(0xFFFEF3C7)
                    }
                ) {
                    Text(
                        text = when {
                            isCurrentActive -> stringResource(R.string.in_progress)
                            isCompleted -> stringResource(R.string.visited)
                            else -> stringResource(R.string.pending)
                        },
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = when {
                            isCurrentActive -> Color(0xFF1E40AF)
                            isCompleted -> Color(0xFF15803D)
                            else -> Color(0xFF92400E)
                        },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Outstanding vs Advance line
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                val outstanding = retailer.outstandingAmountPaise
                val (balLabel, balValue, balColor) = when {
                    outstanding < 0 -> Triple("Advance:", CurrencyFormatter.formatPaise(-outstanding), Color(0xFF15803D))
                    outstanding > 0 -> Triple("Pending Udhaar:", CurrencyFormatter.formatPaise(outstanding), Color(0xFFDC2626))
                    else -> Triple("Balance:", "₹0", Color(0xFF64748B))
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = "$balLabel ", style = MaterialTheme.typography.bodySmall, color = RFColors.TextSecondary)
                    Text(text = balValue, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold, color = balColor)
                }

                if (isHighCreditRisk) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFFEF2F2),
                        border = BorderStroke(1.dp, Color(0xFFFCA5A5))
                    ) {
                        Text(
                            text = "High Credit Risk",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFDC2626),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Action Buttons: Call, Map, Check In
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (retailer.contactNumber.isNotBlank()) {
                    OutlinedButton(
                        onClick = {
                            val intent = android.content.Intent(android.content.Intent.ACTION_DIAL, android.net.Uri.parse("tel:${retailer.contactNumber}"))
                            try { context.startActivity(intent) } catch (_: Exception) {}
                        },
                        modifier = Modifier.height(48.dp),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) {
                        Text("Call", fontWeight = FontWeight.Bold, color = Color(0xFF2563EB))
                    }
                }

                OutlinedButton(
                    onClick = {
                        val lat = retailer.latitude
                        val lng = retailer.longitude
                        val uri = if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                            android.net.Uri.parse("geo:$lat,$lng?q=$lat,$lng(${android.net.Uri.encode(retailer.name)})")
                        } else {
                            android.net.Uri.parse("geo:0,0?q=${android.net.Uri.encode(retailer.address)}")
                        }
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uri)
                        try { context.startActivity(intent) } catch (_: Exception) {}
                    },
                    modifier = Modifier.height(48.dp),
                    shape = RoundedCornerShape(10.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp)
                ) {
                    Text("Map", fontWeight = FontWeight.Bold, color = Color(0xFF16A34A))
                }

                Button(
                    onClick = onClick,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isCurrentActive) Color(0xFF1D4ED8) else Color(0xFF2563EB),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = if (isCurrentActive) "Continue Visit" else stringResource(R.string.check_in_button),
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}
