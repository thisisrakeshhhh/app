package com.routeflow.app.poc

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.LogisticsMarker
import com.routeflow.app.core.design.map.LogisticsMarkerStatus
import com.routeflow.app.core.design.map.LogisticsMarkerType
import com.routeflow.app.core.design.map.RouteFlowLogisticsCanvasMap
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import java.io.File
import java.io.FileInputStream

/**
 * Validation result stages for the PMTiles archive.
 * Explicitly separates:
 * 1. File existence
 * 2. 127-byte Header parsing & compression checks (does NOT guarantee tiles render)
 * 3. Style loading & engine initialization
 * 4. Actual visual tile rendering (requires on-device visual verification)
 */
sealed interface PocArchiveValidation {
    data class Missing(val path: String) : PocArchiveValidation
    data class Corrupt(val path: String, val reason: String) : PocArchiveValidation
    data class Valid(
        val path: String,
        val version: Int,
        val internalCompression: String,
        val tileCompression: String,
        val tileType: String,
        val minZoom: Int,
        val maxZoom: Int
    ) : PocArchiveValidation
}

/**
 * Inspects the 127-byte PMTiles v3 binary header strictly according to PMTiles v3 specification.
 *
 * Specific field offsets in PMTiles v3:
 * - Bytes 0..6: ASCII "PMTiles" (7 bytes)
 * - Byte 7: Version uint8 (must be 3)
 * - Bytes 8..15: Root Directory Offset uint64
 * - Bytes 16..23: Root Directory Length uint64
 * - Byte 97 (0x61): Internal Directory/Metadata Compression (1=none, 2=gzip, 3=brotli, 4=zstd)
 * - Byte 98 (0x62): Tile Payload Compression (1=none, 2=gzip, 3=brotli, 4=zstd)
 * - Byte 99 (0x63): Tile Type (1=MVT vector, 2=PNG, 3=JPEG, 4=WEBP, 5=AVIF, 6=MLT)
 * - Byte 100 (0x64): Min Zoom uint8
 * - Byte 101 (0x65): Max Zoom uint8
 *
 * NOTE: A valid header proves file format compliance only; it does NOT prove
 * that internal tile payloads or coordinate geometries are readable without rendering errors.
 */
object PocPmtilesHeaderInspector {
    fun inspect(file: File): PocArchiveValidation {
        if (!file.exists()) {
            return PocArchiveValidation.Missing(file.absolutePath)
        }
        if (file.length() < 127) {
            return PocArchiveValidation.Corrupt(
                file.absolutePath,
                "File length (${file.length()} bytes) is less than the required 127-byte PMTiles header."
            )
        }

        try {
            FileInputStream(file).use { stream ->
                val header = ByteArray(127)
                var bytesRead = 0
                while (bytesRead < 127) {
                    val count = stream.read(header, bytesRead, 127 - bytesRead)
                    if (count < 0) break
                    bytesRead += count
                }
                if (bytesRead < 127) {
                    return PocArchiveValidation.Corrupt(file.absolutePath, "Incomplete read of 127-byte header.")
                }

                // 1. Magic bytes (0..6)
                val magic = String(header, 0, 7, Charsets.US_ASCII)
                if (magic != "PMTiles") {
                    return PocArchiveValidation.Corrupt(file.absolutePath, "Invalid magic bytes: '$magic' (expected 'PMTiles').")
                }

                // 2. Version (byte 7)
                val version = header[7].toInt() and 0xFF
                if (version != 3) {
                    return PocArchiveValidation.Corrupt(file.absolutePath, "Unsupported PMTiles version: $version (expected v3).")
                }

                // 3. Internal Directory & Metadata Compression (byte 97)
                val internalCompressionCode = header[97].toInt() and 0xFF
                val internalCompression = when (internalCompressionCode) {
                    1 -> "none (1)"
                    2 -> "gzip (2)"
                    3 -> "brotli (3) [UNSUPPORTED]"
                    4 -> "zstd (4) [PROVISIONAL / UNSUPPORTED]"
                    else -> "unknown ($internalCompressionCode)"
                }

                // 4. Tile Payload Compression (byte 98)
                val tileCompressionCode = header[98].toInt() and 0xFF
                val tileCompression = when (tileCompressionCode) {
                    1 -> "none (1)"
                    2 -> "gzip (2)"
                    3 -> "brotli (3) [UNSUPPORTED]"
                    4 -> "zstd (4) [PROVISIONAL / UNSUPPORTED]"
                    else -> "unknown ($tileCompressionCode)"
                }

                // 5. Tile Type (byte 99)
                val tileTypeCode = header[99].toInt() and 0xFF
                val tileType = when (tileTypeCode) {
                    1 -> "MVT Vector (1)"
                    2 -> "PNG Raster (2)"
                    3 -> "JPEG Raster (3)"
                    4 -> "WEBP Raster (4)"
                    5 -> "AVIF (5)"
                    6 -> "MLT (6)"
                    else -> "Type ($tileTypeCode)"
                }

                val minZoom = header[100].toInt() and 0xFF
                val maxZoom = header[101].toInt() and 0xFF

                // Check internal compression: MapLibre 11.8.8 supports gzip or none
                if (internalCompressionCode != 1 && internalCompressionCode != 2) {
                    return PocArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Internal directory compression '$internalCompression' is unsupported by MapLibre 11.8.8 (requires gzip or none)."
                    )
                }

                // Check tile payload compression: MapLibre 11.8.8 supports gzip or none
                if (tileCompressionCode != 1 && tileCompressionCode != 2) {
                    return PocArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Tile payload compression '$tileCompression' is unsupported by MapLibre 11.8.8 (requires gzip or none)."
                    )
                }

                // Check tile type: Must be MVT Vector (1)
                if (tileTypeCode != 1) {
                    return PocArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Archive tile type '$tileType' is not MVT Vector (spec code 1)."
                    )
                }

                return PocArchiveValidation.Valid(
                    path = file.absolutePath,
                    version = version,
                    internalCompression = internalCompression,
                    tileCompression = tileCompression,
                    tileType = tileType,
                    minZoom = minZoom,
                    maxZoom = maxZoom
                )
            }
        } catch (e: Exception) {
            return PocArchiveValidation.Corrupt(file.absolutePath, "I/O error inspecting header: ${e.message}")
        }
    }
}

/**
 * Builds a strict local-only style JSON referencing the local PMTiles file.
 * Avoids all remote network dependencies (no remote glyphs, no remote tile URLs, no remote sprites).
 */
object PocLocalStyleBuilder {
    fun build(pmtilesAbsolutePath: String): String {
        return """
        {
          "version": 8,
          "name": "RouteFlow Offline Local PoC",
          "sources": {
            "openmaptiles": {
              "type": "vector",
              "url": "pmtiles://file://$pmtilesAbsolutePath"
            }
          },
          "layers": [
            {
              "id": "background",
              "type": "background",
              "paint": {
                "background-color": "#f1f5f9"
              }
            },
            {
              "id": "water",
              "type": "fill",
              "source": "openmaptiles",
              "source-layer": "water",
              "paint": {
                "fill-color": "#93c5fd"
              }
            },
            {
              "id": "buildings",
              "type": "fill",
              "source": "openmaptiles",
              "source-layer": "buildings",
              "paint": {
                "fill-color": "#e2e8f0",
                "fill-outline-color": "#cbd5e1"
              }
            },
            {
              "id": "transportation",
              "type": "line",
              "source": "openmaptiles",
              "source-layer": "transportation",
              "paint": {
                "line-color": "#64748b",
                "line-width": 1.5
              }
            },
            {
              "id": "roads",
              "type": "line",
              "source": "openmaptiles",
              "source-layer": "roads",
              "paint": {
                "line-color": "#475569",
                "line-width": 2.0
              }
            }
          ]
        }
        """.trimIndent()
    }
}

/**
 * Isolated Proof-of-Concept Harness for MapLibre Native PMTiles validation.
 *
 * Distinct validation stages reported:
 * 1. File presence
 * 2. PMTiles v3 binary header & compression validation (bytes 97, 98, 99)
 * 3. MapLibre SDK initialization, MapView lifecycle management, & style load callback
 * 4. Failure diagnostics via addOnDidFailLoadingMapListener with programmatic canvas fallback
 */
@Composable
fun MapLibrePocHarness(
    archiveFile: File,
    modifier: Modifier = Modifier,
    sampleMarkers: List<LogisticsMarker> = defaultSampleMarkers()
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Stage 1 & 2: Pre-flight validation
    val validation = remember(archiveFile) {
        PocPmtilesHeaderInspector.inspect(archiveFile)
    }

    var styleLoadState by remember { mutableStateOf<String>("Initializing map engine...") }
    var styleLoadSuccess by remember { mutableStateOf(false) }
    var terminalError by remember { mutableStateOf<String?>(null) }
    var selectedMarkerId by remember { mutableStateOf<String?>(null) }

    // MapView is created and remembered when validation succeeds
    val mapView = remember(validation) {
        if (validation is PocArchiveValidation.Valid) {
            MapLibre.getInstance(context)
            MapView(context).apply {
                onCreate(null)
            }
        } else {
            null
        }
    }

    // Lifecycle forwarding and failure listener attachment
    DisposableEffect(mapView, lifecycleOwner) {
        if (mapView == null) return@DisposableEffect onDispose {}

        val failListener = MapView.OnDidFailLoadingMapListener { errorMessage ->
            terminalError = "MapLibre Load Failure: $errorMessage"
            styleLoadState = "Failed: $errorMessage"
        }
        mapView.addOnDidFailLoadingMapListener(failListener)

        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                Lifecycle.Event.ON_DESTROY -> {
                    // Handled safely in onDispose
                }
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.removeOnDidFailLoadingMapListener(failListener)
            mapView.onDestroy()
        }
    }

    // Active map rendering: only when archive is valid AND no terminal loading error occurred
    val isMapActive = validation is PocArchiveValidation.Valid && terminalError == null

    Box(modifier = modifier.fillMaxSize()) {
        if (isMapActive && mapView != null) {
            // Stage 3: MapLibre MapView hosting
            AndroidView(
                factory = {
                    mapView.apply {
                        getMapAsync { map ->
                            val styleJson = PocLocalStyleBuilder.build((validation as PocArchiveValidation.Valid).path)
                            map.setStyle(Style.Builder().fromJson(styleJson)) { _ ->
                                styleLoadSuccess = true
                                styleLoadState = "Style Loaded Successfully (PMTiles linked)"
                            }
                            map.cameraPosition = CameraPosition.Builder()
                                .target(LatLng(26.9124, 75.7873)) // Jaipur Logistics Center
                                .zoom(12.0)
                                .build()
                        }
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            // Stage 4: Programmatic fallback to the existing RouteFlowLogisticsCanvasMap
            RouteFlowLogisticsCanvasMap(
                markers = sampleMarkers,
                selectedMarkerId = selectedMarkerId,
                onMarkerSelected = { selectedMarkerId = it.id },
                onDismissSelection = { selectedMarkerId = null },
                modifier = Modifier.fillMaxSize()
            )
        }

        // Diagnostic Stage Status Overlay
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = Color.White.copy(alpha = 0.95f),
            shadowElevation = 6.dp,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 48.dp, start = 16.dp, end = 16.dp)
                .fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = "MapLibre PMTiles PoC Diagnostics",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Spacer(modifier = Modifier.height(6.dp))

                when (validation) {
                    is PocArchiveValidation.Valid -> {
                        DiagnosticRow(
                            icon = Icons.Default.CheckCircle,
                            tint = Color(0xFF16A34A),
                            label = "Archive File",
                            value = "Found (${archiveFile.name})"
                        )
                        DiagnosticRow(
                            icon = Icons.Default.CheckCircle,
                            tint = Color(0xFF16A34A),
                            label = "Header (PMTiles v${validation.version})",
                            value = "Dir: ${validation.internalCompression} | Tile: ${validation.tileCompression} (Z${validation.minZoom}-${validation.maxZoom})"
                        )

                        if (terminalError != null) {
                            DiagnosticRow(
                                icon = Icons.Default.ErrorOutline,
                                tint = Color(0xFFDC2626),
                                label = "Engine Error",
                                value = terminalError ?: "Unknown error"
                            )
                            DiagnosticRow(
                                icon = Icons.Default.CheckCircle,
                                tint = Color(0xFF16A34A),
                                label = "Fallback Mode",
                                value = "Active (RouteFlowLogisticsCanvasMap)"
                            )
                        } else {
                            DiagnosticRow(
                                icon = if (styleLoadSuccess) Icons.Default.CheckCircle else Icons.Default.Info,
                                tint = if (styleLoadSuccess) Color(0xFF16A34A) else Color(0xFF2563EB),
                                label = "MapLibre Style",
                                value = styleLoadState
                            )
                            DiagnosticRow(
                                icon = Icons.Default.Info,
                                tint = Color(0xFFB45309),
                                label = "Tile Rendering",
                                value = "Awaiting physical visual confirmation"
                            )
                        }
                    }
                    is PocArchiveValidation.Missing -> {
                        DiagnosticRow(
                            icon = Icons.Default.Warning,
                            tint = Color(0xFFD97706),
                            label = "Archive File",
                            value = "Not Found at ${validation.path}"
                        )
                        DiagnosticRow(
                            icon = Icons.Default.CheckCircle,
                            tint = Color(0xFF16A34A),
                            label = "Fallback Mode",
                            value = "Active (RouteFlowLogisticsCanvasMap)"
                        )
                    }
                    is PocArchiveValidation.Corrupt -> {
                        DiagnosticRow(
                            icon = Icons.Default.ErrorOutline,
                            tint = Color(0xFFDC2626),
                            label = "Validation Error",
                            value = validation.reason
                        )
                        DiagnosticRow(
                            icon = Icons.Default.CheckCircle,
                            tint = Color(0xFF16A34A),
                            label = "Fallback Mode",
                            value = "Active (RouteFlowLogisticsCanvasMap)"
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DiagnosticRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    label: String,
    value: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(vertical = 2.dp)
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = "$label: ",
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = RFColors.TextPrimary
        )
        Text(
            text = value,
            fontSize = 12.sp,
            color = RFColors.TextSecondary,
            maxLines = 2
        )
    }
}

private fun defaultSampleMarkers(): List<LogisticsMarker> = listOf(
    LogisticsMarker(
        id = "sample_jaipur_1",
        title = "Jaipur Wholesale Depot",
        latitude = 26.9124,
        longitude = 75.7873,
        type = LogisticsMarkerType.RETAILER,
        status = LogisticsMarkerStatus.PENDING,
        address = "M.I. Road, Jaipur"
    ),
    LogisticsMarker(
        id = "sample_jaipur_2",
        title = "Mansarovar Distribution Hub",
        latitude = 26.8524,
        longitude = 75.7612,
        type = LogisticsMarkerType.RETAILER,
        status = LogisticsMarkerStatus.VISITED,
        address = "Mansarovar Sector 5, Jaipur"
    )
)
