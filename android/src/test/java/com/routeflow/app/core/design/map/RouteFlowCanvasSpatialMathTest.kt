package com.routeflow.app.core.design.map

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteFlowCanvasSpatialMathTest {

    private fun createMarker(
        id: String,
        title: String,
        lat: Double,
        lng: Double
    ) = LogisticsMarker(
        id = id,
        title = title,
        latitude = lat,
        longitude = lng,
        type = LogisticsMarkerType.RETAILER
    )

    @Test
    fun computeBoundingBox_withValidCoordinates_calculatesSpanCorrectly() {
        val markers = listOf(
            createMarker("1", "Jaipur A", 26.85, 75.76),
            createMarker("2", "Delhi B", 28.61, 77.21)
        )

        val bounds = RouteFlowCanvasSpatialMath.computeBoundingBox(markers)

        assertEquals(26.85, bounds.minLat, 0.0001)
        assertEquals(28.61, bounds.maxLat, 0.0001)
        assertEquals(75.76, bounds.minLng, 0.0001)
        assertEquals(77.21, bounds.maxLng, 0.0001)
    }

    @Test
    fun computeBoundingBox_filtersInvalidCoordinates() {
        val markers = listOf(
            createMarker("1", "Valid Stop", 26.90, 75.80),
            createMarker("2", "Invalid Stop", 0.0, 0.0)
        )

        val bounds = RouteFlowCanvasSpatialMath.computeBoundingBox(markers)

        assertEquals(26.8975, bounds.minLat, 0.0001)
        assertEquals(26.9025, bounds.maxLat, 0.0001)
        assertEquals(75.7975, bounds.minLng, 0.0001)
        assertEquals(75.8025, bounds.maxLng, 0.0001)
    }

    @Test
    fun projectCoordinates_invertsLatitude_soNorthIsUp() {
        val bounds = CanvasBoundingBox(
            minLat = 20.0,
            maxLat = 30.0,
            minLng = 70.0,
            maxLng = 80.0
        )

        // North point (higher latitude) should have smaller Y on screen (higher up)
        val north = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 29.0,
            lng = 75.0,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )

        // South point (lower latitude) should have larger Y on screen (further down)
        val south = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 21.0,
            lng = 75.0,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )

        assertTrue("North Y (${north.y}) must be less than South Y (${south.y})", north.y < south.y)
    }

    @Test
    fun projectCoordinates_scalesAndPansCorrectly() {
        val bounds = CanvasBoundingBox(20.0, 30.0, 70.0, 80.0)
        val p1 = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 25.0,
            lng = 75.0,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )

        val p2Pan = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 25.0,
            lng = 75.0,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset(50f, -30f)
        )

        assertEquals(p1.x + 50f, p2Pan.x, 0.01f)
        assertEquals(p1.y - 30f, p2Pan.y, 0.01f)
    }

    @Test
    fun hitTestMarker_detectsHitWithinRadius() {
        val markerA = createMarker("A", "Shop A", 26.85, 75.76)
        val markerB = createMarker("B", "Shop B", 28.61, 77.21)

        val markerPositions = mapOf(
            "A" to Offset(300f, 400f),
            "B" to Offset(700f, 800f)
        )

        val hit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = Offset(310f, 410f), // ~14px distance
            markerPositions = markerPositions,
            validMarkers = listOf(markerA, markerB),
            touchRadiusPx = 36f
        )

        assertNotNull(hit)
        assertEquals("A", hit?.id)
    }

    @Test
    fun hitTestMarker_returnsNullOnEmptyCanvasTap() {
        val markerA = createMarker("A", "Shop A", 26.85, 75.76)
        val markerPositions = mapOf("A" to Offset(300f, 400f))

        val hit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = Offset(500f, 500f), // >200px distance
            markerPositions = markerPositions,
            validMarkers = listOf(markerA),
            touchRadiusPx = 36f
        )

        assertNull("Tap on empty canvas must not select any marker", hit)
    }

    @Test
    fun hitTestMarker_withProjection_selectsNearestMarker() {
        val bounds = CanvasBoundingBox(26.0, 27.0, 75.0, 76.0)
        // Two markers near each other
        val markerA = createMarker("A", "Near Stop", 26.500, 75.500)
        val markerB = createMarker("B", "Slightly Further Stop", 26.502, 75.502)

        val posA = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = markerA.latitude,
            lng = markerA.longitude,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )

        // Tap offset is 5px away from A, but further from B
        val tapOffset = Offset(posA.x + 5f, posA.y + 5f)

        val hit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = tapOffset,
            markers = listOf(markerA, markerB),
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero,
            touchRadiusPx = 50f
        )

        assertNotNull(hit)
        assertEquals("A", hit?.id)
    }

    @Test
    fun hitTestMarker_withOverlappingMarkers_cyclesOnRepeatedTap() {
        val bounds = CanvasBoundingBox(26.0, 27.0, 75.0, 76.0)
        // Two overlapping markers at virtually the exact same location
        val marker1 = createMarker("M1", "Shop 1", 26.500, 75.500)
        val marker2 = createMarker("M2", "Shop 2", 26.500, 75.500)

        val pos = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 26.500,
            lng = 75.500,
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )

        // First tap with nothing selected -> selects M1
        val firstHit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = pos,
            markers = listOf(marker1, marker2),
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero,
            touchRadiusPx = 36f,
            selectedMarkerId = null
        )
        assertEquals("M1", firstHit?.id)

        // Second tap with M1 selected -> cycles to M2
        val secondHit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = pos,
            markers = listOf(marker1, marker2),
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero,
            touchRadiusPx = 36f,
            selectedMarkerId = "M1"
        )
        assertEquals("M2", secondHit?.id)

        // Third tap with M2 selected -> cycles back to M1
        val thirdHit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = pos,
            markers = listOf(marker1, marker2),
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 1.0f,
            panOffset = Offset.Zero,
            touchRadiusPx = 36f,
            selectedMarkerId = "M2"
        )
        assertEquals("M1", thirdHit?.id)
    }

    @Test
    fun calculatePinchPan_preservesPointUnderPinchFocus() {
        val bounds = CanvasBoundingBox(20.0, 30.0, 70.0, 80.0)
        val canvasWidth = 1000f
        val canvasHeight = 1000f
        val canvasCenter = Offset(500f, 500f)

        val oldScale = 1.0f
        val oldPan = Offset(20f, -40f)

        // Target point on map before zoom
        val lat = 27.5
        val lng = 76.5
        val screenPosBefore = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = lat,
            lng = lng,
            bounds = bounds,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            scale = oldScale,
            panOffset = oldPan
        )

        // User pinches focused directly on this point and zooms to 2.5x
        val newScale = 2.5f
        val newPan = RouteFlowCanvasSpatialMath.calculatePinchPan(
            oldPan = oldPan,
            oldScale = oldScale,
            newScale = newScale,
            centroid = screenPosBefore,
            canvasCenter = canvasCenter,
            panDelta = Offset.Zero
        )

        // Target point on map after zoom
        val screenPosAfter = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = lat,
            lng = lng,
            bounds = bounds,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            scale = newScale,
            panOffset = newPan
        )

        // Must remain at the exact same screen position
        assertEquals(screenPosBefore.x, screenPosAfter.x, 0.01f)
        assertEquals(screenPosBefore.y, screenPosAfter.y, 0.01f)
    }

    @Test
    fun unprojectCoordinates_invertsProjectCoordinates_precisely() {
        val bounds = CanvasBoundingBox(26.0, 29.0, 75.0, 78.0)
        val canvasWidth = 1080f
        val canvasHeight = 1920f
        val scale = 1.75f
        val panOffset = Offset(120f, -85f)

        val testPoints = listOf(
            Pair(26.5, 75.5),
            Pair(27.0, 76.5),
            Pair(28.2, 77.1),
            Pair(28.9, 77.9)
        )

        for ((origLat, origLng) in testPoints) {
            val projected = RouteFlowCanvasSpatialMath.projectCoordinates(
                lat = origLat,
                lng = origLng,
                bounds = bounds,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
                scale = scale,
                panOffset = panOffset,
                padding = 64f
            )

            val unprojected = RouteFlowCanvasSpatialMath.unprojectCoordinates(
                screenOffset = projected,
                bounds = bounds,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
                scale = scale,
                panOffset = panOffset,
                padding = 64f
            )

            assertEquals("Lat round-trip mismatch", origLat, unprojected.first, 0.0001)
            assertEquals("Lng round-trip mismatch", origLng, unprojected.second, 0.0001)
        }
    }

    @Test
    fun pinchZoom_repeatedCycles_accumulatesZeroDrift() {
        val bounds = CanvasBoundingBox(25.0, 30.0, 74.0, 79.0)
        val canvasCenter = Offset(540f, 960f)
        var currentPan = Offset(30f, -40f)
        var currentScale = 1.0f

        val focalPoints = listOf(
            Offset(200f, 300f),
            Offset(800f, 600f),
            Offset(500f, 1200f),
            Offset(700f, 400f)
        )

        // Repeat zoom in (2.0x) and zoom out (0.5x) cycles across multiple focal points
        for (focalPoint in focalPoints) {
            val initialPanForFocus = currentPan
            val initialScaleForFocus = currentScale

            // Zoom In by 2.0x
            val zoomedScale = currentScale * 2.0f
            val panAfterZoomIn = RouteFlowCanvasSpatialMath.calculatePinchPan(
                oldPan = currentPan,
                oldScale = currentScale,
                newScale = zoomedScale,
                centroid = focalPoint,
                canvasCenter = canvasCenter
            )

            // Zoom back Out by 0.5x (returning to original scale)
            val restoredScale = zoomedScale * 0.5f
            val panAfterZoomOut = RouteFlowCanvasSpatialMath.calculatePinchPan(
                oldPan = panAfterZoomIn,
                oldScale = zoomedScale,
                newScale = restoredScale,
                centroid = focalPoint,
                canvasCenter = canvasCenter
            )

            assertEquals("Scale must return to initial", initialScaleForFocus, restoredScale, 0.0001f)
            assertEquals("Pan X must not accumulate drift", initialPanForFocus.x, panAfterZoomOut.x, 0.01f)
            assertEquals("Pan Y must not accumulate drift", initialPanForFocus.y, panAfterZoomOut.y, 0.01f)

            currentPan = panAfterZoomOut
            currentScale = restoredScale
        }
    }

    @Test
    fun hitTestMarker_afterZoomAndPan_detectsCorrectMarker() {
        val bounds = CanvasBoundingBox(26.0, 28.0, 75.0, 77.0)
        val markerA = createMarker("M_A", "Shop A", 26.50, 75.50)
        val markerB = createMarker("M_B", "Shop B", 27.50, 76.50)
        val canvasWidth = 1000f
        val canvasHeight = 1000f
        val scale = 2.5f
        val panOffset = Offset(150f, -120f)

        val posA = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = markerA.latitude,
            lng = markerA.longitude,
            bounds = bounds,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            scale = scale,
            panOffset = panOffset,
            padding = 64f
        )

        // Tap directly on projected marker A (with slight 5px offset)
        val hitA = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = Offset(posA.x + 5f, posA.y + 5f),
            markers = listOf(markerA, markerB),
            bounds = bounds,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            scale = scale,
            panOffset = panOffset,
            touchRadiusPx = 36f,
            padding = 64f
        )

        assertNotNull("Marker A must be detected under zoom & pan", hitA)
        assertEquals("M_A", hitA?.id)

        // Tap far away from both markers
        val missHit = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = Offset(posA.x + 200f, posA.y + 200f),
            markers = listOf(markerA, markerB),
            bounds = bounds,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            scale = scale,
            panOffset = panOffset,
            touchRadiusPx = 36f,
            padding = 64f
        )
        assertNull("Tap far away must return null", missHit)
    }

    @Test
    fun spatialMath_handlesDegenerateOrInvalidInputsGracefully() {
        val bounds = CanvasBoundingBox(0.0, 0.0, 0.0, 0.0)

        // Zero or negative canvas dimensions
        val posZero = RouteFlowCanvasSpatialMath.projectCoordinates(
            lat = 26.0,
            lng = 75.0,
            bounds = bounds,
            canvasWidth = 0f,
            canvasHeight = 0f,
            scale = 1.0f,
            panOffset = Offset.Zero
        )
        assertNotNull(posZero)

        // Zero or negative scale
        val unprojZeroScale = RouteFlowCanvasSpatialMath.unprojectCoordinates(
            screenOffset = Offset(100f, 100f),
            bounds = bounds,
            canvasWidth = 1000f,
            canvasHeight = 1000f,
            scale = 0f,
            panOffset = Offset.Zero
        )
        assertNotNull(unprojZeroScale)

        // calculatePinchPan with zero scale
        val panZeroScale = RouteFlowCanvasSpatialMath.calculatePinchPan(
            oldPan = Offset(10f, 20f),
            oldScale = 0f,
            newScale = 1.0f,
            centroid = Offset(100f, 100f),
            canvasCenter = Offset(500f, 500f),
            panDelta = Offset(5f, 5f)
        )
        assertEquals(15f, panZeroScale.x, 0.001f)
        assertEquals(25f, panZeroScale.y, 0.001f)

        // hitTestMarker with zero width
        val hitZeroCanvas = RouteFlowCanvasSpatialMath.hitTestMarker(
            tapOffset = Offset(100f, 100f),
            markers = listOf(createMarker("1", "Store", 26.0, 75.0)),
            bounds = bounds,
            canvasWidth = 0f,
            canvasHeight = 0f,
            scale = 1.0f,
            panOffset = Offset.Zero,
            touchRadiusPx = 36f
        )
        assertNull(hitZeroCanvas)
    }
}
