package com.routeflow.app.feature.sales

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.sales_today_shops), fontWeight = FontWeight.Bold) }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
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
                            text = "Assigned Shops (${state.retailers.size})",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${state.completedVisitRetailerIds.size} / ${state.retailers.size} Visited",
                            style = MaterialTheme.typography.labelMedium,
                            color = RFColors.Accent
                        )
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
                        Text(
                            text = "No shops assigned to your beat.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = RFColors.TextSecondary
                        )
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
                                    // Single active visit constraint: alert user
                                    blockedVisitRetailerName = activeVisitRetailer?.name ?: "an active shop"
                                } else {
                                    onRetailerClick(retailer.id)
                                }
                            }
                        )
                    }
                }
            }
        }
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
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Text("Go to Active Visit")
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

@Composable
private fun ShiftControlCard(
    isOnShift: Boolean,
    onStartShift: () -> Unit,
    onEndShift: () -> Unit,
    isLoading: Boolean
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (isOnShift) Color(0xFFF0FDF4) else Color(0xFFF8FAFC)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(if (isOnShift) RFColors.Success else Color.Gray)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (isOnShift) stringResource(R.string.on_shift) else stringResource(R.string.off_shift),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = if (isOnShift) RFColors.Success else RFColors.TextPrimary
                    )
                }

                if (isOnShift) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = RFColors.Success,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "GPS Active",
                            style = MaterialTheme.typography.labelSmall,
                            color = RFColors.Success,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            if (isOnShift) {
                OutlinedButton(
                    onClick = onEndShift,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading,
                    colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(
                        contentColor = RFColors.Error
                    )
                ) {
                    Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.end_shift), fontWeight = FontWeight.Bold)
                }
            } else {
                Button(
                    onClick = onStartShift,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading,
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.start_shift), fontWeight = FontWeight.Bold)
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
        colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
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
                    text = "Active Visit In Progress",
                    style = MaterialTheme.typography.labelSmall,
                    color = RFColors.Accent,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = retailer.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = "Tap to view order or check out",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null, tint = RFColors.Accent)
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
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Status icon circle
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
                        isCurrentActive -> Icon(Icons.Default.Schedule, contentDescription = null, tint = RFColors.Accent, modifier = Modifier.size(20.dp))
                        isCompleted -> Icon(Icons.Default.Check, contentDescription = null, tint = RFColors.Success, modifier = Modifier.size(20.dp))
                        else -> Icon(Icons.Default.Store, contentDescription = null, tint = RFColors.TextSecondary, modifier = Modifier.size(20.dp))
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
                        text = "${retailer.address} · ₹${"%,d".format(retailer.outstandingAmountPaise / 100)} Due",
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }
            }

            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = when {
                        isCurrentActive -> "In Progress"
                        isCompleted -> "Visited"
                        else -> "Pending"
                    },
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = when {
                        isCurrentActive -> RFColors.Accent
                        isCompleted -> RFColors.Success
                        else -> Color.Gray
                    }
                )
            }
        }
    }
}
