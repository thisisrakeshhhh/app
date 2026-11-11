package com.routeflow.app.poc

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import com.routeflow.app.core.design.RouteFlowTheme
import org.maplibre.android.MapLibre
import java.io.File

/**
 * Isolated debug-only Activity for MapLibre PMTiles PoC validation.
 *
 * Reachable strictly via ADB intent:
 * `adb shell am start -n com.routeflow.app/.poc.MapLibrePocActivity`
 * Optional custom path:
 * `adb shell am start -n com.routeflow.app/.poc.MapLibrePocActivity --es archive_path /path/to/archive.pmtiles`
 *
 * Does not appear in the launcher app drawer and is never reached in normal user navigation.
 */
class MapLibrePocActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize MapLibre native engine strictly within this debug harness
        MapLibre.getInstance(this)

        val customPath = intent.getStringExtra("archive_path")
        val archiveFile = if (!customPath.isNullOrBlank()) {
            File(customPath)
        } else {
            // Standard external app files directory accessible without runtime storage permissions
            val baseDir = getExternalFilesDir(null) ?: filesDir
            File(baseDir, "maps/test_territory.pmtiles")
        }

        val testMode = intent.getStringExtra("test_mode")

        setContent {
            RouteFlowTheme {
                when (testMode) {
                    "container" -> {
                        RouteFlowContainerTestHarness(
                            validArchiveFile = archiveFile,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    "adapter" -> {
                        RouteFlowAdapterTestHarness(
                            archiveFile = archiveFile,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    else -> {
                        MapLibrePocHarness(
                            archiveFile = archiveFile,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
            }
        }
    }
}
