package com.routeflow.app.core.design.map

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import kotlin.math.max
import kotlin.math.min

/**
 * Honest, interactive vector spatial plane for RouteFlow.
 * Used when Google Maps API key is missing or in offline/air-gapped field operations.
 *
 * Mathematically projects real GPS coordinates (latitude, longitude) onto a 2D coordinate system.
 * Renders spatial grid, sequence polylines, vector marker nodes, and supports pan/zoom/tap.
 * Strictly avoids faking road geometries or inventing coordinates.
 */
@Composable
fun RouteFlowLogisticsCanvasMap(
    markers: List<LogisticsMarker>,
    selectedMarkerId: String?,
    onMarkerSelected: (LogisticsMarker) -> Unit,
    onDismissSelection: () -> Unit,
    modifier: Modifier = Modifier,
    zoomLevel: Float = 1.0f,
    onZoomChange: (Float) -> Unit = {}
) {
    val validMarkers = remember(markers) {
        markers.filter { it.hasValidCoordinates }
    }

    // Dynamic bounding box of all coordinates
    val bounds = remember(validMarkers) {
        if (validMarkers.isEmpty()) {
            BoundingBox(0.0, 0.0, 0.0, 0.0)
        } else {
            var minLat = validMarkers.first().latitude
            var maxLat = validMarkers.first().latitude
            var minLng = validMarkers.first().longitude
            var maxLng = validMarkers.first().longitude

            for (m in validMarkers) {
                if (m.latitude < minLat) minLat = m.latitude
                if (m.latitude > maxLat) maxLat = m.latitude
                if (m.longitude < minLng) minLng = m.longitude
                if (m.longitude > maxLng) maxLng = m.longitude
            }
            // Ensure bounds has some non-zero span for single points
            if (maxLat - minLat < 0.005) {
                minLat -= 0.0025
                maxLat += 0.0025
            }
            if (maxLng - minLng < 0.005) {
                minLng -= 0.0025
                maxLng += 0.0025
            }
            BoundingBox(minLat, maxLat, minLng, maxLng)
        }
    }

    var panOffset by remember { mutableStateOf(Offset.Zero) }
    var scale by remember { mutableStateOf(1f) }

    // Sync external zoomLevel with internal scale
    LaunchedEffect(zoomLevel) {
        if (scale != zoomLevel && zoomLevel > 0f) {
            scale = zoomLevel
        }
    }

    val transformState = rememberTransformableState { zoomChange, offsetChange, _ ->
        val newScale = (scale * zoomChange).coerceIn(0.5f, 4.0f)
        scale = newScale
        panOffset += offsetChange
        onZoomChange(newScale)
    }

    // Keep screen-space projection positions for hit-testing tap gestures
    val markerScreenPositions = remember { mutableStateMapOf<String, Offset>() }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFFF1F5F9))
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .transformable(state = transformState)
                .pointerInput(validMarkers, selectedMarkerId) {
                    detectTapGestures { tapOffset ->
                        // Hit-test markers with a 32dp touch radius
                        val touchRadiusPx = 36.dp.toPx()
                        val hit = validMarkers.firstOrNull { marker ->
                            val pos = markerScreenPositions[marker.id]
                            pos != null && (pos - tapOffset).getDistance() <= touchRadiusPx
                        }
                        if (hit != null) {
                            onMarkerSelected(hit)
                        } else {
                            onDismissSelection()
                        }
                    }
                }
        ) {
            val canvasWidth = size.width
            val canvasHeight = size.height

            val padding = 64f
            val availableWidth = canvasWidth - (padding * 2)
            val availableHeight = canvasHeight - (padding * 2)

            val latSpan = max(bounds.maxLat - bounds.minLat, 0.0001)
            val lngSpan = max(bounds.maxLng - bounds.minLng, 0.0001)

            fun project(lat: Double, lng: Double): Offset {
                // Invert latitude so North is up (-Y)
                val relX = ((lng - bounds.minLng) / lngSpan).toFloat()
                val relY = 1.0f - ((lat - bounds.minLat) / latSpan).toFloat()

                val baseX = padding + (relX * availableWidth)
                val baseY = padding + (relY * availableHeight)

                // Apply zoom scale around center and pan offset
                val centerX = canvasWidth / 2f
                val centerY = canvasHeight / 2f

                val scaledX = centerX + (baseX - centerX) * scale + panOffset.x
                val scaledY = centerY + (baseY - centerY) * scale + panOffset.y

                return Offset(scaledX, scaledY)
            }

            // 1. Draw spatial engineering grid
            drawSpatialGrid(size, scale, panOffset)

            // 2. Draw route polylines between sequence delivery stops
            val orderedStops = validMarkers
                .filter { it.sequenceNumber != null }
                .sortedBy { it.sequenceNumber }

            if (orderedStops.size >= 2) {
                val polylinePath = Path()
                orderedStops.forEachIndexed { index, stop ->
                    val pos = project(stop.latitude, stop.longitude)
                    if (index == 0) polylinePath.moveTo(pos.x, pos.y)
                    else polylinePath.lineTo(pos.x, pos.y)
                }
                drawPath(
                    path = polylinePath,
                    color = Color(0xFF2563EB),
                    style = Stroke(
                        width = 4.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(18f, 10f), 0f)
                    )
                )
            }

            // 3. Draw each marker node
            markerScreenPositions.clear()
            for (marker in validMarkers) {
                val pos = project(marker.latitude, marker.longitude)
                markerScreenPositions[marker.id] = pos
                val isSelected = marker.id == selectedMarkerId

                drawMarkerNode(
                    marker = marker,
                    position = pos,
                    isSelected = isSelected,
                    drawScope = this
                )
            }
        }

        // Top honest disclaimer & spatial coverage pill
        Surface(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 12.dp, start = 16.dp, end = 16.dp),
            shape = RoundedCornerShape(20.dp),
            color = Color(0xFF1E293B).copy(alpha = 0.92f),
            shadowElevation = 3.dp
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color(0xFF38BDF8),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = if (validMarkers.isEmpty()) {
                        "No valid GPS coordinates mapped"
                    } else {
                        "Logistics Spatial View • ${validMarkers.size} stops plotted"
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Compass Rose indicator in top right
        Surface(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 12.dp, end = 16.dp),
            shape = CircleShape,
            color = Color.White.copy(alpha = 0.9f),
            shadowElevation = 2.dp
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .padding(4.dp),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Navigation,
                    contentDescription = "North",
                    tint = RFColors.Primary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

private data class BoundingBox(
    val minLat: Double,
    val maxLat: Double,
    val minLng: Double,
    val maxLng: Double
)

private fun DrawScope.drawSpatialGrid(size: Size, scale: Float, panOffset: Offset) {
    val gridColor = Color(0xFFE2E8F0)
    val step = 48.dp.toPx() * scale.coerceIn(0.8f, 2.0f)

    var x = (panOffset.x % step)
    while (x < size.width) {
        if (x >= 0) {
            drawLine(
                color = gridColor,
                start = Offset(x, 0f),
                end = Offset(x, size.height),
                strokeWidth = 1f
            )
        }
        x += step
    }

    var y = (panOffset.y % step)
    while (y < size.height) {
        if (y >= 0) {
            drawLine(
                color = gridColor,
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = 1f
            )
        }
        y += step
    }
}

private fun drawMarkerNode(
    marker: LogisticsMarker,
    position: Offset,
    isSelected: Boolean,
    drawScope: DrawScope
) {
    with(drawScope) {
        val baseRadius = if (isSelected) 18.dp.toPx() else 14.dp.toPx()

        // Status-based colors
        val pinColor = when (marker.status) {
            LogisticsMarkerStatus.COMPLETED, LogisticsMarkerStatus.VISITED -> Color(0xFF16A34A)
            LogisticsMarkerStatus.IN_PROGRESS -> Color(0xFF2563EB)
            LogisticsMarkerStatus.ALERT -> Color(0xFFDC2626)
            LogisticsMarkerStatus.UNVISITED, LogisticsMarkerStatus.PENDING -> Color(0xFFD97706)
        }

        // Selection highlight ring
        if (isSelected) {
            drawCircle(
                color = pinColor.copy(alpha = 0.25f),
                radius = baseRadius + 10.dp.toPx(),
                center = position
            )
            drawCircle(
                color = pinColor.copy(alpha = 0.5f),
                radius = baseRadius + 4.dp.toPx(),
                center = position,
                style = Stroke(width = 2.dp.toPx())
            )
        }

        // Outer white border
        drawCircle(
            color = Color.White,
            radius = baseRadius + 2.dp.toPx(),
            center = position
        )

        // Main colored circle
        drawCircle(
            color = pinColor,
            radius = baseRadius,
            center = position
        )

        // Text label (stop sequence number or dot)
        val textPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE
            textSize = (if (isSelected) 13.sp else 11.sp).toPx()
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlign = android.graphics.Paint.Align.CENTER
            isAntiAlias = true
        }

        val label = marker.sequenceNumber?.toString() ?: ""
        if (label.isNotEmpty()) {
            val yOffset = ((textPaint.descent() + textPaint.ascent()) / 2f)
            drawContext.canvas.nativeCanvas.drawText(
                label,
                position.x,
                position.y - yOffset,
                textPaint
            )
        } else {
            // Inner white dot
            drawCircle(
                color = Color.White,
                radius = 4.dp.toPx(),
                center = position
            )
        }

        // Draw title badge under marker
        val titlePaint = android.graphics.Paint().apply {
            color = android.graphics.Color.DKGRAY
            textSize = 10.sp.toPx()
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            textAlign = android.graphics.Paint.Align.CENTER
            isAntiAlias = true
        }

        val shortTitle = if (marker.title.length > 14) {
            marker.title.take(12) + "…"
        } else {
            marker.title
        }

        drawContext.canvas.nativeCanvas.drawText(
            shortTitle,
            position.x,
            position.y + baseRadius + 14.dp.toPx(),
            titlePaint
        )
    }
}
