package com.routeflow.app.feature.sales

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PointOfSale
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.LogisticsMarker
import com.routeflow.app.core.design.map.LogisticsMarkerStatus
import com.routeflow.app.core.design.map.LogisticsMarkerType
import com.routeflow.app.core.design.map.MapContextualSheet
import com.routeflow.app.core.design.map.RouteFlowMap
import com.routeflow.app.domain.model.Employee

/**
 * Map-First Salesperson Home & Beat Dashboard.
 * 75% interactive logistics map with real GPS plotted markers.
 * Selecting a marker reveals contextual shop details, udhaar balance,
 * and high-speed actions ("Van Spot Sale" and "Check In / Visit").
 */
@Composable
fun SalesHomeScreen(
    employee: Employee,
    state: SalesHomeState,
    onStartVisits: () -> Unit,
    onStartShift: () -> Unit = {},
    onEndShift: () -> Unit = {},
    onContinueRoute: (nextRetailerId: String?) -> Unit = { onStartVisits() },
    onSyncNow: () -> Unit = {},
    onStartVanSale: () -> Unit = {},
    onStartVanSaleForRetailer: (retailerId: String) -> Unit = { onStartVanSale() }
) {
    val firstName = employee.name.split(" ").firstOrNull() ?: employee.name
    var showEndShiftConfirm by remember { mutableStateOf(false) }
    var isMapView by remember { mutableStateOf(true) }
    var selectedRetailerId by remember { mutableStateOf<String?>(null) }

    // Convert retailers to unified logistics markers
    val markers = remember(state.allRetailers, state.visitedRetailerIds) {
        state.allRetailers.map { retailer ->
            val isVisited = state.visitedRetailerIds.contains(retailer.id)
            val status = when {
                isVisited -> LogisticsMarkerStatus.VISITED
                retailer.outstandingAmountPaise > 0 -> LogisticsMarkerStatus.ALERT
                else -> LogisticsMarkerStatus.UNVISITED
            }
            LogisticsMarker(
                id = retailer.id,
                title = retailer.name,
                subtitle = retailer.beatId.takeIf { it.isNotBlank() } ?: "Assigned Beat",
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
        // 1. Compact Top Bar (Greeting, Beat, Duty Status, Sync)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
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
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFEFF6FF)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.AccountCircle,
                            contentDescription = null,
                            tint = RFColors.Primary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = "Hi $firstName",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = state.beatName,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B),
                            fontSize = 11.sp
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    if (state.isOfflineCache && state.totalShops > 0) {
                        Surface(
                            color = Color(0xFFFEF3C7),
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, Color(0xFFFDE68A))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CloudOff,
                                    contentDescription = null,
                                    tint = Color(0xFFB45309),
                                    modifier = Modifier.size(10.dp)
                                )
                                Spacer(Modifier.width(3.dp))
                                Text(
                                    text = "Offline",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFB45309)
                                )
                            }
                        }
                    }

                    // Duty status badge
                    Surface(
                        shape = RoundedCornerShape(16.dp),
                        color = if (state.isOnShift) Color(0xFFDCFCE7) else Color(0xFFF1F5F9),
                        border = BorderStroke(1.dp, if (state.isOnShift) Color(0xFF86EFAC) else Color(0xFFE2E8F0))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(7.dp)
                                    .clip(CircleShape)
                                    .background(if (state.isOnShift) Color(0xFF16A34A) else Color(0xFF94A3B8))
                            )
                            Spacer(modifier = Modifier.width(5.dp))
                            Text(
                                text = if (state.isOnShift) "On Duty" else "Off Duty",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = if (state.isOnShift) Color(0xFF15803D) else Color(0xFF64748B)
                            )
                        }
                    }
                }
            }
        }

        if (isMapView) {
            // ==========================================
            // MAP-FIRST MODE (~75% SCREEN SPACE)
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

                // Docked Bottom Card / Contextual Information Sheet
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                ) {
                    if (selectedMarker != null) {
                        // Marker selected: Reveal shop specifics, credit and direct actions
                        MapContextualSheet(
                            marker = selectedMarker,
                            onDismiss = { selectedRetailerId = null },
                            primaryActionLabel = stringResource(R.string.van_spot_sale_action),
                            primaryActionIcon = Icons.Default.PointOfSale,
                            onPrimaryAction = {
                                onStartVanSaleForRetailer(selectedMarker.retailerId ?: selectedMarker.id)
                            },
                            secondaryActionLabel = stringResource(R.string.check_in_visit),
                            secondaryActionIcon = Icons.Default.Store,
                            onSecondaryAction = {
                                onContinueRoute(selectedMarker.retailerId ?: selectedMarker.id)
                            }
                        )
                    } else {
                        // No marker selected: Docked Route Summary & Primary Action Card
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            shape = RoundedCornerShape(20.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                            elevation = CardDefaults.cardElevation(defaultElevation = 5.dp)
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(14.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                // Metric row: Visited / Remaining / Orders
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Text(
                                            text = "${state.shopsVisited} / ${state.totalShops} Shops Visited",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp,
                                            color = RFColors.TextPrimary
                                        )
                                    }

                                    Surface(
                                        color = Color(0xFFEFF6FF),
                                        shape = RoundedCornerShape(8.dp)
                                    ) {
                                        Text(
                                            text = "Orders: ${CurrencyFormatter.formatPaise(state.todayOrderValuePaise)}",
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = RFColors.Primary,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                        )
                                    }
                                }

                                // Primary Flow Buttons
                                if (!state.isOnShift) {
                                    Button(
                                        onClick = onStartShift,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(46.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.PlayArrow,
                                            contentDescription = null,
                                            modifier = Modifier.size(20.dp)
                                        )
                                        Spacer(Modifier.width(8.dp))
                                        Text(
                                            text = "Start Route / Duty",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 14.sp
                                        )
                                    }
                                } else {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        // Continue visits
                                        Button(
                                            onClick = { onContinueRoute(state.nextShop?.id) },
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(46.dp),
                                            shape = RoundedCornerShape(12.dp),
                                            colors = ButtonDefaults.buttonColors(containerColor = RFColors.Success)
                                        ) {
                                            Text(
                                                text = if (state.nextShop != null) "Next Shop" else "Continue Beat",
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 13.sp
                                            )
                                            Spacer(Modifier.width(6.dp))
                                            Icon(
                                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }

                                        // Van Spot Sale button
                                        Button(
                                            onClick = onStartVanSale,
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(46.dp),
                                            shape = RoundedCornerShape(12.dp),
                                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706))
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.PointOfSale,
                                                contentDescription = null,
                                                modifier = Modifier.size(16.dp)
                                            )
                                            Spacer(Modifier.width(6.dp))
                                            Text(
                                                text = "Van Sale",
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 13.sp
                                            )
                                        }

                                        // End shift icon button
                                        IconButton(
                                            onClick = { showEndShiftConfirm = true },
                                            modifier = Modifier
                                                .size(46.dp)
                                                .clip(RoundedCornerShape(12.dp))
                                                .background(RFColors.DangerLight)
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Stop,
                                                contentDescription = "End Duty",
                                                tint = RFColors.Danger,
                                                modifier = Modifier.size(22.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // ==========================================
            // LIST VIEW MODE (Full Scrollable Dashboard)
            // ==========================================
            val scrollState = rememberScrollState()

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Top switcher bar to jump back to map
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
                            text = "List View Active",
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            color = RFColors.TextPrimary
                        )
                        TextButton(onClick = { isMapView = true }) {
                            Icon(Icons.Default.Route, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Switch to Map", fontWeight = FontWeight.Bold)
                        }
                    }
                }

                // Primary Action Button (Field duty CTA)
                if (!state.isOnShift) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Button(
                            onClick = onStartShift,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary),
                            elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = null,
                                modifier = Modifier.size(22.dp),
                                tint = Color.White
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Start Route / Duty",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        }
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = { onContinueRoute(state.nextShop?.id) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp),
                            shape = RoundedCornerShape(14.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = RFColors.Success),
                            elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                        ) {
                            Text(
                                text = "Continue Route",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = Color.White
                            )
                        }

                        // Stop Route / End Duty Button
                        OutlinedButton(
                            onClick = { showEndShiftConfirm = true },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(46.dp),
                            shape = RoundedCornerShape(12.dp),
                            border = BorderStroke(1.dp, RFColors.Danger.copy(alpha = 0.35f)),
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = RFColors.DangerLight,
                                contentColor = RFColors.Danger
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Default.Stop,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = RFColors.Danger
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Stop Route / End Duty",
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Danger
                            )
                        }
                    }
                }

                // Van Spot Sale Button in List View
                Button(
                    onClick = onStartVanSale,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706))
                ) {
                    Icon(
                        imageVector = Icons.Default.PointOfSale,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Van Spot Sale (Vehicle Stock)",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }

                // Today Route Summary Tiles
                Text(
                    text = "Today's Route Summary",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    SummaryTile(
                        modifier = Modifier.weight(1f),
                        title = "Shops Assigned",
                        value = "${state.totalShops}",
                        subtext = "In your beat",
                        icon = Icons.Default.Store,
                        accentColor = Color(0xFF2563EB)
                    )
                    SummaryTile(
                        modifier = Modifier.weight(1f),
                        title = "Shops Visited",
                        value = "${state.shopsVisited}",
                        subtext = "${state.remainingShops} pending",
                        icon = Icons.Default.CheckCircle,
                        accentColor = Color(0xFF16A34A)
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    SummaryTile(
                        modifier = Modifier.weight(1f),
                        title = "Booked Today",
                        value = CurrencyFormatter.formatPaise(state.todayOrderValuePaise),
                        subtext = "${state.todayOrdersCount} orders",
                        icon = Icons.Default.ShoppingCart,
                        accentColor = Color(0xFF9333EA)
                    )
                    SummaryTile(
                        modifier = Modifier.weight(1f),
                        title = "Pending Udhaar",
                        value = CurrencyFormatter.formatPaise(state.pendingCollectionPaise),
                        subtext = "To collect",
                        icon = Icons.Default.Payments,
                        accentColor = Color(0xFFDC2626)
                    )
                }

                // View all assigned shops CTA
                OutlinedButton(
                    onClick = onStartVisits,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, Color(0xFF2563EB))
                ) {
                    Icon(
                        imageVector = Icons.Default.Store,
                        contentDescription = null,
                        tint = Color(0xFF2563EB),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "View All Assigned Shops (${state.totalShops})",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF2563EB)
                    )
                }

                Spacer(Modifier.height(16.dp))
            }
        }
    }

    if (showEndShiftConfirm) {
        AlertDialog(
            onDismissRequest = { showEndShiftConfirm = false },
            title = {
                Text(
                    text = "Stop Route & End Duty?",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
            },
            text = {
                Text(
                    text = "Are you sure you want to end your daily shift? This will mark you as off-duty and save today's route progress.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = RFColors.TextSecondary
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showEndShiftConfirm = false
                        onEndShift()
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Danger,
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("End Duty", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showEndShiftConfirm = false }) {
                    Text("Cancel", color = RFColors.TextSecondary)
                }
            }
        )
    }
}

@Composable
private fun SummaryTile(
    modifier: Modifier = Modifier,
    title: String,
    value: String,
    subtext: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    accentColor: Color
) {
    Surface(
        modifier = modifier,
        color = Color.White,
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        shadowElevation = 1.dp
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF64748B),
                    fontWeight = FontWeight.Medium
                )
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(18.dp)
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = RFColors.TextPrimary,
                maxLines = 1,
                softWrap = false
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = subtext,
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF64748B),
                fontSize = 11.sp,
                maxLines = 1,
                softWrap = false
            )
        }
    }
}
