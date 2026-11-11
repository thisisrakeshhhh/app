package com.routeflow.app.feature.sales

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.LogisticsMarker
import com.routeflow.app.core.design.map.LogisticsMarkerStatus
import com.routeflow.app.core.design.map.LogisticsMarkerType
import com.routeflow.app.core.design.map.RouteFlowMap
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.StopStatus

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesRouteScreen(
    state: SalesRouteState,
    onSelectStop: (PlannedRouteStop) -> Unit,
    onMarkVisited: (String, String?) -> Unit,
    onMarkSkipped: (String, String?) -> Unit,
    onBookOrder: (String) -> Unit,
    onNavigateBack: () -> Unit,
    onClearMessages: () -> Unit
) {
    var isMapView by remember { mutableStateOf(false) }
    var stopForVisitDialog by remember { mutableStateOf<PlannedRouteStop?>(null) }
    var stopForSkipDialog by remember { mutableStateOf<PlannedRouteStop?>(null) }
    var visitNotes by remember { mutableStateOf("") }
    var skipReason by remember { mutableStateOf("") }

    val snackbarHostState = remember { SnackbarHostState() }

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

    // Convert stops to LogisticsMarker for RouteFlowMap
    val markers = remember(state.stops) {
        state.stops.map { stop ->
            val status = when (stop.status) {
                StopStatus.VISITED -> LogisticsMarkerStatus.COMPLETED
                StopStatus.SKIPPED -> LogisticsMarkerStatus.ALERT
                StopStatus.PENDING -> LogisticsMarkerStatus.PENDING
            }
            LogisticsMarker(
                id = stop.id,
                title = stop.retailerName,
                subtitle = "Stop #${stop.stopSequence}",
                latitude = stop.latitude,
                longitude = stop.longitude,
                type = LogisticsMarkerType.RETAILER,
                status = status,
                sequenceNumber = stop.stopSequence,
                address = stop.address,
                contactPhone = stop.contactNumber,
                retailerId = stop.retailerId
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Today's Field Route", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            text = state.todayRoute?.name ?: "No route assigned",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { isMapView = !isMapView }) {
                        Icon(
                            imageVector = if (isMapView) Icons.Default.Route else Icons.Default.Map,
                            contentDescription = "Toggle View",
                            tint = if (isMapView) RFColors.Primary else MaterialTheme.colorScheme.onSurface
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (state.isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (state.todayRoute == null) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.Route,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = Color.LightGray
                        )
                        Spacer(Modifier.height(16.dp))
                        Text(
                            "No route assigned for today",
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Your distributor manager will publish your daily stop sequence and road map.",
                            fontSize = 13.sp,
                            color = Color.Gray
                        )
                    }
                }
            } else {
                val route = state.todayRoute
                val visitedCount = state.stops.count { it.status == StopStatus.VISITED }
                val skippedCount = state.stops.count { it.status == StopStatus.SKIPPED }
                val pendingCount = state.stops.count { it.status == StopStatus.PENDING }

                // Metrics Header Banner
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceAround,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("PROGRESS", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                            Text("$visitedCount / ${state.stops.size}", fontWeight = FontWeight.Black, fontSize = 16.sp, color = RFColors.Primary)
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            val isFallback = route.routingProvider == "HAVERSINE_FALLBACK" || route.routingProvider == "FALLBACK"
                            Text(
                                if (isFallback) "STRAIGHT-LINE (FALLBACK)" else "ROAD DISTANCE",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isFallback) Color(0xFFD97706) else Color.Gray
                            )
                            Text(OsrmRoutingHelper.formatDistance(route.roadDistanceMeters), fontWeight = FontWeight.Black, fontSize = 16.sp)
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("EST. DURATION", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                            Text(OsrmRoutingHelper.formatDuration(route.roadDurationSeconds), fontWeight = FontWeight.Black, fontSize = 16.sp)
                        }
                    }
                }

                if (isMapView) {
                    Box(modifier = Modifier.weight(1f)) {
                        RouteFlowMap(
                            markers = markers,
                            selectedMarkerId = state.selectedStop?.id,
                            onMarkerSelected = { marker ->
                                val stop = state.stops.find { it.id == marker.id }
                                if (stop != null) onSelectStop(stop)
                            },
                            onDismissSelection = {},
                            isMapView = true,
                            onToggleView = { isMapView = it },
                            modifier = Modifier.fillMaxSize(),
                            routeCoordinates = state.routeCoordinates
                        )
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(state.stops) { stop ->
                            SalesStopCard(
                                stop = stop,
                                isSelected = stop.id == state.selectedStop?.id,
                                onSelect = { onSelectStop(stop) },
                                onBookOrder = { onBookOrder(stop.retailerId) },
                                onMarkVisited = { stopForVisitDialog = stop },
                                onMarkSkipped = { stopForSkipDialog = stop }
                            )
                        }
                    }
                }
            }
        }
    }

    // Mark Visited Dialog
    if (stopForVisitDialog != null) {
        AlertDialog(
            onDismissRequest = { stopForVisitDialog = null },
            title = { Text("Mark Shop Visited?", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Retailer: ${stopForVisitDialog?.retailerName}")
                    OutlinedTextField(
                        value = visitNotes,
                        onValueChange = { visitNotes = it },
                        label = { Text("Visit notes / feedback (optional)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val s = stopForVisitDialog
                        if (s != null) {
                            onMarkVisited(s.id, visitNotes.ifBlank { null })
                        }
                        stopForVisitDialog = null
                        visitNotes = ""
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF16A34A))
                ) {
                    Text("Confirm Visited", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { stopForVisitDialog = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Mark Skipped Dialog
    if (stopForSkipDialog != null) {
        AlertDialog(
            onDismissRequest = { stopForSkipDialog = null },
            title = { Text("Mark Shop Skipped?", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Retailer: ${stopForSkipDialog?.retailerName}")
                    OutlinedTextField(
                        value = skipReason,
                        onValueChange = { skipReason = it },
                        label = { Text("Reason for skipping (e.g. Shop closed)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val s = stopForSkipDialog
                        if (s != null) {
                            onMarkSkipped(s.id, skipReason.ifBlank { "Shop closed" })
                        }
                        stopForSkipDialog = null
                        skipReason = ""
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706))
                ) {
                    Text("Confirm Skipped", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { stopForSkipDialog = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SalesStopCard(
    stop: PlannedRouteStop,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onBookOrder: () -> Unit,
    onMarkVisited: () -> Unit,
    onMarkSkipped: () -> Unit
) {
    val (statusColor, statusText) = when (stop.status) {
        StopStatus.VISITED -> Pair(Color(0xFF16A34A), "VISITED")
        StopStatus.SKIPPED -> Pair(Color(0xFFD97706), "SKIPPED")
        StopStatus.PENDING -> Pair(RFColors.Primary, "PENDING")
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f) else MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Sequence badge
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(statusColor),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "#${stop.stopSequence}",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }

                Spacer(Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(stop.retailerName, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Text(stop.address, fontSize = 12.sp, color = Color.Gray, maxLines = 1)
                    if (stop.contactNumber.isNotBlank()) {
                        Text("Phone: ${stop.contactNumber}", fontSize = 11.sp, color = Color.DarkGray)
                    }
                }

                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = statusColor.copy(alpha = 0.12f)
                ) {
                    Text(
                        text = statusText,
                        color = statusColor,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            if (stop.notes != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "Notes: ${stop.notes}",
                    fontSize = 12.sp,
                    color = Color.DarkGray,
                    fontStyle = androidx.compose.ui.text.font.FontStyle.Italic
                )
            }

            Spacer(Modifier.height(10.dp))

            // Action Buttons: "Book Order", "Visited", "Skipped"
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = onBookOrder,
                    modifier = Modifier.weight(1.3f),
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.ShoppingCart, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Take Order", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }

                if (stop.status == StopStatus.PENDING) {
                    OutlinedButton(
                        onClick = onMarkVisited,
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)
                    ) {
                        Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFF16A34A))
                        Spacer(Modifier.width(2.dp))
                        Text("Visited", fontSize = 12.sp, color = Color(0xFF16A34A))
                    }

                    OutlinedButton(
                        onClick = onMarkSkipped,
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFD97706))
                        Spacer(Modifier.width(2.dp))
                        Text("Skip", fontSize = 12.sp, color = Color(0xFFD97706))
                    }
                }
            }
        }
    }
}
