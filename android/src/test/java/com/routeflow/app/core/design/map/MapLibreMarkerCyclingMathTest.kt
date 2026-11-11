package com.routeflow.app.core.design.map

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MapLibreMarkerCyclingMathTest {

    private fun createMarker(id: String, lat: Double, lng: Double): LogisticsMarker {
        return LogisticsMarker(
            id = id,
            title = "Stop $id",
            latitude = lat,
            longitude = lng,
            type = LogisticsMarkerType.RETAILER,
            status = LogisticsMarkerStatus.PENDING
        )
    }

    @Test
    fun findMarkerHit_whenNoMarkers_returnsNull() {
        val tap = MapLibreMarkerCyclingMath.ScreenPoint(100f, 100f)
        val result = MapLibreMarkerCyclingMath.findMarkerHit(
            tapPoint = tap,
            projectedMarkers = emptyList(),
            touchRadiusPx = 36f,
            currentSelectedMarkerId = null
        )
        assertNull(result)
    }

    @Test
    fun findMarkerHit_whenTapIsOutsideRadius_returnsNull() {
        val marker = createMarker("m1", 26.9, 75.8)
        val point = MapLibreMarkerCyclingMath.ScreenPoint(100f, 100f)
        val tap = MapLibreMarkerCyclingMath.ScreenPoint(200f, 200f) // ~141px away (>36px)

        val result = MapLibreMarkerCyclingMath.findMarkerHit(
            tapPoint = tap,
            projectedMarkers = listOf(marker to point),
            touchRadiusPx = 36f,
            currentSelectedMarkerId = null
        )
        assertNull(result)
    }

    @Test
    fun findMarkerHit_whenSingleMarkerWithinRadius_returnsMarker() {
        val marker = createMarker("m1", 26.9, 75.8)
        val point = MapLibreMarkerCyclingMath.ScreenPoint(100f, 100f)
        val tap = MapLibreMarkerCyclingMath.ScreenPoint(110f, 105f) // distance ~11.18px (< 36px)

        val result = MapLibreMarkerCyclingMath.findMarkerHit(
            tapPoint = tap,
            projectedMarkers = listOf(marker to point),
            touchRadiusPx = 36f,
            currentSelectedMarkerId = null
        )
        assertEquals(marker, result)
    }

    @Test
    fun findMarkerHit_whenOverlappingMarkers_cyclesThroughThemDeterministically() {
        val m1 = createMarker("m1", 26.900, 75.800)
        val m2 = createMarker("m2", 26.900, 75.800)
        val m3 = createMarker("m3", 26.901, 75.801)

        val pt1 = MapLibreMarkerCyclingMath.ScreenPoint(200f, 300f)
        val pt2 = MapLibreMarkerCyclingMath.ScreenPoint(202f, 298f) // within ~3px
        val pt3 = MapLibreMarkerCyclingMath.ScreenPoint(205f, 305f) // within ~7px

        val projected = listOf(m1 to pt1, m2 to pt2, m3 to pt3)
        val tap = MapLibreMarkerCyclingMath.ScreenPoint(200f, 300f)

        // 1. Initial tap when nothing selected -> returns first candidate (m1)
        val hit1 = MapLibreMarkerCyclingMath.findMarkerHit(tap, projected, 36f, null)
        assertEquals("m1", hit1?.id)

        // 2. Second tap when m1 selected -> cycles to m2
        val hit2 = MapLibreMarkerCyclingMath.findMarkerHit(tap, projected, 36f, "m1")
        assertEquals("m2", hit2?.id)

        // 3. Third tap when m2 selected -> cycles to m3
        val hit3 = MapLibreMarkerCyclingMath.findMarkerHit(tap, projected, 36f, "m2")
        assertEquals("m3", hit3?.id)

        // 4. Fourth tap when m3 selected -> wraps around back to m1
        val hit4 = MapLibreMarkerCyclingMath.findMarkerHit(tap, projected, 36f, "m3")
        assertEquals("m1", hit4?.id)
    }

    @Test
    fun findMarkerHit_whenUnrelatedMarkerSelected_selectsFirstCandidate() {
        val m1 = createMarker("m1", 26.900, 75.800)
        val m2 = createMarker("m2", 26.900, 75.800)
        val pt1 = MapLibreMarkerCyclingMath.ScreenPoint(200f, 300f)
        val pt2 = MapLibreMarkerCyclingMath.ScreenPoint(202f, 298f)

        val projected = listOf(m1 to pt1, m2 to pt2)
        val tap = MapLibreMarkerCyclingMath.ScreenPoint(200f, 300f)

        val hit = MapLibreMarkerCyclingMath.findMarkerHit(tap, projected, 36f, "other_unrelated_marker")
        assertEquals("m1", hit?.id)
    }
}
