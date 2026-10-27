@file:Suppress("DEPRECATION")

package com.routeflow.app.core.design.map

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FileOpen
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import kotlinx.coroutines.launch
import java.io.File

/**
 * RouteFlow Master Map container.
 *
 * Dynamically switches between:
 * - Google Maps (when API Key is present and configured)
 * - MapLibre PMTiles Offline Vector Basemap (when a valid local territory archive is present or requested)
 * - RouteFlowLogisticsCanvasMap (when offline, key missing, archive missing/invalid, or as fallback)
 *
 * Provides a seamless in-app import action when no regional street archive is found,
 * allowing drivers and fleet managers to activate offline street maps without ADB or code changes.
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
    enablePolylines: Boolean = true,
    routeCoordinates: List<Pair<Double, Double>>? = null,
    providerMode: MapProviderMode? = null,
    archiveFile: File? = null,
    onProviderFallback: ((fallbackMode: MapProviderMode, reason: String) -> Unit)? = null
) {
    val context = LocalContext.current
    var archiveUpdateTrigger by remember { mutableIntStateOf(0) }
    var importStatusMessage by remember { mutableStateOf<String?>(null) }
    var showImportBanner by remember { mutableStateOf(true) }

    val effectiveArchive = archiveFile ?: remember(context, archiveUpdateTrigger) {
        MapConfig.resolveDefaultArchiveFile(context)
    }

    val validMarkers = remember(markers) {
        markers.filter { it.hasValidCoordinates }
    }
    val missingCount = remember(markers) {
        markers.count { !it.hasValidCoordinates }
    }

    // MapLibre runtime load failure tracker
    var mapLibreRuntimeError by remember(providerMode, effectiveArchive.absolutePath, archiveUpdateTrigger) {
        mutableStateOf<String?>(null)
    }

    // Determine target mode: defaults to MapConfig.defaultProviderMode(context) if not explicitly set
    val targetMode = remember(providerMode, effectiveArchive, archiveUpdateTrigger) {
        providerMode ?: MapConfig.defaultProviderMode(context)
    }

    // Determine effective provider
    val effectiveProvider = remember(targetMode, effectiveArchive, mapLibreRuntimeError) {
        when (targetMode) {
            MapProviderMode.GOOGLE_MAPS -> {
                if (MapConfig.isGoogleMapsConfigured()) {
                    MapProviderMode.GOOGLE_MAPS
                } else {
                    MapProviderMode.LOGISTICS_CANVAS
                }
            }
            MapProviderMode.MAPLIBRE_OFFLINE -> {
                if (mapLibreRuntimeError != null) {
                    MapProviderMode.LOGISTICS_CANVAS
                } else if (!effectiveArchive.exists()) {
                    MapProviderMode.LOGISTICS_CANVAS
                } else {
                    val validation = PmtilesHeaderInspector.inspect(effectiveArchive)
                    if (validation !is PmtilesArchiveValidation.Valid) {
                        MapProviderMode.LOGISTICS_CANVAS
                    } else {
                        MapProviderMode.MAPLIBRE_OFFLINE
                    }
                }
            }
            MapProviderMode.LOGISTICS_CANVAS -> MapProviderMode.LOGISTICS_CANVAS
        }
    }

    // Notify fallback callback if MapLibre was expected but could not be rendered
    LaunchedEffect(targetMode, effectiveArchive, mapLibreRuntimeError) {
        if (targetMode == MapProviderMode.MAPLIBRE_OFFLINE && effectiveProvider == MapProviderMode.LOGISTICS_CANVAS) {
            val reason = when {
                mapLibreRuntimeError != null -> mapLibreRuntimeError!!
                !effectiveArchive.exists() -> "PMTiles archive missing at: ${effectiveArchive.absolutePath}"
                else -> {
                    val validation = PmtilesHeaderInspector.inspect(effectiveArchive)
                    if (validation is PmtilesArchiveValidation.Corrupt) {
                        validation.reason
                    } else {
                        "Archive validation failed"
                    }
                }
            }
            onProviderFallback?.invoke(MapProviderMode.LOGISTICS_CANVAS, reason)
        }
    }

    // System document picker launcher for importing territory PMTiles archives
    val documentPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            val result = PmtilesArchiveImporter.importArchiveFromUri(context, uri)
            when (result) {
                is PmtilesArchiveImporter.ImportResult.Success -> {
                    importStatusMessage = result.message
                    archiveUpdateTrigger++
                }
                is PmtilesArchiveImporter.ImportResult.Error -> {
                    importStatusMessage = result.message
                }
            }
        }
    }

    // Authoritative canvas map viewport state (zoom and pan)
    var canvasZoom by remember { mutableFloatStateOf(1.0f) }
    var canvasPan by remember { mutableStateOf(Offset.Zero) }

    // Google Maps Camera state
    val defaultTarget = remember(validMarkers) {
        if (validMarkers.isNotEmpty()) {
            val avgLat = validMarkers.map { it.latitude }.average()
            val avgLng = validMarkers.map { it.longitude }.average()
            LatLng(avgLat, avgLng)
        } else {
            // Chandigarh Tricity logistics default
            LatLng(30.7333, 76.7794)
        }
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(defaultTarget, 13f)
    }

    // MapLibre Camera Controller
    val mapLibreController = rememberRouteFlowMapLibreController()

    val coroutineScope = rememberCoroutineScope()

    Box(modifier = modifier.fillMaxSize()) {
        when (effectiveProvider) {
            MapProviderMode.MAPLIBRE_OFFLINE -> {
                RouteFlowMapLibreView(
                    archiveFile = effectiveArchive,
                    markers = markers,
                    selectedMarkerId = selectedMarkerId,
                    onMarkerSelected = onMarkerSelected,
                    onDismissSelection = onDismissSelection,
                    modifier = Modifier.fillMaxSize(),
                    enablePolylines = enablePolylines,
                    routeCoordinates = routeCoordinates,
                    controller = mapLibreController,
                    onMapError = { err ->
                        mapLibreRuntimeError = err
                    }
                )
            }
            MapProviderMode.GOOGLE_MAPS -> {
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
                        val polylinePoints = if (!routeCoordinates.isNullOrEmpty() && routeCoordinates.size >= 2) {
                            routeCoordinates.map { LatLng(it.first, it.second) }
                        } else {
                            validMarkers
                                .filter { it.sequenceNumber != null }
                                .sortedBy { it.sequenceNumber }
                                .map { LatLng(it.latitude, it.longitude) }
                        }

                        if (polylinePoints.size >= 2) {
                            Polyline(
                                points = polylinePoints,
                                color = Color(0xFF2563EB),
                                width = 10f
                            )
                        }
                    }
                }
            }
            MapProviderMode.LOGISTICS_CANVAS -> {
                // Honest Vector Logistics Canvas Fallback
                RouteFlowLogisticsCanvasMap(
                    markers = markers,
                    selectedMarkerId = selectedMarkerId,
                    onMarkerSelected = onMarkerSelected,
                    onDismissSelection = onDismissSelection,
                    zoomLevel = canvasZoom,
                    onZoomChange = { canvasZoom = it },
                    panOffset = canvasPan,
                    onPanChange = { canvasPan = it },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }

        // Actionable Empty-State / Provisioning Notice (when in Canvas mode due to unconfigured maps)
        if (showImportBanner && effectiveProvider == MapProviderMode.LOGISTICS_CANVAS && !MapConfig.isGoogleMapsConfigured()) {
            Surface(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 64.dp, start = 16.dp, end = 76.dp)
                    .fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                color = Color(0xF20F172A),
                shadowElevation = 6.dp
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Map,
                                contentDescription = null,
                                tint = Color(0xFF60A5FA),
                                modifier = Modifier.size(16.dp)
                            )
                            Text(
                                text = "Offline Street Map Not Found",
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 12.sp,
                                color = Color.White
                            )
                        }
                        IconButton(
                            onClick = { showImportBanner = false },
                            modifier = Modifier.size(20.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Dismiss notice",
                                tint = Color(0xFF94A3B8),
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Viewing Logistics Spatial Grid. To display regional streets and buildings offline, import a licensed territory .pmtiles map.",
                        fontSize = 11.sp,
                        color = Color(0xFF94A3B8),
                        lineHeight = 15.sp
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = {
                                documentPickerLauncher.launch(arrayOf("*/*"))
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF2563EB)
                            ),
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.FileOpen,
                                contentDescription = null,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Import Regional Map",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        if (importStatusMessage != null) {
                            Text(
                                text = importStatusMessage!!,
                                fontSize = 10.sp,
                                maxLines = 1,
                                color = if (importStatusMessage!!.startsWith("Successfully")) {
                                    Color(0xFF34D399)
                                } else {
                                    Color(0xFFFCA5A5)
                                }
                            )
                        }
                    }
                }
            }
        }

        // Floating tactile controls
        MapFloatingControls(
            isMapView = isMapView,
            onToggleView = onToggleView,
            onRecenter = {
                when (effectiveProvider) {
                    MapProviderMode.MAPLIBRE_OFFLINE -> {
                        val lat = if (validMarkers.isNotEmpty()) validMarkers.map { it.latitude }.average() else 30.7333
                        val lng = if (validMarkers.isNotEmpty()) validMarkers.map { it.longitude }.average() else 76.7794
                        mapLibreController.recenter(org.maplibre.android.geometry.LatLng(lat, lng), 13.0)
                    }
                    MapProviderMode.GOOGLE_MAPS -> {
                        coroutineScope.launch {
                            cameraPositionState.animate(
                                CameraUpdateFactory.newLatLngZoom(defaultTarget, 13f)
                            )
                        }
                    }
                    MapProviderMode.LOGISTICS_CANVAS -> {
                        canvasZoom = 1.0f
                        canvasPan = Offset.Zero
                    }
                }
            },
            onZoomIn = {
                when (effectiveProvider) {
                    MapProviderMode.MAPLIBRE_OFFLINE -> {
                        mapLibreController.zoomIn()
                    }
                    MapProviderMode.GOOGLE_MAPS -> {
                        coroutineScope.launch {
                            cameraPositionState.animate(CameraUpdateFactory.zoomIn())
                        }
                    }
                    MapProviderMode.LOGISTICS_CANVAS -> {
                        canvasZoom = (canvasZoom * 1.25f).coerceAtMost(4.0f)
                    }
                }
            },
            onZoomOut = {
                when (effectiveProvider) {
                    MapProviderMode.MAPLIBRE_OFFLINE -> {
                        mapLibreController.zoomOut()
                    }
                    MapProviderMode.GOOGLE_MAPS -> {
                        coroutineScope.launch {
                            cameraPositionState.animate(CameraUpdateFactory.zoomOut())
                        }
                    }
                    MapProviderMode.LOGISTICS_CANVAS -> {
                        canvasZoom = (canvasZoom / 1.25f).coerceAtLeast(0.5f)
                    }
                }
            },
            missingCoordinatesCount = missingCount,
            modifier = Modifier.align(Alignment.TopEnd)
        )
    }
}
