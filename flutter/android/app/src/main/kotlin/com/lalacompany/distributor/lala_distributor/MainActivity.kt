package com.lalacompany.distributor.lala_distributor

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.routidrow.distributor/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchNavigation") {
                val uriString = call.argument<String>("uri")
                val fallbackUrl = call.argument<String>("fallbackUrl")

                try {
                    // Try google.navigation intent explicitly directed to Google Maps
                    val navIntent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString))
                    navIntent.setPackage("com.google.android.apps.maps")
                    if (navIntent.resolveActivity(packageManager) != null) {
                        startActivity(navIntent)
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // Fallback to web directions in Google Maps or Browser
                    val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl))
                    startActivity(webIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("NAVIGATION_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
