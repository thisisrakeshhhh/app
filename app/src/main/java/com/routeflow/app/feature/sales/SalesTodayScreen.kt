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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesTodayScreen(
    state: SalesTodayState,
    onStartShift: () -> Unit,
    onEndShift: () -> Unit,
    onRetailerClick: (String) -> Unit,
    onClearMessages: () -> Unit,
    onSyncAgain: (() -> Unit)? = null,
    onNavigateRoute: (() -> Unit)? = null
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

    val nextShop = activeVisitRetailer ?: state.retailers.firstOrNull { !state.completedVisitRetailerIds.contains(it.id) }

    Box(modifier = Modifier.fillMaxSize().background(RFColors.Background)) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // 1. Employee Greeting, Beat & Duty Toggle Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                    border = BorderStroke(1.dp, RFColors.Border),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
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
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Text(
                                    text = "Assigned Beat: ${state.assignedBeat}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary,
                                    fontWeight = FontWeight.Medium
                                )
                            }

                            // Duty Status Pill
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (isOnShift) RFColors.SuccessLight else RFColors.NeutralLight,
                                border = BorderStroke(1.dp, if (isOnShift) RFColors.Success.copy(alpha = 0.3f) else RFColors.Border)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .clip(CircleShape)
                                            .background(if (isOnShift) RFColors.Success else RFColors.TextSecondary)
                                    )
                                    Text(
                                        text = if (isOnShift) "On Duty" else "Off Duty",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = if (isOnShift) RFColors.Success else RFColors.TextSecondary
                                    )
                                }
                            }
                        }

                        // Shift Start/End Action Button
                        if (isOnShift) {
                            OutlinedButton(
                                onClick = onEndShift,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !state.isLoading,
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, RFColors.Danger.copy(alpha = 0.3f)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = RFColors.DangerLight,
                                    contentColor = RFColors.Danger
                                )
                            ) {
                                Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(18.dp), tint = RFColors.Danger)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("End Duty / Shift", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                            }
                        } else {
                            Button(
                                onClick = onStartShift,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp),
                                enabled = !state.isLoading,
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = RFColors.Primary,
                                    contentColor = Color.White
                                )
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp), tint = Color.White)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Start Duty / Shift", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                            }
                        }

                        if (onNavigateRoute != null) {
                            OutlinedButton(
                                onClick = onNavigateRoute,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(44.dp),
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, RFColors.Primary.copy(alpha = 0.4f)),
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Primary)
                            ) {
                                Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Today's Assigned Route & Map", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }

            // 2. Exactly Three Important Metrics Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                    border = BorderStroke(1.dp, RFColors.Border),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 14.dp, horizontal = 12.dp),
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
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = "${state.completedVisitRetailerIds.size}/${state.retailers.size}",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                        }

                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(32.dp)
                                .background(RFColors.Border)
                        )

                        // Metric 2: Today's order amount
                        Column(
                            modifier = Modifier.weight(1.2f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Orders",
                                style = MaterialTheme.typography.labelSmall,
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = CurrencyFormatter.formatPaise(state.todayOrdersAmountPaise),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Primary,
                                maxLines = 1
                            )
                        }

                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(32.dp)
                                .background(RFColors.Border)
                        )

                        // Metric 3: Today's collection
                        Column(
                            modifier = Modifier.weight(1.2f),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Collected",
                                style = MaterialTheme.typography.labelSmall,
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = CurrencyFormatter.formatPaise(state.todayCollectionsAmountPaise),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Success,
                                maxLines = 1
                            )
                        }
                    }
                }
            }

            // 3. Next Shop Card (Primary Call To Action)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (activeVisitRetailer != null) RFColors.InfoLight else RFColors.Surface
                    ),
                    border = BorderStroke(
                        1.5.dp,
                        if (activeVisitRetailer != null) RFColors.Primary else RFColors.Border
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
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
                                color = if (activeVisitRetailer != null) RFColors.Primary.copy(alpha = 0.15f) else RFColors.InfoLight
                            ) {
                                Text(
                                    text = if (activeVisitRetailer != null) "ACTIVE VISIT IN PROGRESS" else "NEXT VISIT",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.Primary,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                    fontSize = 11.sp
                                )
                            }

                            if (nextShop != null && nextShop.outstandingAmountPaise > 0) {
                                Text(
                                    text = "Due: ${CurrencyFormatter.formatPaise(nextShop.outstandingAmountPaise)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = RFColors.Danger
                                )
                            }
                        }

                        if (nextShop != null) {
                            Text(
                                text = nextShop.name,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )

                            if (nextShop.address.isNotBlank()) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Icon(
                                        Icons.Default.LocationOn,
                                        contentDescription = null,
                                        tint = RFColors.TextSecondary,
                                        modifier = Modifier.size(15.dp)
                                    )
                                    Text(
                                        text = nextShop.address,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = RFColors.TextSecondary,
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
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = RFColors.Primary,
                                    contentColor = Color.White
                                )
                            ) {
                                Text(
                                    text = if (activeVisitRetailer != null) "Continue Active Visit" else "Open Shop",
                                    fontWeight = FontWeight.SemiBold,
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
                                color = RFColors.TextPrimary
                            )
                            Text(
                                text = if (state.retailers.isNotEmpty()) "Great job! All beat visits are complete." else "Contact Admin to assign your beat route.",
                                style = MaterialTheme.typography.bodySmall,
                                color = RFColors.TextSecondary
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
                        color = RFColors.TextPrimary
                    )
                    if (onSyncAgain != null) {
                        TextButton(
                            onClick = onSyncAgain,
                            contentPadding = PaddingValues(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(14.dp), tint = RFColors.Primary)
                            Spacer(Modifier.width(4.dp))
                            Text("Sync", style = MaterialTheme.typography.labelSmall, color = RFColors.Primary, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }

            if (state.retailers.isEmpty() && state.isLoading) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().height(100.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = RFColors.Primary)
                    }
                }
            } else if (state.retailers.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(1.dp, RFColors.Border)
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
                                tint = RFColors.TextSecondary,
                                modifier = Modifier.size(36.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "No shops in this beat",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                            Text(
                                text = "Ask your Owner or Admin to assign shops.",
                                style = MaterialTheme.typography.bodySmall,
                                color = RFColors.TextSecondary
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
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(
                            1.dp,
                            when {
                                isCurrentActive -> RFColors.Primary
                                isCompleted -> RFColors.Success.copy(alpha = 0.4f)
                                else -> RFColors.Border
                            }
                        ),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
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
                                                isCurrentActive -> RFColors.InfoLight
                                                isCompleted -> RFColors.SuccessLight
                                                else -> RFColors.NeutralLight
                                            }
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    when {
                                        isCurrentActive -> Icon(Icons.Default.Schedule, contentDescription = null, tint = RFColors.Primary, modifier = Modifier.size(18.dp))
                                        isCompleted -> Icon(Icons.Default.Check, contentDescription = null, tint = RFColors.Success, modifier = Modifier.size(18.dp))
                                        else -> Icon(Icons.Default.Store, contentDescription = null, tint = RFColors.TextSecondary, modifier = Modifier.size(18.dp))
                                    }
                                }

                                Column {
                                    Text(
                                        text = retailer.name,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = FontWeight.SemiBold,
                                        color = RFColors.TextPrimary
                                    )
                                    if (retailer.address.isNotBlank()) {
                                        Text(
                                            text = retailer.address,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = RFColors.TextSecondary,
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
                                        color = RFColors.Danger
                                    )
                                }
                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = when {
                                        isCurrentActive -> RFColors.InfoLight
                                        isCompleted -> RFColors.SuccessLight
                                        else -> RFColors.NeutralLight
                                    }
                                ) {
                                    Text(
                                        text = when {
                                            isCurrentActive -> "Active"
                                            isCompleted -> "Visited"
                                            else -> "Pending"
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = when {
                                            isCurrentActive -> RFColors.Primary
                                            isCompleted -> RFColors.Success
                                            else -> RFColors.TextSecondary
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
            title = { Text("Active Visit in Progress", fontWeight = FontWeight.Bold, color = RFColors.TextPrimary) },
            text = {
                Text("You already have an active visit at '$activeName'. Please check out from that visit before starting a new one.", color = RFColors.TextSecondary)
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
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Go to Active Visit", color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { blockedVisitRetailerName = null }) {
                    Text("Cancel", color = RFColors.TextSecondary)
                }
            }
        )
    }
}
