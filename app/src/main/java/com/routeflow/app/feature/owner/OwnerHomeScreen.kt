package com.routeflow.app.feature.owner

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
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.LogisticsMarker
import com.routeflow.app.core.design.map.LogisticsMarkerStatus
import com.routeflow.app.core.design.map.LogisticsMarkerType
import com.routeflow.app.core.design.map.MapContextualSheet
import com.routeflow.app.core.design.map.RouteFlowMap
import com.routeflow.app.domain.model.Employee
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Map-First Distributor & Owner Overview.
 * Provides a high-altitude territorial distribution map of retailer network and vehicle status,
 * paired with rapid executive KPI controls and pending approval queues.
 */
@Composable
fun OwnerHomeScreen(
    employee: Employee,
    state: OwnerHomeState,
    onViewApprovals: () -> Unit,
    onViewProducts: () -> Unit = {},
    onViewRetailers: () -> Unit = {},
    onViewEmployees: () -> Unit = {},
    onViewHandovers: () -> Unit = {},
    onViewCollections: () -> Unit = {},
    onViewReturns: () -> Unit = {},
    onViewTeam: () -> Unit = {},
    onViewReports: () -> Unit = {},
    onRefresh: () -> Unit = {}
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        var isMapView by remember { mutableStateOf(true) }
        var selectedRetailerId by remember { mutableStateOf<String?>(null) }

        val formattedDate = remember {
            SimpleDateFormat("EEEE, d MMMM", Locale.getDefault()).format(Date())
        }

        // Map retailers into territorial LogisticsMarkers
        val markers = remember(state.retailers) {
            state.retailers.map { retailer ->
                val status = when {
                    retailer.outstandingAmountPaise > retailer.creditLimitPaise && retailer.creditLimitPaise > 0 ->
                        LogisticsMarkerStatus.ALERT
                    retailer.outstandingAmountPaise > 0 ->
                        LogisticsMarkerStatus.PENDING
                    else ->
                        LogisticsMarkerStatus.COMPLETED
                }
                LogisticsMarker(
                    id = retailer.id,
                    title = retailer.name,
                    subtitle = retailer.beatId.takeIf { it.isNotBlank() } ?: "Territory Shop",
                    latitude = retailer.latitude,
                    longitude = retailer.longitude,
                    type = LogisticsMarkerType.RETAILER,
                    status = status,
                    balancePaise = retailer.outstandingAmountPaise,
                    creditLimitPaise = retailer.creditLimitPaise,
                    address = retailer.address,
                    contactPhone = retailer.contactNumber,
                    retailerId = retailer.id
                )
            }
        }

        val selectedMarker = remember(selectedRetailerId, markers) {
            markers.find { it.id == selectedRetailerId }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background)
        ) {
            // 1. Executive Top Bar
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Good morning, ${employee.name} Ji",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = "$formattedDate • ${state.staffOnDutyCount} Staff on Duty",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary,
                            fontSize = 11.sp
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        if (state.pendingApprovalsCount > 0) {
                            Surface(
                                color = Color(0xFFFEF2F2),
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, Color(0xFFFECACA)),
                                modifier = Modifier.clickable { onViewApprovals() }
                            ) {
                                Text(
                                    text = "${state.pendingApprovalsCount} Approvals",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFDC2626),
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }

                        IconButton(onClick = onRefresh, modifier = Modifier.size(36.dp)) {
                            Icon(
                                Icons.Default.Refresh,
                                contentDescription = "Refresh",
                                tint = RFColors.Primary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }

            if (isMapView) {
                // ==========================================
                // TERRITORY MAP-FIRST VIEW (~75% SCREEN SPACE)
                // ==========================================
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {
                    RouteFlowMap(
                        markers = markers,
                        selectedMarkerId = selectedRetailerId,
                        onMarkerSelected = { marker ->
                            selectedRetailerId = marker.id
                        },
                        onDismissSelection = {
                            selectedRetailerId = null
                        },
                        isMapView = true,
                        onToggleView = { isMapView = it },
                        enablePolylines = false,
                        modifier = Modifier.fillMaxSize()
                    )

                    // Docked Bottom Sheet / Action Deck
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .align(Alignment.BottomCenter)
                    ) {
                        if (selectedMarker != null) {
                            MapContextualSheet(
                                marker = selectedMarker,
                                onDismiss = { selectedRetailerId = null },
                                primaryActionLabel = stringResource(R.string.owner_tab_retailers),
                                primaryActionIcon = Icons.Default.Store,
                                onPrimaryAction = onViewRetailers,
                                secondaryActionLabel = if (state.pendingApprovalsCount > 0) "Approvals" else null,
                                secondaryActionIcon = Icons.Default.PendingActions,
                                onSecondaryAction = if (state.pendingApprovalsCount > 0) onViewApprovals else null
                            )
                        } else {
                            // Docked Executive Pulse Bar
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                shape = RoundedCornerShape(20.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White),
                                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                                elevation = CardDefaults.cardElevation(defaultElevation = 5.dp)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(14.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(
                                            text = "Territory Udhaar",
                                            fontSize = 11.sp,
                                            color = Color(0xFF64748B),
                                            fontWeight = FontWeight.Medium
                                        )
                                        Text(
                                            text = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFFDC2626)
                                        )
                                    }

                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            text = "Delivered Today",
                                            fontSize = 11.sp,
                                            color = Color(0xFF64748B),
                                            fontWeight = FontWeight.Medium
                                        )
                                        Text(
                                            text = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFF16A34A)
                                        )
                                    }

                                    Button(
                                        onClick = onViewApprovals,
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = if (state.pendingApprovalsCount > 0) Color(0xFFDC2626) else RFColors.Primary
                                        ),
                                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                                    ) {
                                        Text(
                                            text = if (state.pendingApprovalsCount > 0) "${state.pendingApprovalsCount} Review" else "Approvals",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // ==========================================
                // KPI DASHBOARD VIEW (Full Scrollable Overview)
                // ==========================================
                val scrollState = rememberScrollState()

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState)
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Switcher back to map
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "KPI Dashboard View Active",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = RFColors.TextPrimary
                            )
                            TextButton(onClick = { isMapView = true }) {
                                Icon(Icons.Default.Store, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(4.dp))
                                Text("Switch to Map", fontWeight = FontWeight.Bold)
                            }
                        }
                    }

                    // Primary Decision Panel: Orders Requiring Approval
                    val pendingCount = state.pendingApprovalsCount
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(onClick = onViewApprovals)
                            .testTag("primary_action_approvals"),
                        shape = RoundedCornerShape(16.dp),
                        color = if (pendingCount > 0) RFColors.InfoSurface else Color.White,
                        border = BorderStroke(
                            1.dp,
                            if (pendingCount > 0) Color(0xFFBFDBFE) else RFColors.Border
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(18.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                modifier = Modifier.weight(1f),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(14.dp)
                            ) {
                                Surface(
                                    shape = CircleShape,
                                    color = if (pendingCount > 0) Color(0xFFDBEAFE) else Color(0xFFF1F5F9),
                                    modifier = Modifier.size(44.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            Icons.Default.PendingActions,
                                            contentDescription = null,
                                            tint = if (pendingCount > 0) RFColors.Primary else RFColors.TextSecondary,
                                            modifier = Modifier.size(22.dp)
                                        )
                                    }
                                }

                                Column {
                                    Text(
                                        text = if (pendingCount > 0) {
                                            "$pendingCount ${if (pendingCount == 1) "order needs" else "orders need"} approval"
                                        } else {
                                            "All orders approved"
                                        },
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        color = RFColors.TextPrimary
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = if (pendingCount > 0) {
                                            "Review wholesale credit & inventory checks"
                                        } else {
                                            "Approval queue is clear"
                                        },
                                        style = MaterialTheme.typography.bodySmall,
                                        color = if (pendingCount > 0) RFColors.Primary else RFColors.TextSecondary
                                    )
                                }
                            }

                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = if (pendingCount > 0) RFColors.Primary else Color(0xFFF1F5F9)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Review",
                                        style = MaterialTheme.typography.labelMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = if (pendingCount > 0) Color.White else RFColors.TextSecondary
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(
                                        Icons.AutoMirrored.Filled.ArrowForward,
                                        contentDescription = null,
                                        tint = if (pendingCount > 0) Color.White else RFColors.TextSecondary,
                                        modifier = Modifier.size(14.dp)
                                    )
                                }
                            }
                        }
                    }

                    // Business Pulse Metrics Surface
                    Text(
                        text = "Business Pulse",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.TextPrimary
                    )

                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, RFColors.Border)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 16.dp, horizontal = 12.dp),
                            horizontalArrangement = Arrangement.SpaceEvenly,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(
                                modifier = Modifier.weight(1f),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Text(
                                    text = "Sales Today",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = RFColors.TextSecondary
                                )
                            }

                            VerticalDivider(modifier = Modifier.height(36.dp), color = RFColors.Border)

                            Column(
                                modifier = Modifier.weight(1f),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = CurrencyFormatter.formatPaise(state.cashCollectedTodayPaise),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.Success
                                )
                                Text(
                                    text = "Cash In",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = RFColors.TextSecondary
                                )
                            }

                            VerticalDivider(modifier = Modifier.height(36.dp), color = RFColors.Border)

                            Column(
                                modifier = Modifier.weight(1f),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.Danger
                                )
                                Text(
                                    text = "Pending Udhaar",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = RFColors.TextSecondary
                                )
                            }
                        }
                    }

                    // Attention Required Section
                    Text(
                        text = "Attention Required",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.TextPrimary
                    )

                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = Color.White,
                        border = BorderStroke(1.dp, RFColors.Border)
                    ) {
                        Column {
                            AttentionRow(
                                icon = Icons.Default.Inventory2,
                                iconTint = if (state.lowStockCount > 0) RFColors.Warning else RFColors.Success,
                                iconBg = if (state.lowStockCount > 0) RFColors.WarningSurface else RFColors.SuccessSurface,
                                title = "Low Stock Alerts",
                                subtitle = if (state.lowStockCount > 0) "${state.lowStockCount} items below threshold" else "All items sufficiently stocked",
                                statusText = if (state.lowStockCount > 0) "${state.lowStockCount} items" else "Healthy",
                                onClick = onViewProducts
                            )
                            HorizontalDivider(color = RFColors.Border)
                            AttentionRow(
                                icon = Icons.Default.LocalShipping,
                                iconTint = if (state.failedDeliveriesCount > 0) RFColors.Danger else RFColors.Success,
                                iconBg = if (state.failedDeliveriesCount > 0) RFColors.DangerSurface else RFColors.SuccessSurface,
                                title = "Delivery Issues",
                                subtitle = if (state.failedDeliveriesCount > 0) "${state.failedDeliveriesCount} deliveries failed or partial" else "No delivery failures reported",
                                statusText = if (state.failedDeliveriesCount > 0) "${state.failedDeliveriesCount} issues" else "Clear",
                                onClick = onViewReturns
                            )
                            HorizontalDivider(color = RFColors.Border)
                            AttentionRow(
                                icon = Icons.Default.AccountBalanceWallet,
                                iconTint = if (state.pendingHandoverCount > 0) RFColors.Primary else RFColors.Success,
                                iconBg = if (state.pendingHandoverCount > 0) RFColors.InfoSurface else RFColors.SuccessSurface,
                                title = "Cash Handovers Due",
                                subtitle = if (state.pendingHandoverCount > 0) "${CurrencyFormatter.formatPaise(state.pendingHandoverAmountPaise)} awaiting collection" else "All driver cash handed over",
                                statusText = if (state.pendingHandoverCount > 0) "${state.pendingHandoverCount} pending" else "Clear",
                                onClick = onViewHandovers
                            )
                        }
                    }

                    Spacer(Modifier.height(16.dp))
                }
            }
        }
    }
}

@Composable
private fun AttentionRow(
    icon: ImageVector,
    iconTint: Color,
    iconBg: Color,
    title: String,
    subtitle: String,
    statusText: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Surface(
                shape = CircleShape,
                color = iconBg,
                modifier = Modifier.size(36.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = statusText,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = iconTint
            )
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = RFColors.TextSecondary,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
