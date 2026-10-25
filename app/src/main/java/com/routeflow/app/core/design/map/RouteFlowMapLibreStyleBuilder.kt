package com.routeflow.app.core.design.map

/**
 * Builds a strict, offline-first MapLibre Style Specification (v8) JSON document
 * for rendering local vector PMTiles archives.
 *
 * Design constraints:
 * - Offline isolation: Strictly points to `pmtiles://file://$pmtilesAbsolutePath`.
 * - Zero network leakage: Excludes remote glyph and sprite URLs (`http://` / `https://`)
 *   to prevent background network requests, timeouts, or air-gap rendering failures.
 * - Multi-schema compatibility: Defines rendering layers for both Protomaps schemas
 *   (`roads`, `buildings`, `water`) and OpenMapTiles schemas (`transportation`, `water`).
 * - Glyphs / Labels: Avoids unverified remote font stacks; complex typography (e.g. Devanagari)
 *   is not assumed and must not be loaded from remote CDNs.
 */
object RouteFlowMapLibreStyleBuilder {

    /**
     * Constructs the local MapLibre style JSON string for a given PMTiles archive path.
     *
     * @param pmtilesAbsolutePath The absolute filesystem path to the local PMTiles archive.
     * @return Complete MapLibre v8 Style JSON.
     * @throws IllegalArgumentException if the provided path is blank.
     */
    fun build(pmtilesAbsolutePath: String): String {
        require(pmtilesAbsolutePath.isNotBlank()) {
            "PMTiles absolute path cannot be blank."
        }

        // Clean path to ensure valid file URI format
        val cleanPath = pmtilesAbsolutePath.trim().replace('\\', '/')

        return """
        {
          "version": 8,
          "name": "RouteFlow Offline Basemap",
          "sources": {
            "local_territory": {
              "type": "vector",
              "url": "pmtiles://file://$cleanPath"
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
              "source": "local_territory",
              "source-layer": "water",
              "paint": {
                "fill-color": "#93c5fd"
              }
            },
            {
              "id": "buildings",
              "type": "fill",
              "source": "local_territory",
              "source-layer": "buildings",
              "paint": {
                "fill-color": "#e2e8f0",
                "fill-outline-color": "#cbd5e1"
              }
            },
            {
              "id": "transportation",
              "type": "line",
              "source": "local_territory",
              "source-layer": "transportation",
              "paint": {
                "line-color": "#64748b",
                "line-width": 1.5
              }
            },
            {
              "id": "roads",
              "type": "line",
              "source": "local_territory",
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

    /**
     * Audits a style JSON to ensure it contains zero remote HTTP/HTTPS endpoints,
     * remote font templates, or remote sprite sheets.
     */
    fun hasRemoteDependencies(styleJson: String): Boolean {
        val lower = styleJson.lowercase()
        return lower.contains("http://") || lower.contains("https://")
    }
}
