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
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
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
    onClearMessages: () -> Unit,
    onSyncAgain: (() -> Unit)? = null
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

    // Determine the next shop: active visit shop first, or the first unvisited shop
    val nextShop = activeVisitRetailer ?: state.retailers.firstOrNull { !state.completedVisitRetailerIds.contains(it.id) }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 120.dp)
        ) {
            // 1. Employee Greeting, Beat & Duty Toggle Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = if (state.employeeName.isNotBlank()) "Hello, ${state.employeeName}" else "Hello, Sales Executive",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Black,
                                    color = Color(0xFF0F172A)
                                )
                                Text(
                                    text = "Assigned Beat: ${state.assignedBeat}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color(0xFF64748B),
                                    fontWeight = FontWeight.SemiBold
                                )
                            }

                            // Duty Status Pill
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (isOnShift) Color(0xFFDCFCE7) else Color(0xFFF1F5F9),
                                border = BorderStroke(1.dp, if (isOnShift) Color(0xFF86EFAC) else Color(0xFFCBD5E1))
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .clip(CircleShape)
                                            .background(if (isOnShift) Color(0xFF16A34A) else Color(0xFF64748B))
                                    )
                                    Text(
                                        text = if (isOnShift) "On Duty" else "Off Duty",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = if (isOnShift) Color(0xFF15803D) else Color(0xFF475569)
                                    )
                                }
                            }
                        }

                        // One prominent Start Duty / End Duty action button (minimum 48dp touch target)
                        if (isOnShift) {
                            OutlinedButton(
                                onClick = onEndShift,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !state.isLoading,
                                shape = RoundedCornerShape(10.dp),
                                border = BorderStroke(1.dp, Color(0xFFFCA5A5)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = Color(0xFFFEF2F2),
                                    contentColor = Color(0xFFDC2626)
                                )
                            ) {
                                Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color(0xFFDC2626))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("End Duty / Shift", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }
                        } else {
                            Button(
                                onClick = onStartShift,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !state.isLoading,
                                shape = RoundedCornerShape(10.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFF2563EB),
                                    contentColor = Color.White
                                )
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp), tint = Color.White)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Start Duty / Shift", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }
                        }
                    }
                }
            }

            // 2. Exactly Three Important Metrics Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp, horizontal = 8.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Metric 1: Visit progress
                        Column(
                            modifier = Modifier.weight(1f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Visited",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF64748B),
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = "${state.completedVisitRetailerIds.size} / ${state.retailers.size}",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF0F172A)
                            )
                        }

                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(32.dp)
                                .background(Color(0xFFE2E8F0))
                        )

                        // Metric 2: Today's order amount
                        Column(
                            modifier = Modifier.weight(1.2f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Today's Orders",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF64748B),
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = CurrencyFormatter.formatPaise(state.todayOrdersAmountPaise),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF2563EB)
                            )
                        }

                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(32.dp)
                                .background(Color(0xFFE2E8F0))
                        )

                        // Metric 3: Today's collection
                        Column(
                            modifier = Modifier.weight(1.2f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Today's Collection",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF64748B),
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = CurrencyFormatter.formatPaise(state.todayCollectionsAmountPaise),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF16A34A)
                            )
                        }
                    }
                }
            }

            // 3. Next Shop Card (Primary Call To Action)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (activeVisitRetailer != null) Color(0xFFEFF6FF) else Color.White
                    ),
                    border = BorderStroke(
                        1.5.dp,
                        if (activeVisitRetailer != null) Color(0xFF3B82F6) else Color(0xFF2563EB)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = if (activeVisitRetailer != null) Color(0xFFDBEAFE) else Color(0xFFEFF6FF)
                            ) {
                                Text(
                                    text = if (activeVisitRetailer != null) "ACTIVE VISIT IN PROGRESS" else "NEXT SHOP TO VISIT",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Black,
                                    color = Color(0xFF1D4ED8),
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                    fontSize = 10.sp
                                )
                            }

                            if (nextShop != null && nextShop.outstandingAmountPaise > 0) {
                                Text(
                                    text = "Due: ${CurrencyFormatter.formatPaise(nextShop.outstandingAmountPaise)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFDC2626)
                                )
                            }
                        }

                        if (nextShop != null) {
                            Text(
                                text = nextShop.name,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Black,
                                color = Color(0xFF0F172A)
                            )

                            if (nextShop.address.isNotBlank()) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Icon(
                                        Icons.Default.LocationOn,
                                        contentDescription = null,
                                        tint = Color(0xFF64748B),
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        text = nextShop.address,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFF64748B),
                                        maxLines = 1
                                    )
                                }
                            }

                            Button(
                                onClick = {
                                    if (activeVisitRetailer != null && activeVisitRetailer.id != nextShop.id) {
                                        blockedVisitRetailerName = activeVisitRetailer.name
                                    } else {
                                        onRetailerClick(nextShop.id)
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                shape = RoundedCornerShape(10.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFF2563EB),
                                    contentColor = Color.White
                                )
                            ) {
                                Text(
                                    text = if (activeVisitRetailer != null) "Continue Active Visit" else "Open Shop",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp
                                )
                                Spacer(Modifier.width(6.dp))
                                Icon(Icons.Default.ChevronRight, contentDescription = null, modifier = Modifier.size(18.dp))
                            }
                        } else {
                            Text(
                                text = if (state.retailers.isNotEmpty()) "All shops visited for today!" else "No shops assigned yet",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = if (state.retailers.isNotEmpty()) "Great job! All beat visits are complete." else "Contact Admin to assign your beat route.",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF64748B)
                            )
                        }
                    }
                }
            }

            // 4. Assigned Beat Shops List
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Assigned Shops (${state.retailers.size})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0F172A)
                    )
                    if (onSyncAgain != null) {
                        TextButton(
                            onClick = onSyncAgain,
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Sync", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }

            if (state.retailers.isEmpty() && state.isLoading) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().height(100.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Color(0xFF2563EB))
                    }
                }
            } else if (state.retailers.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Store,
                                contentDescription = null,
                                tint = Color(0xFF94A3B8),
                                modifier = Modifier.size(36.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "No shops in this beat",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = "Ask your Owner or Admin to assign shops.",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF64748B)
                            )
                        }
                    }
                }
            } else {
                items(state.retailers, key = { it.id }) { retailer ->
                    val isCurrentActive = state.activeVisit?.retailerId == retailer.id
                    val isCompleted = state.completedVisitRetailerIds.contains(retailer.id)

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                if (state.activeVisit != null && !isCurrentActive) {
                                    blockedVisitRetailerName = activeVisitRetailer?.name ?: "an active shop"
                                } else {
                                    onRetailerClick(retailer.id)
                                }
                            },
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(
                            1.dp,
                            when {
                                isCurrentActive -> Color(0xFF93C5FD)
                                isCompleted -> Color(0xFF86EFAC)
                                else -> Color(0xFFE2E8F0)
                            }
                        ),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                modifier = Modifier.weight(1f),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
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
                                        isCurrentActive -> Icon(Icons.Default.Schedule, contentDescription = null, tint = Color(0xFF1D4ED8), modifier = Modifier.size(18.dp))
                                        isCompleted -> Icon(Icons.Default.Check, contentDescription = null, tint = Color(0xFF15803D), modifier = Modifier.size(18.dp))
                                        else -> Icon(Icons.Default.Store, contentDescription = null, tint = Color(0xFF64748B), modifier = Modifier.size(18.dp))
                                    }
                                }

                                Column {
                                    Text(
                                        text = retailer.name,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF0F172A)
                                    )
                                    if (retailer.address.isNotBlank()) {
                                        Text(
                                            text = retailer.address,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = Color(0xFF64748B),
                                            maxLines = 1
                                        )
                                    }
                                }
                            }

                            Column(horizontalAlignment = Alignment.End) {
                                if (retailer.outstandingAmountPaise > 0) {
                                    Text(
                                        text = CurrencyFormatter.formatPaise(retailer.outstandingAmountPaise),
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFFDC2626)
                                    )
                                }
                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = when {
                                        isCurrentActive -> Color(0xFFDBEAFE)
                                        isCompleted -> Color(0xFFDCFCE7)
                                        else -> Color(0xFFF8FAFC)
                                    }
                                ) {
                                    Text(
                                        text = when {
                                            isCurrentActive -> "Active"
                                            isCompleted -> "Visited"
                                            else -> "Pending"
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = when {
                                            isCurrentActive -> Color(0xFF1E40AF)
                                            isCompleted -> Color(0xFF15803D)
                                            else -> Color(0xFF64748B)
                                        },
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                        fontSize = 11.sp
                                    )
                                }
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

    blockedVisitRetailerName?.let { activeName ->
        AlertDialog(
            onDismissRequest = { blockedVisitRetailerName = null },
            title = { Text("Active Visit in Progress", fontWeight = FontWeight.Bold) },
            text = {
                Text("You already have an active visit at '$activeName'. Please check out from that visit before starting a new one.")
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
                    Text("Go to Active Visit", color = Color.White, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { blockedVisitRetailerName = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}
