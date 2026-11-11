package com.routeflow.app.core.design.map

import android.content.Context
import com.routeflow.app.BuildConfig
import java.io.File

/**
 * Diagnostic and configuration helper for RouteFlow map subsystem.
 * Evaluates whether a valid Google Maps API Key has been configured
 * and manages provider selection and offline map archive resolution.
 */
object MapConfig {

    /**
     * Optional override for the preferred map provider mode across the application.
     * When null, falls back to [MapProviderMode.GOOGLE_MAPS] if configured,
     * otherwise checks for a valid local offline PMTiles archive, and lastly
     * falls back to [MapProviderMode.LOGISTICS_CANVAS].
     */
    var preferredProviderOverride: MapProviderMode? = null

    /**
     * Resolves the default provider mode based on configuration, overrides, and archive availability.
     * Order of precedence:
     * 1. Explicit override via [preferredProviderOverride]
     * 2. Google Maps (if MAPS_API_KEY is configured with a valid key)
     * 3. Offline MapLibre PMTiles (if a valid local regional archive exists)
     * 4. Logistics Canvas (honest algorithmic grid fallback)
     */
    fun defaultProviderMode(context: Context? = null): MapProviderMode {
        if (preferredProviderOverride != null) return preferredProviderOverride!!
        if (isGoogleMapsConfigured()) return MapProviderMode.GOOGLE_MAPS
        if ((context != null || customMapsDirectory != null) && hasValidArchive(context)) {
            return MapProviderMode.MAPLIBRE_OFFLINE
        }
        return MapProviderMode.LOGISTICS_CANVAS
    }

    /**
     * Optional custom directory override for testing or specialized enterprise deployments.
     */
    var customMapsDirectory: File? = null

    /**
     * Checks whether a valid regional PMTiles archive currently exists on disk.
     */
    fun hasValidArchive(context: Context? = null): Boolean {
        val archive = resolveDefaultArchiveFile(context)
        if (!archive.exists() || archive.length() < 127) return false
        val validation = PmtilesHeaderInspector.inspect(archive)
        return validation is PmtilesArchiveValidation.Valid
    }

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
     * Resolves the app-specific directory for local map archives:
     * `<external-files>/maps` or `<internal-files>/maps`
     */
    fun getMapsDirectory(context: Context? = null): File {
        if (customMapsDirectory != null) {
            val dir = customMapsDirectory!!
            if (!dir.exists()) dir.mkdirs()
            return dir
        }
        val baseDir = context?.getExternalFilesDir(null) ?: context?.filesDir ?: File("build/tmp/maps")
        val dir = File(baseDir, "maps")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * Resolves the primary local regional map archive if present in the maps directory.
     * Checks for territory archive first, then the verified test territory archive.
     */
    fun resolveDefaultArchiveFile(context: Context? = null): File {
        val mapsDir = getMapsDirectory(context)
        val primaryArchive = File(mapsDir, "territory.pmtiles")
        if (primaryArchive.exists()) return primaryArchive
        return File(mapsDir, "test_territory.pmtiles")
    }

    /**
     * Explanation message displayed on the honest logistics canvas fallback.
     */
    const val FALLBACK_NOTICE = "RouteFlow Logistics Spatial View (Offline Vector Grid • Real Coordinates Plotted)"
    const val SETUP_HINT = "To enable satellite/street imagery, supply MAPS_API_KEY in local properties or import a .pmtiles regional map."
}
