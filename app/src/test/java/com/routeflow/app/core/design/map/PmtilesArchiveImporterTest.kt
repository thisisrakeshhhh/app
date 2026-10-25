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

class PmtilesArchiveImporterTest {

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
    }

    @After
    fun tearDown() {
        MapConfig.customMapsDirectory = null
        MapConfig.preferredProviderOverride = null
    }

    @Test
    fun importArchiveFromFile_withValidHeader_succeedsAndInstallsTerritoryPmtiles() {
        // Create a synthetic valid PMTiles v3 archive header (127 bytes)
        val validFile = tempFolder.newFile("source_valid.pmtiles")
        validFile.writeBytes(createValidV3Header())

        val result = PmtilesArchiveImporter.importArchiveFromFile(sourceFile = validFile)

        assertTrue("Expected Success, got $result", result is PmtilesArchiveImporter.ImportResult.Success)
        val targetFile = File(mapsDir, "territory.pmtiles")
        assertTrue("territory.pmtiles should exist in maps directory", targetFile.exists())
        assertEquals(127L, targetFile.length())
    }

    @Test
    fun importArchiveFromFile_withCorruptHeader_failsAndDoesNotInstall() {
        val corruptFile = tempFolder.newFile("source_corrupt.pmtiles")
        corruptFile.writeBytes(ByteArray(20)) // < 127 bytes

        val result = PmtilesArchiveImporter.importArchiveFromFile(sourceFile = corruptFile)

        assertTrue("Expected Error, got $result", result is PmtilesArchiveImporter.ImportResult.Error)
        val targetFile = File(mapsDir, "territory.pmtiles")
        assertFalse("territory.pmtiles should not be installed when source is corrupt", targetFile.exists())
    }

    @Test
    fun importArchiveFromFile_withNonExistentFile_returnsError() {
        val nonExistent = File(tempFolder.root, "does_not_exist.pmtiles")

        val result = PmtilesArchiveImporter.importArchiveFromFile(sourceFile = nonExistent)

        assertTrue(result is PmtilesArchiveImporter.ImportResult.Error)
    }
}
