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
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Publish
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
import com.routeflow.app.domain.model.RouteStatus

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerRoutesScreen(
    state: OwnerRoutesState,
    onDateSelected: (String) -> Unit,
    onPublishRoute: (String) -> Unit,
    onCancelRoute: (String, String) -> Unit,
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
}

@Composable
private fun PlannedRouteCard(
    route: PlannedRoute,
    onPublish: () -> Unit,
    onCancel: () -> Unit
) {
    val statusColor = when (route.status) {
        RouteStatus.PUBLISHED -> Color(0xFF16A34A)
        RouteStatus.DRAFT -> Color(0xFFD97706)
        RouteStatus.CANCELLED -> Color(0xFFDC2626)
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
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

            Spacer(Modifier.height(8.dp))

            // Metrics: Stops, Road Distance, Duration
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Stops", fontSize = 11.sp, color = Color.Gray)
                    Text("${route.totalStops}", fontWeight = FontWeight.Bold, fontSize = 14.sp)
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

            if (route.status == RouteStatus.DRAFT) {
                Spacer(Modifier.height(12.dp))
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
