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
}
