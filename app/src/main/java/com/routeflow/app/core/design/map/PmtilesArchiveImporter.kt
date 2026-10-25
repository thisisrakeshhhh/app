package com.routeflow.app.core.design.map

import android.content.Context
import android.net.Uri
import java.io.File

/**
 * Enterprise and user provisioning utility for regional PMTiles v3 archives.
 *
 * Allows authorized users, fleet managers, or drivers to import and activate
 * a licensed offline vector street map archive without ADB or source code changes.
 *
 * Defensively stages incoming files, executes pre-flight [PmtilesHeaderInspector]
 * validation, and only promotes valid archives to the primary 'territory.pmtiles' path.
 */
object PmtilesArchiveImporter {

    sealed class ImportResult {
        data class Success(val file: File, val message: String) : ImportResult()
        data class Error(val message: String) : ImportResult()
    }

    /**
     * Imports a PMTiles archive from an Android content URI (e.g. from system document picker,
     * Downloads, Google Drive, WhatsApp, or SD card).
     */
    fun importArchiveFromUri(context: Context, sourceUri: Uri): ImportResult {
        return try {
            val mapsDir = MapConfig.getMapsDirectory(context)
            val stagingFile = File(mapsDir, "staging_import.pmtiles")

            context.contentResolver.openInputStream(sourceUri)?.use { input ->
                stagingFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: return ImportResult.Error("Could not open input stream from selected URI.")

            val validation = PmtilesHeaderInspector.inspect(stagingFile)
            if (validation !is PmtilesArchiveValidation.Valid) {
                stagingFile.delete()
                val reason = if (validation is PmtilesArchiveValidation.Corrupt) validation.reason else "Archive is missing or invalid"
                return ImportResult.Error("Invalid PMTiles v3 archive: $reason")
            }

            val targetFile = File(mapsDir, "territory.pmtiles")
            if (targetFile.exists()) {
                targetFile.delete()
            }
            if (!stagingFile.renameTo(targetFile)) {
                stagingFile.copyTo(targetFile, overwrite = true)
                stagingFile.delete()
            }

            ImportResult.Success(targetFile, "Successfully installed regional street map: territory.pmtiles")
        } catch (e: Exception) {
            ImportResult.Error("Import failed: ${e.message}")
        }
    }

    /**
     * Imports directly from an existing File (e.g. for testing, cache transfer, or direct storage provisioning).
     */
    fun importArchiveFromFile(context: Context? = null, sourceFile: File): ImportResult {
        return try {
            if (!sourceFile.exists()) {
                return ImportResult.Error("Source file does not exist: ${sourceFile.absolutePath}")
            }

            val validation = PmtilesHeaderInspector.inspect(sourceFile)
            if (validation !is PmtilesArchiveValidation.Valid) {
                val reason = if (validation is PmtilesArchiveValidation.Corrupt) validation.reason else "Archive is invalid"
                return ImportResult.Error("Invalid PMTiles v3 archive: $reason")
            }

            val mapsDir = MapConfig.getMapsDirectory(context)
            val targetFile = File(mapsDir, "territory.pmtiles")
            sourceFile.copyTo(targetFile, overwrite = true)

            ImportResult.Success(targetFile, "Successfully installed regional street map: territory.pmtiles")
        } catch (e: Exception) {
            ImportResult.Error("Import failed: ${e.message}")
        }
    }
}
