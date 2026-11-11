package com.routeflow.app.core.design.map

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteFlowMapLibreStyleBuilderTest {

    @Test(expected = IllegalArgumentException::class)
    fun build_whenPathIsBlank_throwsIllegalArgumentException() {
        RouteFlowMapLibreStyleBuilder.build("   ")
    }

    @Test
    fun build_generatesValidJsonWithVersion8() {
        val path = "/data/user/0/com.routeflow.app/files/maps/test.pmtiles"
        val styleJson = RouteFlowMapLibreStyleBuilder.build(path)

        val json = Json.parseToJsonElement(styleJson).jsonObject
        assertEquals(8, json["version"]?.jsonPrimitive?.int)
        assertEquals("RouteFlow Offline Basemap", json["name"]?.jsonPrimitive?.content)
        assertNotNull(json["sources"]?.jsonObject)
        assertNotNull(json["layers"]?.jsonArray)
    }

    @Test
    fun build_normalizesWindowsBackslashesToForwardSlashesInUri() {
        val windowsPath = """C:\Users\RouteFlow\maps\jaipur.pmtiles"""
        val styleJson = RouteFlowMapLibreStyleBuilder.build(windowsPath)

        val json = Json.parseToJsonElement(styleJson).jsonObject
        val source = json["sources"]!!.jsonObject["local_territory"]!!.jsonObject
        val url = source["url"]!!.jsonPrimitive.content

        assertEquals("pmtiles://file://C:/Users/RouteFlow/maps/jaipur.pmtiles", url)
        assertFalse(url.contains("""\"""))
    }

    @Test
    fun build_strictlyAvoidsRemoteDependenciesAndGlyphTemplates() {
        val path = "/storage/emulated/0/maps/territory.pmtiles"
        val styleJson = RouteFlowMapLibreStyleBuilder.build(path)

        // Strict audit for remote endpoints
        assertFalse("Style must not have remote dependencies", RouteFlowMapLibreStyleBuilder.hasRemoteDependencies(styleJson))
        assertFalse(styleJson.contains("http://"))
        assertFalse(styleJson.contains("https://"))

        // Must not declare unverified remote glyphs or sprites
        val json = Json.parseToJsonElement(styleJson).jsonObject
        assertFalse("Must not declare glyphs field pointing to network fonts", json.containsKey("glyphs"))
        assertFalse("Must not declare sprite field pointing to network sprite sheets", json.containsKey("sprite"))
    }

    @Test
    fun build_definesMultiSchemaLayersForBothProtomapsAndOpenMapTiles() {
        val path = "/maps/territory.pmtiles"
        val styleJson = RouteFlowMapLibreStyleBuilder.build(path)
        val json = Json.parseToJsonElement(styleJson).jsonObject
        val layers = json["layers"]!!.jsonArray

        val layerIds = mutableListOf<String>()
        val sourceLayers = mutableListOf<String>()

        for (layerElement in layers) {
            val layer = layerElement.jsonObject
            layerIds.add(layer["id"]!!.jsonPrimitive.content)
            if (layer.containsKey("source-layer")) {
                sourceLayers.add(layer["source-layer"]!!.jsonPrimitive.content)
            }
        }

        assertTrue("Must contain background layer", layerIds.contains("background"))
        assertTrue("Must contain water layer", layerIds.contains("water"))
        assertTrue("Must contain buildings layer", layerIds.contains("buildings"))
        assertTrue("Must contain transportation layer (OpenMapTiles)", layerIds.contains("transportation"))
        assertTrue("Must contain roads layer (Protomaps)", layerIds.contains("roads"))

        assertTrue("Must map water source-layer", sourceLayers.contains("water"))
        assertTrue("Must map buildings source-layer", sourceLayers.contains("buildings"))
        assertTrue("Must map transportation source-layer", sourceLayers.contains("transportation"))
        assertTrue("Must map roads source-layer", sourceLayers.contains("roads"))
    }

    @Test
    fun hasRemoteDependencies_correctlyIdentifiesInjectedUrls() {
        val clean = """{"sources": {"s": {"url": "pmtiles://file:///local.pmtiles"}}}"""
        assertFalse(RouteFlowMapLibreStyleBuilder.hasRemoteDependencies(clean))

        val dirtyHttp = """{"glyphs": "http://example.com/fonts/{fontstack}/{range}.pbf"}"""
        assertTrue(RouteFlowMapLibreStyleBuilder.hasRemoteDependencies(dirtyHttp))

        val dirtyHttps = """{"sprite": "https://example.com/sprites/osm-liberty"}"""
        assertTrue(RouteFlowMapLibreStyleBuilder.hasRemoteDependencies(dirtyHttps))
    }
}
