package com.routeflow.app.feature.owner

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Route
import androidx.compose.material.icons.filled.Schedule
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
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.Retailer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerRoutePlannerScreen(
    state: OwnerRoutePlannerState,
    onDateChanged: (String) -> Unit,
    onNameChanged: (String) -> Unit,
    onSalespersonSelected: (Employee) -> Unit,
    onAddRetailerStop: (Retailer) -> Unit,
    onMoveStopUp: (Int) -> Unit,
    onMoveStopDown: (Int) -> Unit,
    onRemoveStop: (Int) -> Unit,
    onRecalculateRoad: () -> Unit,
    onSaveDraft: () -> Unit,
    onPublishRoute: () -> Unit,
    onNavigateBack: () -> Unit,
    onClearMessages: () -> Unit
) {
    var isMapView by remember { mutableStateOf(false) }
    var selectedMarkerId by remember { mutableStateOf<String?>(null) }
    var showPublishConfirmDialog by remember { mutableStateOf(false) }
    var showAddRetailerSheet by remember { mutableStateOf(false) }
    var salespersonDropdownExpanded by remember { mutableStateOf(false) }

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.errorMessage, state.successMessage) {
        state.errorMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
        state.successMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
    }

    // Map markers from all retailers + sequence numbers for selected stops
    val mapMarkers = remember(state.allRetailers, state.stops) {
        state.allRetailers.map { ret ->
            val stopIdx = state.stops.indexOfFirst { it.retailerId == ret.id }
            val seqNumber = if (stopIdx >= 0) stopIdx + 1 else null
            LogisticsMarker(
                id = ret.id,
                title = ret.name,
                subtitle = if (seqNumber != null) "Stop #$seqNumber" else ret.address,
                latitude = ret.latitude,
                longitude = ret.longitude,
                type = LogisticsMarkerType.RETAILER,
                status = if (seqNumber != null) LogisticsMarkerStatus.IN_PROGRESS else LogisticsMarkerStatus.PENDING,
                sequenceNumber = seqNumber,
                address = ret.address,
                contactPhone = ret.contactNumber,
                retailerId = ret.id
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Route Planner", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(
                            text = if (state.stops.isEmpty()) "Add retailers to build route" else "${state.stops.size} stops sequenced",
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
        bottomBar = {
            Surface(
                tonalElevation = 8.dp,
                shadowElevation = 8.dp,
                color = MaterialTheme.colorScheme.surface
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = onSaveDraft,
                        modifier = Modifier.weight(1f),
                        enabled = !state.isSaving
                    ) {
                        Text("Save Draft", fontWeight = FontWeight.SemiBold)
                    }

                    Button(
                        onClick = { showPublishConfirmDialog = true },
                        modifier = Modifier.weight(1f),
                        enabled = !state.isSaving && state.stops.isNotEmpty() && state.selectedSalesperson != null,
                        colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                    ) {
                        if (state.isSaving) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                color = Color.White,
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text("Publish Route", fontWeight = FontWeight.Bold)
                        }
                    }
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
            // 1. Metadata Bar (Date, Route Name, Salesperson)
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedTextField(
                            value = state.routeName,
                            onValueChange = onNameChanged,
                            label = { Text("Route Name") },
                            modifier = Modifier.weight(2f),
                            singleLine = true
                        )

                        OutlinedTextField(
                            value = state.routeDate,
                            onValueChange = onDateChanged,
                            label = { Text("Date (YYYY-MM-DD)") },
                            modifier = Modifier.weight(1.3f),
                            singleLine = true
                        )
                    }

                    // Salesperson Selector Dropdown
                    Box(modifier = Modifier.fillMaxWidth()) {
                        OutlinedButton(
                            onClick = { salespersonDropdownExpanded = true },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.Person, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = state.selectedSalesperson?.let { "Assigned: ${it.name}" } ?: "Select Salesperson",
                                fontWeight = FontWeight.Medium
                            )
                        }

                        DropdownMenu(
                            expanded = salespersonDropdownExpanded,
                            onDismissRequest = { salespersonDropdownExpanded = false }
                        ) {
                            state.salespeople.forEach { sp ->
                                DropdownMenuItem(
                                    text = { Text(sp.name) },
                                    onClick = {
                                        onSalespersonSelected(sp)
                                        salespersonDropdownExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // 2. OSRM Road Metrics Banner
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                colors = CardDefaults.cardColors(containerColor = RFColors.Primary.copy(alpha = 0.1f)),
                shape = RoundedCornerShape(12.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        // Total Stops
                        Column {
                            Text("STOPS", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                            Text("${state.stops.size}", fontWeight = FontWeight.Black, fontSize = 16.sp)
                        }

                        // Road Distance
                        Column {
                            val isFallback = state.roadMetrics?.isFallback == true || state.roadMetrics?.provider == "HAVERSINE_FALLBACK"
                            Text(
                                if (isFallback) "STRAIGHT-LINE (FALLBACK)" else "ROAD DISTANCE",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isFallback) Color(0xFFD97706) else Color.Gray
                            )
                            val distText = state.roadMetrics?.let {
                                OsrmRoutingHelper.formatDistance(it.distanceMeters)
                            } ?: "0 m"
                            Text(distText, fontWeight = FontWeight.Black, fontSize = 16.sp, color = RFColors.Primary)
                        }

                        // Est Driving Duration
                        Column {
                            Text("EST. DURATION", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                            val durText = state.roadMetrics?.let {
                                OsrmRoutingHelper.formatDuration(it.durationSeconds)
                            } ?: "0 min"
                            Text(durText, fontWeight = FontWeight.Black, fontSize = 16.sp)
                        }
                    }

                    // Routing status indicator
                    if (state.isCalculatingRoad) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    } else {
                        IconButton(onClick = onRecalculateRoad) {
                            Icon(Icons.Default.Refresh, contentDescription = "Recalculate", tint = RFColors.Primary)
                        }
                    }
                }
            }

            // 3. View Content (Map vs Stop Order List)
            if (isMapView) {
                Box(modifier = Modifier.weight(1f)) {
                    RouteFlowMap(
                        markers = mapMarkers,
                        selectedMarkerId = selectedMarkerId,
                        onMarkerSelected = { marker ->
                            selectedMarkerId = marker.id
                            val ret = state.allRetailers.find { it.id == marker.id }
                            if (ret != null) {
                                onAddRetailerStop(ret)
                            }
                        },
                        onDismissSelection = { selectedMarkerId = null },
                        isMapView = true,
                        onToggleView = { isMapView = it },
                        modifier = Modifier.fillMaxSize(),
                        routeCoordinates = state.routeGeometryCoordinates
                    )
                }
            } else {
                // Stop Sequence List
                Box(modifier = Modifier.weight(1f)) {
                    if (state.stops.isEmpty()) {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                Icons.Default.DirectionsCar,
                                contentDescription = null,
                                modifier = Modifier.size(56.dp),
                                tint = Color.LightGray
                            )
                            Spacer(Modifier.height(16.dp))
                            Text(
                                "No stops added to this route yet",
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "Tap '+ Add Retailer Stop' below or switch to Map View to click shops",
                                fontSize = 13.sp,
                                color = Color.Gray
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            itemsIndexed(state.stops) { index, stop ->
                                StopItemCard(
                                    stop = stop,
                                    isFirst = index == 0,
                                    isLast = index == state.stops.size - 1,
                                    onMoveUp = { onMoveStopUp(index) },
                                    onMoveDown = { onMoveStopDown(index) },
                                    onRemove = { onRemoveStop(index) }
                                )
                            }
                        }
                    }

                    // Floating Add Button
                    FloatingActionButton(
                        onClick = { showAddRetailerSheet = true },
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(16.dp),
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    ) {
                        Row(modifier = Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Add, contentDescription = "Add Stop")
                            Spacer(Modifier.width(4.dp))
                            Text("Add Stop", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }

    // Modal Sheet to select retailer
    if (showAddRetailerSheet) {
        ModalBottomSheet(
            onDismissRequest = { showAddRetailerSheet = false }
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Text("Select Retailer to Add", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(Modifier.height(12.dp))

                val unselectedRetailers = state.allRetailers.filter { ret ->
                    state.stops.none { it.retailerId == ret.id }
                }

                if (unselectedRetailers.isEmpty()) {
                    Text("All retailers are already included in this route.", color = Color.Gray, modifier = Modifier.padding(16.dp))
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 350.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(unselectedRetailers.size) { idx ->
                            val r = unselectedRetailers[idx]
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        onAddRetailerStop(r)
                                        showAddRetailerSheet = false
                                    },
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(r.name, fontWeight = FontWeight.Bold)
                                        Text(r.address, fontSize = 12.sp, color = Color.Gray)
                                    }
                                    Icon(Icons.Default.Add, contentDescription = null, tint = RFColors.Primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Confirmation Dialog before Publishing
    if (showPublishConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showPublishConfirmDialog = false },
            title = { Text("Publish Daily Route?", fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Salesperson: ${state.selectedSalesperson?.name}")
                    Text("Date: ${state.routeDate}")
                    Text("Total Stops: ${state.stops.size}")
                    state.roadMetrics?.let {
                        Text("Road Distance: ${OsrmRoutingHelper.formatDistance(it.distanceMeters)}")
                        Text("Est. Driving Time: ${OsrmRoutingHelper.formatDuration(it.durationSeconds)}")
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Once published, this route will become active on the salesperson's field app in the exact sequence specified.",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showPublishConfirmDialog = false
                        onPublishRoute()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                ) {
                    Text("Confirm & Publish", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showPublishConfirmDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun StopItemCard(
    stop: PlannedRouteStop,
    isFirst: Boolean,
    isLast: Boolean,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onRemove: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Sequence Number Badge
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(RFColors.Primary),
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

            // Shop Details
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stop.retailerName,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
                Text(
                    text = stop.address,
                    fontSize = 12.sp,
                    color = Color.Gray,
                    maxLines = 1
                )
                if (stop.contactNumber.isNotBlank()) {
                    Text(
                        text = "Phone: ${stop.contactNumber}",
                        fontSize = 11.sp,
                        color = Color.DarkGray
                    )
                }
            }

            // Ordering and Delete Controls
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onMoveUp, enabled = !isFirst) {
                    Icon(
                        Icons.Default.ArrowUpward,
                        contentDescription = "Move Up",
                        tint = if (!isFirst) RFColors.Primary else Color.LightGray
                    )
                }

                IconButton(onClick = onMoveDown, enabled = !isLast) {
                    Icon(
                        Icons.Default.ArrowDownward,
                        contentDescription = "Move Down",
                        tint = if (!isLast) RFColors.Primary else Color.LightGray
                    )
                }

                IconButton(onClick = onRemove) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Remove Stop",
                        tint = Color.Red.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}
