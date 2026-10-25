package com.routeflow.app.core.design.map

/**
 * Spatial map provider modes supported by RouteFlow architecture.
 * Enables clear provider boundaries between online Google Maps,
 * offline MapLibre PMTiles, and the mathematical Logistics Canvas fallback.
 */
enum class MapProviderMode {
    /**
     * Online Google Maps provider. Active when MAPS_API_KEY is configured
     * and an active network connection or cache is available.
     */
    GOOGLE_MAPS,

    /**
     * Offline regional vector street basemap using a verified local PMTiles v3 archive.
     */
    MAPLIBRE_OFFLINE,

    /**
     * Algorithmic 2D vector spatial plane. Used when Google Maps is unconfigured,
     * no valid PMTiles archive is found, or the device is air-gapped without street data.
     */
    LOGISTICS_CANVAS
}
