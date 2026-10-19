package com.routeflow.app.core.design.map

import com.routeflow.app.BuildConfig

/**
 * Diagnostic and configuration helper for RouteFlow map subsystem.
 * Evaluates whether a valid Google Maps API Key has been configured.
 */
object MapConfig {

    /**
     * Inspects BuildConfig.MAPS_API_KEY to determine if Google Play Services Maps
     * can be rendered, or whether the fallback vector logistics spatial plane should be used.
     */
    fun isGoogleMapsConfigured(): Boolean {
        val key = BuildConfig.MAPS_API_KEY.trim()
        if (key.isBlank()) return false
        if (key.equals("YOUR_KEY_HERE", ignoreCase = true)) return false
        if (key.startsWith("AIzaSyDummy", ignoreCase = true)) return false
        if (key.length < 20) return false
        return true
    }

    /**
     * Explanation message displayed on the honest logistics canvas fallback.
     */
    const val FALLBACK_NOTICE = "RouteFlow Logistics Spatial View (Offline Vector Grid • Real Coordinates Plotted)"
    const val SETUP_HINT = "To enable satellite/street imagery, supply MAPS_API_KEY in local properties or environment."
}
