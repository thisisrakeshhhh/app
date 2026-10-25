package com.routeflow.app.core.design.map

import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MapConfigProviderTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private lateinit var mapsDir: File

    private fun createValidV3Header(): ByteArray {
        val bytes = ByteArray(127)
        System.arraycopy("PMTiles".toByteArray(Charsets.US_ASCII), 0, bytes, 0, 7)
        bytes[7] = 3
        bytes[16] = 0x55.toByte()
        bytes[17] = 0xAA.toByte()
        bytes[97] = 2
        bytes[98] = 2
        bytes[99] = 1
        bytes[100] = 0
        bytes[101] = 14
        return bytes
    }

    @Before
    fun setUp() {
        mapsDir = tempFolder.newFolder("maps")
        MapConfig.customMapsDirectory = mapsDir
        MapConfig.preferredProviderOverride = null
    }

    @After
    fun tearDown() {
        MapConfig.customMapsDirectory = null
        MapConfig.preferredProviderOverride = null
    }

    @Test
    fun defaultProviderMode_withoutOverrideAndNoArchive_returnsCanvas() {
        // No archive in mapsDir, MAPS_API_KEY unconfigured
        assertEquals(MapProviderMode.LOGISTICS_CANVAS, MapConfig.defaultProviderMode())
    }

    @Test
    fun defaultProviderMode_withValidArchive_returnsMapLibreOffline() {
        // Create valid PMTiles v3 header in mapsDir/territory.pmtiles
        val territoryFile = File(mapsDir, "territory.pmtiles")
        territoryFile.writeBytes(createValidV3Header())

        assertTrue(MapConfig.hasValidArchive())
        // When context is provided (or customMapsDirectory is set), it evaluates to MAPLIBRE_OFFLINE
        assertEquals(MapProviderMode.MAPLIBRE_OFFLINE, MapConfig.defaultProviderMode(null))
    }

    @Test
    fun defaultProviderMode_withFallbackTestArchive_returnsMapLibreOffline() {
        // Create valid test_territory.pmtiles
        val testArchive = File(mapsDir, "test_territory.pmtiles")
        testArchive.writeBytes(createValidV3Header())

        assertTrue(MapConfig.hasValidArchive())
        assertEquals(MapProviderMode.MAPLIBRE_OFFLINE, MapConfig.defaultProviderMode(null))
    }

    @Test
    fun defaultProviderMode_withOverride_returnsOverriddenMode() {
        MapConfig.preferredProviderOverride = MapProviderMode.MAPLIBRE_OFFLINE
        assertEquals(MapProviderMode.MAPLIBRE_OFFLINE, MapConfig.defaultProviderMode())

        MapConfig.preferredProviderOverride = MapProviderMode.GOOGLE_MAPS
        assertEquals(MapProviderMode.GOOGLE_MAPS, MapConfig.defaultProviderMode())
    }

    @Test
    fun defaultProviderMode_afterClearingOverride_revertsToDefault() {
        MapConfig.preferredProviderOverride = MapProviderMode.MAPLIBRE_OFFLINE
        assertEquals(MapProviderMode.MAPLIBRE_OFFLINE, MapConfig.defaultProviderMode())

        MapConfig.preferredProviderOverride = null
        assertEquals(MapProviderMode.LOGISTICS_CANVAS, MapConfig.defaultProviderMode())
    }
}
