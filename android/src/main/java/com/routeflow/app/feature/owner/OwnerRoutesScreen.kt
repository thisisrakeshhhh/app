package com.routeflow.app.feature.owner

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudQueue
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Publish
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.model.StopStatus
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerRoutesScreen(
    state: OwnerRoutesState,
    onDateSelected: (String) -> Unit,
    onPublishRoute: (String) -> Unit,
    onCancelRoute: (String, String) -> Unit,
    onSelectRouteForInspection: (PlannedRoute?) -> Unit = {},
    onRefreshRoute: (String) -> Unit = {},
    onNavigatePlanner: () -> Unit,
    onNavigateBack: () -> Unit,
    onClearMessages: () -> Unit
) {
    val snackbarHostState = remember { SnackbarHostState() }
    var routeToCancel by remember { mutableStateOf<PlannedRoute?>(null) }
    var cancelReason by remember { mutableStateOf("") }

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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Daily Routes", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNavigatePlanner,
                containerColor = RFColors.Primary,
                contentColor = Color.White
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Add, contentDescription = "New Route")
                    Spacer(Modifier.width(8.dp))
                    Text("New Route", fontWeight = FontWeight.Bold)
                }
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Date Filter Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Routes for ${state.selectedDate}",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )
                Text(
                    text = "${state.routes.size} Routes",
                    color = Color.Gray,
                    fontSize = 13.sp
                )
            }

            if (state.isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = RFColors.Primary)
                }
            } else if (state.routes.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.Map,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = Color.LightGray
                        )
                        Spacer(Modifier.height(16.dp))
                        Text(
                            "No routes planned for ${state.selectedDate}",
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Tap '+ New Route' to pick stops on the map and assign a salesperson",
                            fontSize = 13.sp,
                            color = Color.Gray
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(state.routes) { route ->
                        PlannedRouteCard(
                            route = route,
                            onSelect = { onSelectRouteForInspection(route) },
                            onPublish = { onPublishRoute(route.id) },
                            onCancel = { routeToCancel = route }
                        )
                    }
                }
            }
        }
    }

    // Cancellation Dialog
    if (routeToCancel != null) {
        AlertDialog(
            onDismissRequest = { routeToCancel = null },
            title = { Text("Cancel Route?", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Are you sure you want to cancel \"${routeToCancel?.name}\"?")
                    OutlinedTextField(
                        value = cancelReason,
                        onValueChange = { cancelReason = it },
                        label = { Text("Reason for cancellation") },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val r = routeToCancel
                        if (r != null) {
                            onCancelRoute(r.id, cancelReason.ifBlank { "Cancelled by owner" })
                        }
                        routeToCancel = null
                        cancelReason = ""
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text("Cancel Route", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { routeToCancel = null }) {
                    Text("Keep Route")
                }
            }
        )
    }

    // Stop Inspection Bottom Sheet
    state.selectedRouteForInspection?.let { selectedRoute ->
        RouteStopInspectionSheet(
            route = selectedRoute,
            isRefreshing = state.isRefreshing,
            onRefresh = { onRefreshRoute(selectedRoute.id) },
            onDismiss = { onSelectRouteForInspection(null) }
        )
    }
}

@Composable
private fun PlannedRouteCard(
    route: PlannedRoute,
    onSelect: () -> Unit,
    onPublish: () -> Unit,
    onCancel: () -> Unit
) {
    val statusColor = when (route.status) {
        RouteStatus.PUBLISHED -> Color(0xFF16A34A)
        RouteStatus.DRAFT -> Color(0xFFD97706)
        RouteStatus.CANCELLED -> Color(0xFFDC2626)
    }

    val total = if (route.stops.isNotEmpty()) route.stops.size else route.totalStops
    val visited = route.stops.count { it.status == StopStatus.VISITED }
    val skipped = route.stops.count { it.status == StopStatus.SKIPPED }
    val pending = if (route.stops.isNotEmpty()) route.stops.count { it.status == StopStatus.PENDING } else total
    val resolved = visited + skipped

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Header: Title & Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = route.name,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    modifier = Modifier.weight(1f)
                )

                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = statusColor.copy(alpha = 0.12f)
                ) {
                    Text(
                        text = route.status.name,
                        color = statusColor,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Salesperson & Date
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Salesperson: ${route.salespersonName}", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface)
                Text("Date: ${route.routeDate}", fontSize = 13.sp, color = Color.Gray)
            }

            Spacer(Modifier.height(10.dp))

            // Live Progress Metrics
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(10.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Route Progress",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "$resolved/$total resolved",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (resolved == total && total > 0) Color(0xFF16A34A) else RFColors.Primary
                        )
                    }

                    Spacer(Modifier.height(6.dp))

                    LinearProgressIndicator(
                        progress = { if (total > 0) resolved.toFloat() / total else 0f },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp),
                        color = Color(0xFF16A34A),
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )

                    Spacer(Modifier.height(6.dp))

                    Text(
                        text = "$total total · $visited visited · $skipped skipped · $pending pending · $resolved/$total resolved",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Distance & Duration Metrics
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f), RoundedCornerShape(8.dp))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Stops", fontSize = 11.sp, color = Color.Gray)
                    Text("$total", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Distance", fontSize = 11.sp, color = Color.Gray)
                    Text(
                        OsrmRoutingHelper.formatDistance(route.roadDistanceMeters),
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = RFColors.Primary
                    )
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Driving Time", fontSize = 11.sp, color = Color.Gray)
                    Text(
                        OsrmRoutingHelper.formatDuration(route.roadDurationSeconds),
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Inspection hint row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Tap card to inspect stops",
                    fontSize = 11.sp,
                    color = RFColors.Primary,
                    fontWeight = FontWeight.Medium
                )
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = RFColors.Primary
                )
            }

            if (route.status == RouteStatus.DRAFT) {
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onCancel) {
                        Text("Cancel", color = Color.Red.copy(alpha = 0.8f))
                    }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick = onPublish,
                        colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                    ) {
                        Icon(Icons.Default.Publish, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Publish")
                    }
                }
            } else if (route.status == RouteStatus.PUBLISHED) {
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Active on salesperson's app",
                        fontSize = 12.sp,
                        color = Color(0xFF16A34A),
                        fontWeight = FontWeight.SemiBold
                    )
                    TextButton(onClick = onCancel) {
                        Text("Cancel Route", color = Color.Red.copy(alpha = 0.8f), fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteStopInspectionSheet(
    route: PlannedRoute,
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val total = if (route.stops.isNotEmpty()) route.stops.size else route.totalStops
    val visited = route.stops.count { it.status == StopStatus.VISITED }
    val skipped = route.stops.count { it.status == StopStatus.SKIPPED }
    val pending = if (route.stops.isNotEmpty()) route.stops.count { it.status == StopStatus.PENDING } else total
    val resolved = visited + skipped

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = route.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                    Text(
                        text = "Salesperson: ${route.salespersonName}",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                FilledTonalButton(
                    onClick = onRefresh,
                    enabled = !isRefreshing,
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    if (isRefreshing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = RFColors.Primary
                        )
                        Spacer(Modifier.width(6.dp))
                        Text("Refreshing...", fontSize = 12.sp)
                    } else {
                        Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Refresh", fontSize = 12.sp)
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            // Summary progress badge
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "$total total · $visited visited · $skipped skipped · $pending pending",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = "$resolved/$total resolved",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (resolved == total && total > 0) Color(0xFF16A34A) else RFColors.Primary
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "Route Stops (${route.stops.size})",
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp
            )

            Spacer(Modifier.height(8.dp))

            if (route.stops.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No stops configured for this route",
                        color = Color.Gray,
                        fontSize = 13.sp
                    )
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(route.stops.sortedBy { it.stopSequence }) { stop ->
                        RouteStopInspectionItem(stop = stop)
                    }
                }
            }
        }
    }
}

@Composable
private fun RouteStopInspectionItem(stop: PlannedRouteStop) {
    val statusColor = when (stop.status) {
        StopStatus.VISITED -> Color(0xFF16A34A)
        StopStatus.SKIPPED -> Color(0xFFD97706)
        StopStatus.PENDING -> Color(0xFF6B7280)
    }

    val (syncLabel, syncColor, syncIcon) = when (stop.syncStatus) {
        "CLOUD_CONFIRMED" -> Triple("Cloud Confirmed", Color(0xFF16A34A), Icons.Default.CloudDone)
        "SAVED_OFFLINE" -> Triple("Saved Offline", Color(0xFFD97706), Icons.Default.CloudQueue)
        "SYNCING" -> Triple("Syncing", Color(0xFF2563EB), Icons.Default.Sync)
        "NEEDS_ATTENTION" -> Triple("Needs Attention", Color(0xFFDC2626), Icons.Default.ErrorOutline)
        "LOCAL_ONLY" -> Triple("Local Only", Color(0xFF6B7280), Icons.Default.CloudQueue)
        "UNVERIFIED" -> Triple("Unverified", Color(0xFF6B7280), Icons.Default.CloudQueue)
        else -> Triple(stop.syncStatus, Color.Gray, Icons.Default.CloudQueue)
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    // Sequence Badge
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = RFColors.Primary.copy(alpha = 0.1f),
                        modifier = Modifier.size(24.dp)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = "${stop.stopSequence}",
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                color = RFColors.Primary
                            )
                        }
                    }

                    Spacer(Modifier.width(8.dp))

                    Text(
                        text = stop.retailerName,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp
                    )
                }

                // Stop Status Badge
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = statusColor.copy(alpha = 0.12f)
                ) {
                    Text(
                        text = stop.status.name,
                        color = statusColor,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                }
            }

            if (stop.address.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stop.address,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(Modifier.height(6.dp))

            // Visit time or notes if available
            if (stop.visitedAt != null && stop.visitedAt > 0) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.Schedule,
                        contentDescription = null,
                        modifier = Modifier.size(13.dp),
                        tint = Color.Gray
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = "Visited at ${formatTimestamp(stop.visitedAt)}",
                        fontSize = 11.sp,
                        color = Color.Gray
                    )
                }
            }

            if (!stop.notes.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "Notes: \"${stop.notes}\"",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(Modifier.height(6.dp))

            // Sync Status Badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = syncColor.copy(alpha = 0.10f)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            syncIcon,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = syncColor
                        )
                        Spacer(Modifier.width(4.dp))
                        Text(
                            text = syncLabel,
                            color = syncColor,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 10.sp
                        )
                    }
                }
            }
        }
    }
}

private fun formatTimestamp(millis: Long?): String {
    if (millis == null || millis <= 0) return ""
    return SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date(millis))
}
