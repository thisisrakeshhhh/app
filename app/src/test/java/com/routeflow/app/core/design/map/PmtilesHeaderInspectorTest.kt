package com.routeflow.app.core.design.map

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PmtilesHeaderInspectorTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    private fun createValidV3Header(): ByteArray {
        val bytes = ByteArray(127)
        // Offset 0..6: Magic bytes
        System.arraycopy("PMTiles".toByteArray(), 0, bytes, 0, 7)
        // Offset 7: Version 3
        bytes[7] = 3
        // Offset 16..23: Root Directory Length (non-zero test values)
        bytes[16] = 0x55.toByte()
        bytes[17] = 0xAA.toByte()
        // Offset 97: Internal directory compression -> gzip (2)
        bytes[97] = 2
        // Offset 98: Tile payload compression -> gzip (2)
        bytes[98] = 2
        // Offset 99: Tile type -> MVT Vector (1)
        bytes[99] = 1
        // Offset 100: Min Zoom -> 0
        bytes[100] = 0
        // Offset 101: Max Zoom -> 14
        bytes[101] = 14
        return bytes
    }

    @Test
    fun inspect_whenFileDoesNotExist_returnsMissing() {
        val nonExistent = File(tempFolder.root, "does_not_exist.pmtiles")
        val result = PmtilesHeaderInspector.inspect(nonExistent)

        assertTrue(result is PmtilesArchiveValidation.Missing)
        assertEquals(nonExistent.absolutePath, (result as PmtilesArchiveValidation.Missing).path)
    }

    @Test
    fun inspect_whenFileZeroBytes_returnsCorrupt() {
        val emptyFile = tempFolder.newFile("empty.pmtiles")
        val result = PmtilesHeaderInspector.inspect(emptyFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        val corrupt = result as PmtilesArchiveValidation.Corrupt
        assertTrue(corrupt.reason.contains("less than the required 127-byte"))
    }

    @Test
    fun inspect_whenFileTruncated_returnsCorrupt() {
        listOf(1, 50, 126).forEach { size ->
            val truncatedFile = tempFolder.newFile("truncated_$size.pmtiles")
            truncatedFile.writeBytes(ByteArray(size))

            val result = PmtilesHeaderInspector.inspect(truncatedFile)
            assertTrue("Expected Corrupt for file size $size", result is PmtilesArchiveValidation.Corrupt)
            val corrupt = result as PmtilesArchiveValidation.Corrupt
            assertTrue(corrupt.reason.contains("less than the required 127-byte"))
        }
    }

    @Test
    fun inspect_whenMagicBytesInvalid_returnsCorrupt() {
        val badMagic = tempFolder.newFile("bad_magic.pmtiles")
        val bytes = createValidV3Header()
        System.arraycopy("NOT_PMT".toByteArray(), 0, bytes, 0, 7)
        badMagic.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(badMagic)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Invalid PMTiles magic bytes"))
    }

    @Test
    fun inspect_whenVersionNot3_returnsCorrupt() {
        val badVersion = tempFolder.newFile("bad_version.pmtiles")
        val bytes = createValidV3Header()
        bytes[7] = 2 // v2
        badVersion.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(badVersion)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Unsupported PMTiles spec version: 2"))
    }

    @Test
    fun inspect_whenInternalCompressionAtByte97IsUnsupportedZstd_returnsCorrupt() {
        val zstdFile = tempFolder.newFile("internal_zstd.pmtiles")
        val bytes = createValidV3Header()
        bytes[97] = 4 // internal directory compression = zstd
        zstdFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(zstdFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Internal directory compression 'zstd (4) [PROVISIONAL / UNSUPPORTED]'"))
    }

    @Test
    fun inspect_whenInternalCompressionAtByte97IsUnsupportedBrotli_returnsCorrupt() {
        val brotliFile = tempFolder.newFile("internal_brotli.pmtiles")
        val bytes = createValidV3Header()
        bytes[97] = 3 // internal directory compression = brotli
        brotliFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(brotliFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Internal directory compression 'brotli (3) [UNSUPPORTED]'"))
    }

    @Test
    fun inspect_whenTileCompressionAtByte98IsUnsupportedBrotli_returnsCorrupt() {
        val brotliFile = tempFolder.newFile("tile_brotli.pmtiles")
        val bytes = createValidV3Header()
        bytes[98] = 3 // tile compression = brotli
        brotliFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(brotliFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Tile payload compression 'brotli (3) [UNSUPPORTED]'"))
    }

    @Test
    fun inspect_whenTileCompressionAtByte98IsUnsupportedZstd_returnsCorrupt() {
        val zstdFile = tempFolder.newFile("tile_zstd.pmtiles")
        val bytes = createValidV3Header()
        bytes[98] = 4 // tile compression = zstd
        zstdFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(zstdFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Tile payload compression 'zstd (4) [PROVISIONAL / UNSUPPORTED]'"))
    }

    @Test
    fun inspect_whenTileTypeAtByte99IsNotMvt_returnsCorrupt() {
        val rasterFile = tempFolder.newFile("raster.pmtiles")
        val bytes = createValidV3Header()
        bytes[99] = 2 // PNG raster (code 2), not MVT vector (code 1)
        rasterFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(rasterFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("not MVT Vector (spec code 1)"))
    }

    @Test
    fun inspect_whenMinZoomExceedsMaxZoom_returnsCorrupt() {
        val invalidZoomFile = tempFolder.newFile("invalid_zoom.pmtiles")
        val bytes = createValidV3Header()
        bytes[100] = 16 // min zoom 16
        bytes[101] = 10 // max zoom 10
        invalidZoomFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(invalidZoomFile)

        assertTrue(result is PmtilesArchiveValidation.Corrupt)
        assertTrue((result as PmtilesArchiveValidation.Corrupt).reason.contains("Malformed zoom levels"))
    }

    @Test
    fun inspect_whenValidV3Gzip_returnsValidAndPreservesFieldSeparation() {
        val validFile = tempFolder.newFile("valid.pmtiles")
        val bytes = createValidV3Header()
        validFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(validFile)

        assertTrue(result is PmtilesArchiveValidation.Valid)
        val valid = result as PmtilesArchiveValidation.Valid
        assertEquals(3, valid.version)
        assertEquals("gzip (2)", valid.internalCompression)
        assertEquals("gzip (2)", valid.tileCompression)
        assertEquals("MVT Vector (1)", valid.tileType)
        assertEquals(0, valid.minZoom)
        assertEquals(14, valid.maxZoom)
    }

    @Test
    fun inspect_whenValidV3Uncompressed_returnsValid() {
        val uncompressedFile = tempFolder.newFile("uncompressed.pmtiles")
        val bytes = createValidV3Header()
        bytes[97] = 1 // internal compression none
        bytes[98] = 1 // tile compression none
        uncompressedFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(uncompressedFile)

        assertTrue(result is PmtilesArchiveValidation.Valid)
        val valid = result as PmtilesArchiveValidation.Valid
        assertEquals("none (1)", valid.internalCompression)
        assertEquals("none (1)", valid.tileCompression)
    }

    @Test
    fun inspect_verifiesBytes16To23DoNotAffectCompressionAtByte97And98() {
        val validFile = tempFolder.newFile("directory_length_check.pmtiles")
        val bytes = createValidV3Header()
        // Put byte values that would look like invalid compression (0x04 = zstd) at bytes 16 and 17
        bytes[16] = 4
        bytes[17] = 4
        // Genuine offsets 97 and 98 remain gzip (2)
        bytes[97] = 2
        bytes[98] = 2
        validFile.writeBytes(bytes)

        val result = PmtilesHeaderInspector.inspect(validFile)

        assertTrue(result is PmtilesArchiveValidation.Valid)
        val valid = result as PmtilesArchiveValidation.Valid
        assertEquals("gzip (2)", valid.internalCompression)
        assertEquals("gzip (2)", valid.tileCompression)
    }
}
