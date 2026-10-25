package com.routeflow.app.core.design.map

import java.io.File
import java.io.FileInputStream

/**
 * Validation outcome stages for a local PMTiles archive.
 * Explicitly separates:
 * 1. File existence on the filesystem.
 * 2. 127-byte Header parsing and compression verification (does not prove tiles render).
 * 3. Native MapLibre style loading and engine initialization.
 * 4. Actual visual vector tile rendering.
 */
sealed interface PmtilesArchiveValidation {
    data class Missing(val path: String) : PmtilesArchiveValidation
    data class Corrupt(val path: String, val reason: String) : PmtilesArchiveValidation
    data class Valid(
        val path: String,
        val version: Int,
        val internalCompression: String,
        val tileCompression: String,
        val tileType: String,
        val minZoom: Int,
        val maxZoom: Int
    ) : PmtilesArchiveValidation
}

/**
 * Pure Kotlin parser and validator for the 127-byte PMTiles v3 binary header.
 * Designed to reject unsupported archives defensively before handing paths to the
 * native MapLibre C++ engine.
 *
 * PMTiles v3 Binary Header Specification (Little-Endian):
 * - Bytes 0..6: ASCII "PMTiles" magic (7 bytes)
 * - Byte 7: Version uint8 (must be 3)
 * - Bytes 8..15: Root Directory Offset uint64
 * - Bytes 16..23: Root Directory Length uint64
 * - Bytes 24..31: JSON Metadata Offset uint64
 * - Bytes 32..39: JSON Metadata Length uint64
 * - Bytes 40..47: Leaf Directories Offset uint64
 * - Bytes 48..55: Leaf Directories Length uint64
 * - Bytes 56..63: Tile Data Offset uint64
 * - Bytes 64..71: Tile Data Length uint64
 * - Bytes 72..79: Addressed Tiles Count uint64
 * - Bytes 80..87: Tile Entries Count uint64
 * - Bytes 88..95: Tile Contents Count uint64
 * - Byte 96: Clustered boolean (0 or 1)
 * - Byte 97 (0x61): Internal Directory/Metadata Compression (1=none, 2=gzip, 3=brotli, 4=zstd)
 * - Byte 98 (0x62): Tile Payload Compression (1=none, 2=gzip, 3=brotli, 4=zstd)
 * - Byte 99 (0x63): Tile Type (1=MVT vector, 2=PNG, 3=JPEG, 4=WEBP, 5=AVIF, 6=MLT)
 * - Byte 100 (0x64): Min Zoom uint8
 * - Byte 101 (0x65): Max Zoom uint8
 * - Bytes 102..117: Bounds (min_lon, min_lat, max_lon, max_lat as 10^7 int32)
 * - Bytes 118..126: Center & Zoom
 *
 * NOTE: A valid header proves specification compliance and supported compression codecs only.
 * It does NOT guarantee that internal vector geometries or fonts are renderable without errors.
 */
object PmtilesHeaderInspector {

    private const val REQUIRED_HEADER_LENGTH = 127
    private const val EXPECTED_MAGIC = "PMTiles"
    private const val EXPECTED_VERSION = 3

    fun inspect(file: File): PmtilesArchiveValidation {
        if (!file.exists()) {
            return PmtilesArchiveValidation.Missing(file.absolutePath)
        }

        val fileLength = file.length()
        if (fileLength < REQUIRED_HEADER_LENGTH) {
            return PmtilesArchiveValidation.Corrupt(
                file.absolutePath,
                "File length ($fileLength bytes) is less than the required $REQUIRED_HEADER_LENGTH-byte PMTiles header."
            )
        }

        return try {
            FileInputStream(file).use { stream ->
                val header = ByteArray(REQUIRED_HEADER_LENGTH)
                var bytesRead = 0
                while (bytesRead < REQUIRED_HEADER_LENGTH) {
                    val count = stream.read(header, bytesRead, REQUIRED_HEADER_LENGTH - bytesRead)
                    if (count < 0) break
                    bytesRead += count
                }

                if (bytesRead < REQUIRED_HEADER_LENGTH) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Truncated read: only read $bytesRead of $REQUIRED_HEADER_LENGTH bytes from header."
                    )
                }

                // 1. Magic bytes (0..6)
                val magic = String(header, 0, 7, Charsets.US_ASCII)
                if (magic != EXPECTED_MAGIC) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Invalid PMTiles magic bytes: '$magic' (expected '$EXPECTED_MAGIC')."
                    )
                }

                // 2. Spec Version (byte 7)
                val version = header[7].toInt() and 0xFF
                if (version != EXPECTED_VERSION) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Unsupported PMTiles spec version: $version (expected v$EXPECTED_VERSION)."
                    )
                }

                // 3. Internal Directory & Metadata Compression (byte 97)
                val internalCompressionCode = header[97].toInt() and 0xFF
                val internalCompression = when (internalCompressionCode) {
                    1 -> "none (1)"
                    2 -> "gzip (2)"
                    3 -> "brotli (3) [UNSUPPORTED]"
                    4 -> "zstd (4) [PROVISIONAL / UNSUPPORTED]"
                    else -> "unknown ($internalCompressionCode)"
                }

                // 4. Tile Payload Compression (byte 98)
                val tileCompressionCode = header[98].toInt() and 0xFF
                val tileCompression = when (tileCompressionCode) {
                    1 -> "none (1)"
                    2 -> "gzip (2)"
                    3 -> "brotli (3) [UNSUPPORTED]"
                    4 -> "zstd (4) [PROVISIONAL / UNSUPPORTED]"
                    else -> "unknown ($tileCompressionCode)"
                }

                // 5. Tile Type (byte 99)
                val tileTypeCode = header[99].toInt() and 0xFF
                val tileType = when (tileTypeCode) {
                    1 -> "MVT Vector (1)"
                    2 -> "PNG Raster (2)"
                    3 -> "JPEG Raster (3)"
                    4 -> "WEBP Raster (4)"
                    5 -> "AVIF (5)"
                    6 -> "MLT (6)"
                    else -> "Type ($tileTypeCode)"
                }

                val minZoom = header[100].toInt() and 0xFF
                val maxZoom = header[101].toInt() and 0xFF

                if (minZoom > maxZoom) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Malformed zoom levels: minZoom ($minZoom) exceeds maxZoom ($maxZoom)."
                    )
                }

                // Validate internal compression against MapLibre 11.8.8 capabilities (gzip or none)
                if (internalCompressionCode != 1 && internalCompressionCode != 2) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Internal directory compression '$internalCompression' is unsupported by MapLibre 11.8.8 (requires gzip or none)."
                    )
                }

                // Validate tile payload compression against MapLibre 11.8.8 capabilities (gzip or none)
                if (tileCompressionCode != 1 && tileCompressionCode != 2) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Tile payload compression '$tileCompression' is unsupported by MapLibre 11.8.8 (requires gzip or none)."
                    )
                }

                // Validate tile payload type (must be MVT Vector = 1 for vector street map)
                if (tileTypeCode != 1) {
                    return PmtilesArchiveValidation.Corrupt(
                        file.absolutePath,
                        "Archive tile type '$tileType' is not MVT Vector (spec code 1)."
                    )
                }

                PmtilesArchiveValidation.Valid(
                    path = file.absolutePath,
                    version = version,
                    internalCompression = internalCompression,
                    tileCompression = tileCompression,
                    tileType = tileType,
                    minZoom = minZoom,
                    maxZoom = maxZoom
                )
            }
        } catch (e: Exception) {
            PmtilesArchiveValidation.Corrupt(
                file.absolutePath,
                "I/O error inspecting PMTiles header: ${e.message}"
            )
        }
    }
}
