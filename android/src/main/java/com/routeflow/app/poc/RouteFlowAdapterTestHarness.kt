package com.routeflow.app.poc

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.*
import org.maplibre.android.geometry.LatLng
import java.io.File

/**
 * Isolated debug test harness specifically validating [RouteFlowMapLibreView].
 *
 * Exercises:
 * - MapLibre Native initialization and PMTiles vector street basemap rendering.
 * - Offline behavior with network severed.
 * - Retailer marker plotting and geographic coordinate accuracy.
 * - Overlapping marker cycling via [MapLibreMarkerCyclingMath].
 * - Empty map tap selection dismissal.
 * - Route polyline display toggling.
 * - Camera controller (Recenter, Zoom In, Zoom Out).
 * - Graceful fallback to [RouteFlowLogisticsCanvasMap] when archive is missing or corrupt.
 */
@Composable
fun RouteFlowAdapterTestHarness(
    archiveFile: File,
    modifier: Modifier = Modifier
) {
    val sampleMarkers = remember {
        listOf(
            LogisticsMarker(
                id = "RJ-JPR-001",
                title = "Pink City Kirana",
                subtitle = "Badi Chaupar, Old City",
                address = "Shop 12, Johari Bazar, Jaipur",
                latitude = 26.9239,
                longitude = 75.8267,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.PENDING,
                sequenceNumber = 1
            ),
            LogisticsMarker(
                id = "RJ-JPR-002",
                title = "MI Road Supermarket",
                subtitle = "Panch Batti, MI Road",
                address = "Plot 4, MI Road, Jaipur",
                latitude = 26.9150,
                longitude = 75.8050,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.IN_PROGRESS,
                sequenceNumber = 2
            ),
            LogisticsMarker(
                id = "RJ-JPR-003",
                title = "Bapu Bazaar Traders",
                subtitle = "Link Road Wholesale",
                address = "Bapu Bazaar, Jaipur",
                latitude = 26.9200,
                longitude = 75.8220,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.PENDING,
                sequenceNumber = 3
            ),
            // Co-located markers to test overlapping marker cycling
            LogisticsMarker(
                id = "RJ-JPR-004A",
                title = "Civil Lines Hub A",
                subtitle = "Co-located Stop #4",
                address = "Civil Lines Gate 1, Jaipur",
                latitude = 26.9050,
                longitude = 75.7850,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.PENDING,
                sequenceNumber = 4
            ),
            LogisticsMarker(
                id = "RJ-JPR-004B",
                title = "Civil Lines Hub B",
                subtitle = "Co-located Stop #5 (Overlapping)",
                address = "Civil Lines Gate 2, Jaipur",
                latitude = 26.9050,
                longitude = 75.7850,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.PENDING,
                sequenceNumber = 5
            )
        )
    }

    var selectedMarkerId by remember { mutableStateOf<String?>(null) }
    var enablePolylines by remember { mutableStateOf(true) }
    var mapError by remember { mutableStateOf<String?>(null) }
    var isMapReady by remember { mutableStateOf(false) }
    var activeArchiveFile by remember { mutableStateOf(archiveFile) }

    val controller = rememberRouteFlowMapLibreController()
    val selectedMarker = remember(selectedMarkerId) {
        sampleMarkers.find { it.id == selectedMarkerId }
    }

    Box(modifier = modifier.fillMaxSize()) {
        if (mapError == null) {
            // Render the isolated production adapter
            RouteFlowMapLibreView(
                archiveFile = activeArchiveFile,
                markers = sampleMarkers,
                selectedMarkerId = selectedMarkerId,
                onMarkerSelected = { marker ->
                    selectedMarkerId = marker.id
                },
                onDismissSelection = {
                    selectedMarkerId = null
                },
                enablePolylines = enablePolylines,
                controller = controller,
                onMapReady = {
                    isMapReady = true
                },
                onMapError = { errorReason ->
                    mapError = errorReason
                },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            // Fallback to existing RouteFlowLogisticsCanvasMap on error
            RouteFlowLogisticsCanvasMap(
                markers = sampleMarkers,
                selectedMarkerId = selectedMarkerId,
                onMarkerSelected = { selectedMarkerId = it.id },
                onDismissSelection = { selectedMarkerId = null },
                modifier = Modifier.fillMaxSize()
            )
        }

        // Top Diagnostic Card
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = Color.White.copy(alpha = 0.95f),
            shadowElevation = 6.dp,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 44.dp, start = 14.dp, end = 14.dp)
                .fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = "RouteFlowMapLibreView Acceptance Test",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Spacer(modifier = Modifier.height(4.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = if (mapError == null) Icons.Default.CheckCircle else Icons.Default.Warning,
                        contentDescription = null,
                        tint = if (mapError == null) Color(0xFF16A34A) else Color(0xFFDC2626),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (mapError == null) {
                            if (isMapReady) "Engine Ready • Streets Rendered Offline" else "Initializing Engine..."
                        } else {
                            "Error Fallback Active: $mapError"
                        },
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (mapError == null) Color(0xFF15803D) else Color(0xFFB91C1C)
                    )
                }

                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "Selected Marker: ${selectedMarker?.title ?: "None (Tap a pin)"}",
                    fontSize = 11.sp,
                    color = RFColors.TextSecondary
                )
                Text(
                    text = "Polylines: ${if (enablePolylines) "ON (Stops 1→2→3→4→5)" else "OFF"}",
                    fontSize = 11.sp,
                    color = RFColors.TextSecondary
                )
            }
        }

        // Floating Tactile Controls (Recenter, Zoom In, Zoom Out, Toggle Polylines, Trigger Missing Fallback)
        Column(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FloatingActionButton(
                onClick = {
                    controller.recenter(LatLng(26.9150, 75.8050), 13.0)
                },
                modifier = Modifier.size(44.dp),
                containerColor = Color.White,
                contentColor = RFColors.Primary,
                shape = CircleShape
            ) {
                Icon(Icons.Default.MyLocation, contentDescription = "Recenter", modifier = Modifier.size(20.dp))
            }

            FloatingActionButton(
                onClick = { controller.zoomIn() },
                modifier = Modifier.size(44.dp),
                containerColor = Color.White,
                contentColor = RFColors.Primary,
                shape = CircleShape
            ) {
                Icon(Icons.Default.Add, contentDescription = "Zoom In", modifier = Modifier.size(20.dp))
            }

            FloatingActionButton(
                onClick = { controller.zoomOut() },
                modifier = Modifier.size(44.dp),
                containerColor = Color.White,
                contentColor = RFColors.Primary,
                shape = CircleShape
            ) {
                Icon(Icons.Default.Remove, contentDescription = "Zoom Out", modifier = Modifier.size(20.dp))
            }

            FloatingActionButton(
                onClick = { enablePolylines = !enablePolylines },
                modifier = Modifier.size(44.dp),
                containerColor = if (enablePolylines) RFColors.Primary else Color.White,
                contentColor = if (enablePolylines) Color.White else RFColors.Primary,
                shape = CircleShape
            ) {
                Icon(Icons.Default.Route, contentDescription = "Toggle Polylines", modifier = Modifier.size(20.dp))
            }

            // Test button to toggle missing file to verify canvas fallback
            FloatingActionButton(
                onClick = {
                    if (mapError == null) {
                        activeArchiveFile = File("/nonexistent/path/missing.pmtiles")
                    } else {
                        mapError = null
                        isMapReady = false
                        activeArchiveFile = archiveFile
                    }
                },
                modifier = Modifier.size(44.dp),
                containerColor = Color(0xFFFEF3C7),
                contentColor = Color(0xFF92400E),
                shape = CircleShape
            ) {
                Icon(Icons.Default.BugReport, contentDescription = "Toggle Missing Fallback", modifier = Modifier.size(20.dp))
            }
        }

        // Bottom Contextual Card when marker is selected
        if (selectedMarker != null) {
            Surface(
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
                color = Color.White,
                shadowElevation = 8.dp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = selectedMarker.title,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = selectedMarker.address ?: selectedMarker.subtitle ?: "",
                            fontSize = 12.sp,
                            color = RFColors.TextSecondary
                        )
                        Text(
                            text = "Coords: ${selectedMarker.latitude}, ${selectedMarker.longitude}",
                            fontSize = 11.sp,
                            color = Color(0xFF2563EB)
                        )
                    }

                    IconButton(onClick = { selectedMarkerId = null }) {
                        Icon(Icons.Default.Close, contentDescription = "Dismiss")
                    }
                }
            }
        }
    }
}
