package com.routeflow.app.core.design.map

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
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
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
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
    onZoomChange: (Float) -> Unit = {},
    panOffset: Offset = Offset.Zero,
    onPanChange: (Offset) -> Unit = {}
) {
    val validMarkers = remember(markers) {
        markers.filter { it.hasValidCoordinates }
    }

    // Dynamic bounding box of all coordinates
    val bounds = remember(validMarkers) {
        RouteFlowCanvasSpatialMath.computeBoundingBox(validMarkers)
    }

    // Dynamic density-aware comfortable viewing insets (avoids top headers, floating controls, bottom sheet)
    val density = LocalDensity.current
    val padLeft = with(density) { 48.dp.toPx() }
    val padRight = with(density) { 72.dp.toPx() }
    val padTop = with(density) { 140.dp.toPx() }
    val padBottom = with(density) { 200.dp.toPx() }

    // Keep updated state references for gestures so pointerInput coroutine never captures stale callbacks
    val currentZoom by rememberUpdatedState(zoomLevel)
    val currentPan by rememberUpdatedState(panOffset)
    val currentOnZoomChange by rememberUpdatedState(onZoomChange)
    val currentOnPanChange by rememberUpdatedState(onPanChange)
    val currentOnMarkerSelected by rememberUpdatedState(onMarkerSelected)
    val currentOnDismissSelection by rememberUpdatedState(onDismissSelection)
    val currentSelectedId by rememberUpdatedState(selectedMarkerId)
    val currentMarkers by rememberUpdatedState(validMarkers)
    val currentBounds by rememberUpdatedState(bounds)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFFF1F5F9))
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    val touchSlop = viewConfiguration.touchSlop
                    val touchRadiusPx = 36.dp.toPx()

                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        val startPos = down.position
                        var isDragOrPinch = false

                        do {
                            val event = awaitPointerEvent()
                            val pressedChanges = event.changes.filter { it.pressed }
                            val pointerCount = pressedChanges.size

                            if (pointerCount >= 2) {
                                isDragOrPinch = true
                                val zoomChange = event.calculateZoom()
                                val panChange = event.calculatePan()
                                val centroid = event.calculateCentroid()

                                if (zoomChange != 1f || panChange != Offset.Zero) {
                                    val oldScale = currentZoom
                                    val newScale = (oldScale * zoomChange).coerceIn(0.5f, 4.0f)
                                    val canvasCenter = Offset(size.width / 2f, size.height / 2f)
                                    val newPan = RouteFlowCanvasSpatialMath.calculatePinchPan(
                                        oldPan = currentPan,
                                        oldScale = oldScale,
                                        newScale = newScale,
                                        centroid = centroid,
                                        canvasCenter = canvasCenter,
                                        panDelta = panChange
                                    )
                                    currentOnZoomChange(newScale)
                                    currentOnPanChange(newPan)
                                    event.changes.forEach { it.consume() }
                                }
                            } else if (pointerCount == 1) {
                                val change = pressedChanges.first()
                                val totalMovement = (change.position - startPos).getDistance()

                                if (!isDragOrPinch) {
                                    if (totalMovement > touchSlop) {
                                        isDragOrPinch = true
                                    }
                                }

                                if (isDragOrPinch) {
                                    val panChange = change.positionChange()
                                    if (panChange != Offset.Zero) {
                                        val newPan = currentPan + panChange
                                        currentOnPanChange(newPan)
                                        change.consume()
                                    }
                                }
                            }
                        } while (event.changes.any { it.pressed })

                        if (!isDragOrPinch) {
                            // Discrete single tap at startPos
                            val hit = RouteFlowCanvasSpatialMath.hitTestMarker(
                                tapOffset = startPos,
                                markers = currentMarkers,
                                bounds = currentBounds,
                                canvasWidth = size.width.toFloat(),
                                canvasHeight = size.height.toFloat(),
                                scale = currentZoom,
                                panOffset = currentPan,
                                touchRadiusPx = touchRadiusPx,
                                selectedMarkerId = currentSelectedId,
                                paddingLeft = padLeft,
                                paddingTop = padTop,
                                paddingRight = padRight,
                                paddingBottom = padBottom
                            )
                            if (hit != null) {
                                currentOnMarkerSelected(hit)
                            } else {
                                currentOnDismissSelection()
                            }
                        }
                    }
                }
        ) {
            val canvasWidth = size.width
            val canvasHeight = size.height

            fun project(lat: Double, lng: Double): Offset {
                return RouteFlowCanvasSpatialMath.projectCoordinates(
                    lat = lat,
                    lng = lng,
                    bounds = bounds,
                    canvasWidth = canvasWidth,
                    canvasHeight = canvasHeight,
                    scale = zoomLevel,
                    panOffset = panOffset,
                    paddingLeft = padLeft,
                    paddingTop = padTop,
                    paddingRight = padRight,
                    paddingBottom = padBottom
                )
            }

            // 1. Draw spatial engineering grid
            drawSpatialGrid(size, zoomLevel, panOffset)

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
            for (marker in validMarkers) {
                val pos = project(marker.latitude, marker.longitude)
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

internal data class CanvasBoundingBox(
    val minLat: Double,
    val maxLat: Double,
    val minLng: Double,
    val maxLng: Double
)

internal object RouteFlowCanvasSpatialMath {
    fun computeBoundingBox(markers: List<LogisticsMarker>): CanvasBoundingBox {
        val valid = markers.filter { it.hasValidCoordinates }
        if (valid.isEmpty()) return CanvasBoundingBox(0.0, 0.0, 0.0, 0.0)

        var minLat = valid.first().latitude
        var maxLat = valid.first().latitude
        var minLng = valid.first().longitude
        var maxLng = valid.first().longitude

        for (m in valid) {
            if (m.latitude < minLat) minLat = m.latitude
            if (m.latitude > maxLat) maxLat = m.latitude
            if (m.longitude < minLng) minLng = m.longitude
            if (m.longitude > maxLng) maxLng = m.longitude
        }
        if (maxLat - minLat < 0.005) {
            minLat -= 0.0025
            maxLat += 0.0025
        }
        if (maxLng - minLng < 0.005) {
            minLng -= 0.0025
            maxLng += 0.0025
        }
        return CanvasBoundingBox(minLat, maxLat, minLng, maxLng)
    }

    fun projectCoordinates(
        lat: Double,
        lng: Double,
        bounds: CanvasBoundingBox,
        canvasWidth: Float,
        canvasHeight: Float,
        scale: Float,
        panOffset: Offset,
        paddingLeft: Float,
        paddingTop: Float,
        paddingRight: Float,
        paddingBottom: Float
    ): Offset {
        val availableWidth = max(canvasWidth - paddingLeft - paddingRight, 100f)
        val availableHeight = max(canvasHeight - paddingTop - paddingBottom, 100f)

        val latSpan = max(bounds.maxLat - bounds.minLat, 0.0001)
        val lngSpan = max(bounds.maxLng - bounds.minLng, 0.0001)

        val avgLatRad = Math.toRadians((bounds.minLat + bounds.maxLat) / 2.0)
        val cosLat = max(Math.cos(avgLatRad), 0.1)

        val geoWidth = lngSpan * cosLat
        val geoHeight = latSpan

        val scaleX = (availableWidth / geoWidth).toFloat()
        val scaleY = (availableHeight / geoHeight).toFloat()
        val spatialScale = min(scaleX, scaleY)

        val fittedWidth = (geoWidth * spatialScale).toFloat()
        val fittedHeight = (geoHeight * spatialScale).toFloat()

        val offsetX = paddingLeft + (availableWidth - fittedWidth) / 2f
        val offsetY = paddingTop + (availableHeight - fittedHeight) / 2f

        val relX = (((lng - bounds.minLng) * cosLat) / geoWidth).toFloat()
        val relY = 1.0f - ((lat - bounds.minLat) / latSpan).toFloat()

        val baseX = offsetX + (relX * fittedWidth)
        val baseY = offsetY + (relY * fittedHeight)

        val centerX = canvasWidth / 2f
        val centerY = canvasHeight / 2f

        val scaledX = centerX + (baseX - centerX) * scale + panOffset.x
        val scaledY = centerY + (baseY - centerY) * scale + panOffset.y

        return Offset(scaledX, scaledY)
    }

    fun projectCoordinates(
        lat: Double,
        lng: Double,
        bounds: CanvasBoundingBox,
        canvasWidth: Float,
        canvasHeight: Float,
        scale: Float,
        panOffset: Offset,
        padding: Float = 64f
    ): Offset = projectCoordinates(
        lat = lat,
        lng = lng,
        bounds = bounds,
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight,
        scale = scale,
        panOffset = panOffset,
        paddingLeft = padding,
        paddingTop = padding,
        paddingRight = padding,
        paddingBottom = padding
    )

    fun calculatePinchPan(
        oldPan: Offset,
        oldScale: Float,
        newScale: Float,
        centroid: Offset,
        canvasCenter: Offset,
        panDelta: Offset = Offset.Zero
    ): Offset {
        if (oldScale <= 0f) return oldPan + panDelta
        val zoomRatio = newScale / oldScale
        val focusOffset = centroid - canvasCenter
        return (oldPan * zoomRatio) + (focusOffset * (1f - zoomRatio)) + panDelta
    }

    fun hitTestMarker(
        tapOffset: Offset,
        markers: List<LogisticsMarker>,
        bounds: CanvasBoundingBox,
        canvasWidth: Float,
        canvasHeight: Float,
        scale: Float,
        panOffset: Offset,
        touchRadiusPx: Float,
        selectedMarkerId: String? = null,
        paddingLeft: Float,
        paddingTop: Float,
        paddingRight: Float,
        paddingBottom: Float
    ): LogisticsMarker? {
        val valid = markers.filter { it.hasValidCoordinates }
        if (valid.isEmpty() || canvasWidth <= 0f || canvasHeight <= 0f) return null

        val candidates = valid.mapNotNull { marker ->
            val pos = projectCoordinates(
                lat = marker.latitude,
                lng = marker.longitude,
                bounds = bounds,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
                scale = scale,
                panOffset = panOffset,
                paddingLeft = paddingLeft,
                paddingTop = paddingTop,
                paddingRight = paddingRight,
                paddingBottom = paddingBottom
            )
            val dist = (pos - tapOffset).getDistance()
            if (dist <= touchRadiusPx) {
                Pair(marker, dist)
            } else {
                null
            }
        }.sortedBy { it.second }

        if (candidates.isEmpty()) return null

        val candidateMarkers = candidates.map { it.first }

        if (candidateMarkers.size > 1 && selectedMarkerId != null) {
            val currentIndex = candidateMarkers.indexOfFirst { it.id == selectedMarkerId }
            if (currentIndex != -1) {
                val nextIndex = (currentIndex + 1) % candidateMarkers.size
                return candidateMarkers[nextIndex]
            }
        }

        return candidateMarkers.first()
    }

    fun hitTestMarker(
        tapOffset: Offset,
        markers: List<LogisticsMarker>,
        bounds: CanvasBoundingBox,
        canvasWidth: Float,
        canvasHeight: Float,
        scale: Float,
        panOffset: Offset,
        touchRadiusPx: Float,
        selectedMarkerId: String? = null,
        padding: Float = 64f
    ): LogisticsMarker? = hitTestMarker(
        tapOffset = tapOffset,
        markers = markers,
        bounds = bounds,
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight,
        scale = scale,
        panOffset = panOffset,
        touchRadiusPx = touchRadiusPx,
        selectedMarkerId = selectedMarkerId,
        paddingLeft = padding,
        paddingTop = padding,
        paddingRight = padding,
        paddingBottom = padding
    )

    fun hitTestMarker(
        tapOffset: Offset,
        markerPositions: Map<String, Offset>,
        validMarkers: List<LogisticsMarker>,
        touchRadiusPx: Float
    ): LogisticsMarker? {
        return validMarkers
            .mapNotNull { marker ->
                val pos = markerPositions[marker.id] ?: return@mapNotNull null
                val dist = (pos - tapOffset).getDistance()
                if (dist <= touchRadiusPx) Pair(marker, dist) else null
            }
            .minByOrNull { it.second }
            ?.first
    }
}

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
