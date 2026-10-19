package com.routeflow.app.core.design.map

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import kotlinx.coroutines.launch

/**
 * RouteFlow Master Map container.
 * Dynamically switches between Google Maps (when API Key is present) and
 * RouteFlowLogisticsCanvasMap (when key is missing or offline).
 */
@Composable
fun RouteFlowMap(
    markers: List<LogisticsMarker>,
    selectedMarkerId: String?,
    onMarkerSelected: (LogisticsMarker) -> Unit,
    onDismissSelection: () -> Unit,
    isMapView: Boolean,
    onToggleView: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enablePolylines: Boolean = true
) {
    val validMarkers = remember(markers) {
        markers.filter { it.hasValidCoordinates }
    }
    val missingCount = remember(markers) {
        markers.count { !it.hasValidCoordinates }
    }

    val isGoogleMapsAvailable = remember { MapConfig.isGoogleMapsConfigured() }

    // Canvas map zoom level state
    var canvasZoom by remember { mutableFloatStateOf(1.0f) }

    // Google Maps Camera state
    val defaultTarget = remember(validMarkers) {
        if (validMarkers.isNotEmpty()) {
            val avgLat = validMarkers.map { it.latitude }.average()
            val avgLng = validMarkers.map { it.longitude }.average()
            LatLng(avgLat, avgLng)
        } else {
            // New Delhi logistics default
            LatLng(28.6139, 77.2090)
        }
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(defaultTarget, 13f)
    }

    val coroutineScope = rememberCoroutineScope()

    Box(modifier = modifier.fillMaxSize()) {
        if (isGoogleMapsAvailable) {
            // Google Maps Compose View
            val uiSettings = remember {
                MapUiSettings(
                    zoomControlsEnabled = false,
                    myLocationButtonEnabled = false,
                    compassEnabled = true,
                    mapToolbarEnabled = false
                )
            }
            val mapProperties = remember {
                MapProperties(
                    isMyLocationEnabled = false
                )
            }

            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                uiSettings = uiSettings,
                properties = mapProperties,
                onMapClick = { onDismissSelection() }
            ) {
                // Plot Markers
                validMarkers.forEach { marker ->
                    val pos = LatLng(marker.latitude, marker.longitude)
                    Marker(
                        state = rememberMarkerState(key = marker.id, position = pos),
                        title = marker.title,
                        snippet = marker.subtitle ?: marker.address,
                        onClick = {
                            onMarkerSelected(marker)
                            true
                        }
                    )
                }

                // Connect sequential delivery stops with polyline
                if (enablePolylines) {
                    val polylinePoints = validMarkers
                        .filter { it.sequenceNumber != null }
                        .sortedBy { it.sequenceNumber }
                        .map { LatLng(it.latitude, it.longitude) }

                    if (polylinePoints.size >= 2) {
                        Polyline(
                            points = polylinePoints,
                            color = androidx.compose.ui.graphics.Color(0xFF2563EB),
                            width = 10f
                        )
                    }
                }
            }
        } else {
            // Honest Vector Logistics Canvas Fallback
            RouteFlowLogisticsCanvasMap(
                markers = markers,
                selectedMarkerId = selectedMarkerId,
                onMarkerSelected = onMarkerSelected,
                onDismissSelection = onDismissSelection,
                zoomLevel = canvasZoom,
                onZoomChange = { canvasZoom = it },
                modifier = Modifier.fillMaxSize()
            )
        }

        // Floating tactile controls
        MapFloatingControls(
            isMapView = isMapView,
            onToggleView = onToggleView,
            onRecenter = {
                if (isGoogleMapsAvailable) {
                    coroutineScope.launch {
                        cameraPositionState.animate(
                            CameraUpdateFactory.newLatLngZoom(defaultTarget, 13f)
                        )
                    }
                } else {
                    canvasZoom = 1.0f
                }
            },
            onZoomIn = {
                if (isGoogleMapsAvailable) {
                    coroutineScope.launch {
                        cameraPositionState.animate(CameraUpdateFactory.zoomIn())
                    }
                } else {
                    canvasZoom = (canvasZoom * 1.25f).coerceAtMost(4.0f)
                }
            },
            onZoomOut = {
                if (isGoogleMapsAvailable) {
                    coroutineScope.launch {
                        cameraPositionState.animate(CameraUpdateFactory.zoomOut())
                    }
                } else {
                    canvasZoom = (canvasZoom / 1.25f).coerceAtLeast(0.5f)
                }
            },
            missingCoordinatesCount = missingCount,
            modifier = Modifier.align(Alignment.TopEnd)
        )
    }
}
