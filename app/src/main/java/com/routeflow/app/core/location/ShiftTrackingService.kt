package com.routeflow.app.core.location

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.routeflow.app.R
import com.routeflow.app.app.MainActivity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.LocationPoint
import com.routeflow.app.core.network.dto.ShiftLocationsRequest
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class ShiftTrackingService : Service(), LocationListener {

    @Inject lateinit var api: RouteFlowApi

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var locationManager: LocationManager? = null
    private var activeShiftId: String? = null
    private val breadcrumbBuffer = mutableListOf<LocationPoint>()

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP_TRACKING) {
            stopTracking()
            stopSelf()
            return START_NOT_STICKY
        }

        val shiftId = intent?.getStringExtra(EXTRA_SHIFT_ID)
        if (shiftId != null) {
            activeShiftId = shiftId
            startForeground(NOTIFICATION_ID, buildForegroundNotification())
            startLocationUpdates()
        }

        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun startLocationUpdates() {
        try {
            locationManager?.let { lm ->
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        MIN_TIME_MS,
                        MIN_DISTANCE_M,
                        this
                    )
                }
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        MIN_TIME_MS,
                        MIN_DISTANCE_M,
                        this
                    )
                }
            }
        } catch (_: SecurityException) {
            stopSelf()
        }
    }

    override fun onLocationChanged(location: Location) {
        val point = LocationPoint(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy,
            timestamp = location.time.takeIf { it > 0 } ?: System.currentTimeMillis()
        )

        synchronized(breadcrumbBuffer) {
            breadcrumbBuffer.add(point)
            if (breadcrumbBuffer.size >= BATCH_UPLOAD_SIZE) {
                flushBuffer()
            }
        }
    }

    private fun flushBuffer() {
        val shiftId = activeShiftId ?: return
        val toSend: List<LocationPoint>
        synchronized(breadcrumbBuffer) {
            if (breadcrumbBuffer.isEmpty()) return
            toSend = breadcrumbBuffer.toList()
            breadcrumbBuffer.clear()
        }

        serviceScope.launch {
            try {
                api.uploadShiftLocations(
                    ShiftLocationsRequest(shiftId = shiftId, points = toSend)
                )
            } catch (_: Exception) {
                // If offline, re-buffer up to limit to prevent memory leak
                synchronized(breadcrumbBuffer) {
                    if (breadcrumbBuffer.size < 500) {
                        breadcrumbBuffer.addAll(0, toSend)
                    }
                }
            }
        }
    }

    private fun stopTracking() {
        try {
            locationManager?.removeUpdates(this)
            flushBuffer()
        } catch (_: Exception) {}
        activeShiftId = null
    }

    override fun onDestroy() {
        stopTracking()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RouteFlow Active Shift",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active shift GPS tracking status"
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RouteFlow Shift Active")
            .setContentText("Location tracking enabled for your shift")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_START_TRACKING = "com.routeflow.app.START_TRACKING"
        const val ACTION_STOP_TRACKING = "com.routeflow.app.STOP_TRACKING"
        const val EXTRA_SHIFT_ID = "extra_shift_id"
        private const val CHANNEL_ID = "rf_shift_tracking"
        private const val NOTIFICATION_ID = 9110
        private const val MIN_TIME_MS = 15000L // 15 seconds
        private const val MIN_DISTANCE_M = 10f  // 10 meters
        private const val BATCH_UPLOAD_SIZE = 4 // Flush every 4 points (~1 minute)

        fun start(context: Context, shiftId: String) {
            val intent = Intent(context, ShiftTrackingService::class.java).apply {
                action = ACTION_START_TRACKING
                putExtra(EXTRA_SHIFT_ID, shiftId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ShiftTrackingService::class.java).apply {
                action = ACTION_STOP_TRACKING
            }
            context.startService(intent)
        }
    }
}
