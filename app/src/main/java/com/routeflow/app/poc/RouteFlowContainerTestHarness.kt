@file:Suppress("DEPRECATION")

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
import java.io.File

/**
 * Isolated debug test harness for validating [RouteFlowMap] container integration in Phase 3C.
 *
 * Exercises:
 * - Default provider mode (Google Maps if key present, else honest Logistics Canvas fallback).
 * - Explicit [MapProviderMode.MAPLIBRE_OFFLINE] with valid local archive.
 * - Graceful fallback to [RouteFlowLogisticsCanvasMap] when archive is missing or corrupted.
 * - Marker selection, contextual bottom sheet, and overlapping pin cycling.
 * - Empty map tap selection dismissal.
 * - Floating controls (Recenter, Zoom In, Zoom Out) dispatching to whichever provider is active.
 * - Polyline overlay toggling.
 */
@Composable
fun RouteFlowContainerTestHarness(
    validArchiveFile: File,
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
                title = "Civil Lines Hub A",
                subtitle = "Civil Lines Gate 1",
                address = "Civil Lines, Jaipur",
                latitude = 26.9050,
                longitude = 75.7850,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.COMPLETED,
                sequenceNumber = 3
            ),
            LogisticsMarker(
                id = "RJ-JPR-004",
                title = "Civil Lines Hub B",
                subtitle = "Civil Lines Gate 2, Jaipur",
                address = "Civil Lines, Jaipur",
                latitude = 26.9050,
                longitude = 75.7850,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.PENDING,
                sequenceNumber = 4
            ),
            LogisticsMarker(
                id = "RJ-JPR-005",
                title = "C-Scheme Retail",
                subtitle = "Ashok Nagar",
                address = "Subhash Marg, C-Scheme, Jaipur",
                latitude = 26.9100,
                longitude = 75.7950,
                type = LogisticsMarkerType.RETAILER,
                status = LogisticsMarkerStatus.COMPLETED,
                sequenceNumber = 5
            )
        )
    }

    var selectedMarkerId by remember { mutableStateOf<String?>(null) }
    var enablePolylines by remember { mutableStateOf(true) }
    var isMapView by remember { mutableStateOf(true) }

    // Test configuration state
    var selectedProviderMode by remember { mutableStateOf<MapProviderMode?>(null) }
    var archiveState by remember { mutableStateOf("VALID") } // "VALID", "MISSING", "CORRUPT"
    var fallbackReport by remember { mutableStateOf<String?>(null) }

    // Corrupt archive reference (0-byte file in cache)
    val corruptArchiveFile = remember {
        val file = File(validArchiveFile.parentFile, "corrupted_test.pmtiles")
        if (!file.exists()) {
            file.createNewFile()
        }
        file
    }

    val missingArchiveFile = remember {
        File("/nonexistent/path/missing_test.pmtiles")
    }

    val activeArchiveFile = when (archiveState) {
        "MISSING" -> missingArchiveFile
        "CORRUPT" -> corruptArchiveFile
        else -> validArchiveFile
    }

    val selectedMarker = remember(selectedMarkerId) {
        sampleMarkers.firstOrNull { it.id == selectedMarkerId }
    }

    Box(modifier = modifier.fillMaxSize()) {
        // Master Container
        RouteFlowMap(
            markers = sampleMarkers,
            selectedMarkerId = selectedMarkerId,
            onMarkerSelected = { marker ->
                selectedMarkerId = marker.id
            },
            onDismissSelection = {
                selectedMarkerId = null
            },
            isMapView = isMapView,
            onToggleView = { isMapView = it },
            enablePolylines = enablePolylines,
            providerMode = selectedProviderMode ?: MapConfig.defaultProviderMode(),
            archiveFile = activeArchiveFile,
            onProviderFallback = { fallbackMode, reason ->
                fallbackReport = "Fallback to $fallbackMode: $reason"
            },
            modifier = Modifier.fillMaxSize()
        )

        // Top Diagnostic HUD
        Column(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 16.dp, top = 48.dp, end = 80.dp)
                .background(Color(0xE60F172A), RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Text(
                text = "RouteFlowMap Phase 3C Integration",
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                color = Color.White
            )
            val reqMode = selectedProviderMode?.name ?: "DEFAULT (${MapConfig.defaultProviderMode().name})"
            Text(
                text = "Requested: $reqMode • Archive: $archiveState",
                fontSize = 11.sp,
                color = Color(0xFF93C5FD)
            )
            if (fallbackReport != null) {
                Text(
                    text = fallbackReport!!,
                    fontSize = 11.sp,
                    color = Color(0xFFFCA5A5),
                    fontWeight = FontWeight.Medium
                )
            }
            Text(
                text = "Selected Marker: ${selectedMarker?.title ?: "None"}",
                fontSize = 11.sp,
                color = if (selectedMarkerId != null) Color(0xFF34D399) else Color(0xFF94A3B8)
            )
            Text(
                text = "Polylines: ${if (enablePolylines) "ON" else "OFF"}",
                fontSize = 11.sp,
                color = Color(0xFFCBD5E1)
            )
        }

        // Test Control Action Buttons (Right rail below floating controls)
        Column(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 12.dp, top = 60.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.End
        ) {
            // Mode Switcher (Default -> MapLibre -> Canvas)
            SmallFloatingActionButton(
                onClick = {
                    fallbackReport = null
                    selectedProviderMode = when (selectedProviderMode) {
                        null -> MapProviderMode.MAPLIBRE_OFFLINE
                        MapProviderMode.MAPLIBRE_OFFLINE -> MapProviderMode.LOGISTICS_CANVAS
                        MapProviderMode.LOGISTICS_CANVAS -> null
                        else -> null
                    }
                },
                containerColor = Color.White,
                contentColor = RFColors.Primary,
                shape = CircleShape
            ) {
                Icon(
                    imageVector = Icons.Default.Layers,
                    contentDescription = "Cycle Provider Mode"
                )
            }

            // Archive Switcher (VALID -> MISSING -> CORRUPT)
            SmallFloatingActionButton(
                onClick = {
                    fallbackReport = null
                    archiveState = when (archiveState) {
                        "VALID" -> "MISSING"
                        "MISSING" -> "CORRUPT"
                        else -> "VALID"
                    }
                },
                containerColor = Color.White,
                contentColor = when (archiveState) {
                    "VALID" -> Color(0xFF10B981)
                    "MISSING" -> Color(0xFFEF4444)
                    else -> Color(0xFFF59E0B)
                },
                shape = CircleShape
            ) {
                Icon(
                    imageVector = Icons.Default.Folder,
                    contentDescription = "Cycle Archive State"
                )
            }

            // Toggle Polylines
            SmallFloatingActionButton(
                onClick = { enablePolylines = !enablePolylines },
                containerColor = Color.White,
                contentColor = if (enablePolylines) RFColors.Primary else Color.Gray,
                shape = CircleShape
            ) {
                Icon(
                    imageVector = Icons.Default.AltRoute,
                    contentDescription = "Toggle Polylines"
                )
            }
        }

        // Contextual Bottom Card (mirroring Sales/Delivery/Owner screen contextual sheets)
        if (selectedMarker != null) {
            Card(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                shape = RoundedCornerShape(16.dp)
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
                            text = selectedMarker.title,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = Color(0xFF0F172A)
                        )
                        selectedMarker.subtitle?.let {
                            Text(
                                text = it,
                                fontSize = 13.sp,
                                color = Color(0xFF64748B)
                            )
                        }
                        Text(
                            text = "Coords: ${selectedMarker.latitude}, ${selectedMarker.longitude}",
                            fontSize = 11.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }
                    IconButton(onClick = { selectedMarkerId = null }) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Dismiss",
                            tint = Color.Gray
                        )
                    }
                }
            }
        }
    }
}
