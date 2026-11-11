package com.routeflow.app.core.design.map

/**
 * Pure spatial hit-testing and cycling logic for MapLibre markers.
 * Decoupled from Android UI and native types to enable deterministic JVM unit testing.
 *
 * Implements the exact same cycling model as [RouteFlowCanvasSpatialMath.hitTestMarker]:
 * When multiple markers overlap within a comfortable touch radius (e.g. 36dp):
 * - If none of the overlapping markers is currently selected, selects the first candidate.
 * - If one of the overlapping markers IS currently selected, cycles to the next candidate.
 */
object MapLibreMarkerCyclingMath {

    data class ScreenPoint(val x: Float, val y: Float)

    /**
     * Finds the candidate marker at the tap location, cycling through overlapping markers
     * if one is already selected.
     *
     * @param tapPoint The screen coordinates of the user's touch tap.
     * @param projectedMarkers List of logistics markers paired with their screen projection coordinates.
     * @param touchRadiusPx The touch threshold radius in screen pixels (typically 36dp converted to px).
     * @param currentSelectedMarkerId The ID of the currently selected marker, if any.
     * @return The resolved [LogisticsMarker], or null if no marker was within touch radius.
     */
    fun findMarkerHit(
        tapPoint: ScreenPoint,
        projectedMarkers: List<Pair<LogisticsMarker, ScreenPoint>>,
        touchRadiusPx: Float,
        currentSelectedMarkerId: String?
    ): LogisticsMarker? {
        val radiusSquared = touchRadiusPx * touchRadiusPx

        val candidates = projectedMarkers.filter { (_, screenPt) ->
            val dx = screenPt.x - tapPoint.x
            val dy = screenPt.y - tapPoint.y
            (dx * dx + dy * dy) <= radiusSquared
        }.map { it.first }

        if (candidates.isEmpty()) return null
        if (candidates.size == 1) return candidates[0]

        val currentIndex = candidates.indexOfFirst { it.id == currentSelectedMarkerId }
        return if (currentIndex != -1) {
            candidates[(currentIndex + 1) % candidates.size]
        } else {
            candidates[0]
        }
    }
}
