@file:Suppress("DEPRECATION")

package com.routeflow.app.core.design.map

import android.graphics.PointF
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.Marker
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import java.io.File

/**
 * External camera controller for [RouteFlowMapLibreView].
 * Allows parent composables (e.g. tactile floating buttons) to control camera movement,
 * recentering, and step zooming without direct coupling to native MapView instances.
 */
class RouteFlowMapLibreController {
    internal var mapInstance by mutableStateOf<MapLibreMap?>(null)

    val isReady: Boolean
        get() = mapInstance != null

    fun recenter(target: LatLng, zoom: Double = 13.0) {
        mapInstance?.animateCamera(CameraUpdateFactory.newLatLngZoom(target, zoom))
    }

    fun zoomIn() {
        mapInstance?.animateCamera(CameraUpdateFactory.zoomIn())
    }

    fun zoomOut() {
        mapInstance?.animateCamera(CameraUpdateFactory.zoomOut())
    }

    fun setCameraPosition(target: LatLng, zoom: Double) {
        mapInstance?.cameraPosition = CameraPosition.Builder()
            .target(target)
            .zoom(zoom)
            .build()
    }
}

@Composable
fun rememberRouteFlowMapLibreController(): RouteFlowMapLibreController {
    return remember { RouteFlowMapLibreController() }
}

/**
 * Isolated production MapLibre Native adapter for RouteFlow.
 *
 * Responsibilities:
 * 1. Validates local PMTiles v3 archive before initializing native map engine.
 * 2. Employs [RouteFlowMapLibreStyleBuilder] to enforce zero-network, local-only rendering.
 * 3. Bridges Android and Compose lifecycles safely with idempotent cleanup.
 * 4. Renders retailer and stop markers, highlighting selections.
 * 5. Uses [MapLibreMarkerCyclingMath] to preserve exact overlapping-marker cycling behavior.
 * 6. Plots delivery stop sequence polylines when enabled.
 * 7. Reports errors programmatically to the caller without swallowing exceptions.
 * 8. Displays legally required OpenStreetMap attribution visibly.
 */
@Composable
fun RouteFlowMapLibreView(
    archiveFile: File,
    markers: List<LogisticsMarker>,
    selectedMarkerId: String?,
    onMarkerSelected: (LogisticsMarker) -> Unit,
    onDismissSelection: () -> Unit,
    modifier: Modifier = Modifier,
    enablePolylines: Boolean = true,
    routeCoordinates: List<Pair<Double, Double>>? = null,
    controller: RouteFlowMapLibreController = rememberRouteFlowMapLibreController(),
    onMapReady: () -> Unit = {},
    onMapError: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val density = LocalDensity.current
    val touchRadiusPx = with(density) { 36.dp.toPx() }

    val validMarkers = remember(markers) {
        markers.filter { it.hasValidCoordinates }
    }

    // 1. Defensive Archive Validation
    val validation = remember(archiveFile.absolutePath) {
        PmtilesHeaderInspector.inspect(archiveFile)
    }

    var styleLoadFailed by remember { mutableStateOf(false) }

    // Report validation errors immediately
    LaunchedEffect(validation) {
        when (validation) {
            is PmtilesArchiveValidation.Missing -> {
                onMapError("PMTiles archive missing at: ${validation.path}")
            }
            is PmtilesArchiveValidation.Corrupt -> {
                onMapError("PMTiles archive corrupt or unsupported: ${validation.reason}")
            }
            is PmtilesArchiveValidation.Valid -> Unit
        }
    }

    if (validation !is PmtilesArchiveValidation.Valid || styleLoadFailed) {
        // Validation failed or style load failed: MapView will not be instantiated
        return
    }

    // 2. Initialize native MapLibre engine & MapView
    val mapView = remember {
        MapLibre.getInstance(context)
        MapView(context).apply {
            onCreate(null)
        }
    }

    // 3. Compose & Android Lifecycle forwarding
    DisposableEffect(mapView, lifecycleOwner) {
        val failListener = MapView.OnDidFailLoadingMapListener { errorReason ->
            val reason = errorReason ?: "MapLibre native map failed to load."
            styleLoadFailed = true
            onMapError(reason)
        }
        mapView.addOnDidFailLoadingMapListener(failListener)

        // Ensure MapView is immediately started and resumed if entering composition while Activity is already active
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
            mapView.onStart()
        }
        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
            mapView.onResume()
        }

        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                Lifecycle.Event.ON_DESTROY -> mapView.onDestroy()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.removeOnDidFailLoadingMapListener(failListener)
            controller.mapInstance = null
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }

    // Keep updated state references to prevent stale gesture callbacks
    val currentMarkers by rememberUpdatedState(validMarkers)
    val currentSelectedMarkerId by rememberUpdatedState(selectedMarkerId)
    val currentOnMarkerSelected by rememberUpdatedState(onMarkerSelected)
    val currentOnDismissSelection by rememberUpdatedState(onDismissSelection)

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            factory = {
                mapView.apply {
                    getMapAsync { map ->
                        Log.d("RouteFlowMapLibre", "getMapAsync callback invoked")
                        controller.mapInstance = map

                        // Enable native attribution & compass
                        map.uiSettings.isAttributionEnabled = true
                        map.uiSettings.isLogoEnabled = true
                        map.uiSettings.isCompassEnabled = true

                        // Build local-only style JSON
                        val styleJson = RouteFlowMapLibreStyleBuilder.build(validation.path)
                        map.setStyle(Style.Builder().fromJson(styleJson)) { _ ->
                            Log.d("RouteFlowMapLibre", "Style loaded successfully. Markers count: ${currentMarkers.size}")
                            onMapReady()

                            // Set initial camera to center of markers or default Tricity center
                            val target = if (currentMarkers.isNotEmpty()) {
                                LatLng(
                                    currentMarkers.map { it.latitude }.average(),
                                    currentMarkers.map { it.longitude }.average()
                                )
                            } else {
                                LatLng(30.7333, 76.7794)
                            }
                            map.cameraPosition = CameraPosition.Builder()
                                .target(target)
                                .zoom(13.0)
                                .build()

                            // Render annotations immediately upon style load
                            renderMapLibreAnnotations(map, currentMarkers, enablePolylines, routeCoordinates)
                        }

                        // Marker Click Listener: uses screen-space projection to support cycling
                        map.setOnMarkerClickListener { clickedMarker ->
                            Log.d("RouteFlowMapLibre", "onMarkerClick fired: ${clickedMarker.title}")
                            val clickedLatLng = clickedMarker.position
                            val clickedPointF = map.projection.toScreenLocation(clickedLatLng)
                            val tapScreenPoint = MapLibreMarkerCyclingMath.ScreenPoint(clickedPointF.x, clickedPointF.y)

                            val projected = currentMarkers.map { m ->
                                val pt = map.projection.toScreenLocation(LatLng(m.latitude, m.longitude))
                                m to MapLibreMarkerCyclingMath.ScreenPoint(pt.x, pt.y)
                            }

                            val resolved = MapLibreMarkerCyclingMath.findMarkerHit(
                                tapPoint = tapScreenPoint,
                                projectedMarkers = projected,
                                touchRadiusPx = touchRadiusPx,
                                currentSelectedMarkerId = currentSelectedMarkerId
                            )

                            if (resolved != null) {
                                currentOnMarkerSelected(resolved)
                            }
                            true // Consumes click to suppress default Android infowindow
                        }

                        // Map Blank Space Click Listener: checks touch radius, dismisses if blank
                        map.addOnMapClickListener { clickLatLng ->
                            Log.d("RouteFlowMapLibre", "onMapClick fired: LatLng=$clickLatLng")
                            val clickPointF = map.projection.toScreenLocation(clickLatLng)
                            val tapScreenPoint = MapLibreMarkerCyclingMath.ScreenPoint(clickPointF.x, clickPointF.y)

                            val projected = currentMarkers.map { m ->
                                val pt = map.projection.toScreenLocation(LatLng(m.latitude, m.longitude))
                                m to MapLibreMarkerCyclingMath.ScreenPoint(pt.x, pt.y)
                            }

                            val hit = MapLibreMarkerCyclingMath.findMarkerHit(
                                tapPoint = tapScreenPoint,
                                projectedMarkers = projected,
                                touchRadiusPx = touchRadiusPx,
                                currentSelectedMarkerId = currentSelectedMarkerId
                            )

                            if (hit != null) {
                                currentOnMarkerSelected(hit)
                            } else {
                                currentOnDismissSelection()
                            }
                            true
                        }
                    }
                }
            },
            update = {
                val map = controller.mapInstance ?: return@AndroidView
                renderMapLibreAnnotations(map, validMarkers, enablePolylines, routeCoordinates)
            },
            modifier = Modifier.fillMaxSize()
        )

        // Visible OSM & Protomaps attribution pill
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 8.dp, bottom = 4.dp)
                .background(
                    color = Color.White.copy(alpha = 0.85f),
                    shape = RoundedCornerShape(4.dp)
                )
                .padding(horizontal = 6.dp, vertical = 2.dp)
        ) {
            Text(
                text = "© OpenStreetMap • © Protomaps",
                fontSize = 10.sp,
                color = Color(0xFF475569)
            )
        }
    }
}

private fun renderMapLibreAnnotations(
    map: MapLibreMap,
    markers: List<LogisticsMarker>,
    enablePolylines: Boolean,
    routeCoordinates: List<Pair<Double, Double>>? = null
) {
    Log.d("RouteFlowMapLibre", "renderMapLibreAnnotations: adding ${markers.size} markers, enablePolylines=$enablePolylines")
    map.clear()

    // Plot Annotations (Markers)
    markers.forEach { marker ->
        val pos = LatLng(marker.latitude, marker.longitude)
        val markerOptions = MarkerOptions()
            .position(pos)
            .title(marker.title)
            .snippet(marker.subtitle ?: marker.address)

        map.addMarker(markerOptions)
    }

    // Plot Route Polylines (OSRM road-following geometry or sequence fallback)
    if (enablePolylines) {
        val polylinePoints = if (!routeCoordinates.isNullOrEmpty() && routeCoordinates.size >= 2) {
            routeCoordinates.map { LatLng(it.first, it.second) }
        } else {
            markers
                .filter { it.sequenceNumber != null }
                .sortedBy { it.sequenceNumber }
                .map { LatLng(it.latitude, it.longitude) }
        }

        if (polylinePoints.size >= 2) {
            map.addPolyline(
                PolylineOptions()
                    .addAll(polylinePoints)
                    .color(0xFF2563EB.toInt())
                    .width(5f)
            )
        }
    }
}
