package com.routeflow.app.core.location

import android.annotation.SuppressLint
import android.app.*
import android.content.*
import android.location.*
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.room.withTransaction
import com.routeflow.app.R
import com.routeflow.app.app.MainActivity
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.ShiftLocationEntity
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.sync.SyncManager
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import java.util.UUID
import javax.inject.Inject

@AndroidEntryPoint
class ShiftTrackingService : Service(), LocationListener {
    @Inject lateinit var db: RouteFlowDatabase
    @Inject lateinit var tokens: TokenStorage
    @Inject lateinit var sync: SyncManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var manager: LocationManager? = null
    private var shiftId: String? = null
    private var userId: String? = null
    private var companyId: String? = null
    override fun onCreate() { super.onCreate(); manager = getSystemService(LocationManager::class.java) }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra("shiftId") ?: run { stopSelf(); return START_NOT_STICKY }
        shiftId = id; userId = tokens.getUserId(); companyId = tokens.getCompanyId()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("rf_shift_tracking", getString(R.string.tracking_title), NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        startForeground(9110, NotificationCompat.Builder(this, "rf_shift_tracking").setContentTitle(getString(R.string.tracking_title))
            .setContentText(getString(R.string.tracking_notice)).setSmallIcon(R.mipmap.ic_launcher).setOngoing(true).setContentIntent(open).build())
        scope.launch {
            val shift = db.fieldRecordDao().getShift(id)
            if (shift == null || shift.status != "ON_SHIFT" || shift.userId != userId || shift.companyId != companyId) {
                stopSelf(); return@launch
            }
            withContext(Dispatchers.Main) { beginUpdates() }
        }
        return START_NOT_STICKY
    }
    @SuppressLint("MissingPermission")
    private fun beginUpdates() {
        try {
            var available = false
            for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (manager?.isProviderEnabled(provider) == true) {
                    manager?.requestLocationUpdates(provider, 30000L, 20f, this, Looper.getMainLooper()); available = true
                }
            }
            trackingState.value = if (available) "WAITING" else "UNAVAILABLE"
        } catch (_: SecurityException) { trackingState.value = "UNAVAILABLE"; stopSelf() }
    }
    override fun onLocationChanged(location: Location) {
        val id = shiftId ?: return
        val user = userId ?: return; val company = companyId ?: return
        if (tokens.getUserId() != user || tokens.getCompanyId() != company) { stopSelf(); return }
        if (stoppedAt.value > 0L) return
        val capturedAt = location.time
        scope.launch {
            db.withTransaction {
                val shift = db.fieldRecordDao().getShift(id) ?: return@withTransaction
                if (shift.status != "ON_SHIFT" || shift.userId != user || shift.companyId != company || capturedAt < shift.startTime || capturedAt > System.currentTimeMillis() + 60000 || stoppedAt.value > 0) return@withTransaction
                db.shiftLocationDao().insertLocation(ShiftLocationEntity(UUID.randomUUID().toString(), id, user, company,
                    location.latitude, location.longitude, location.accuracy, capturedAt, false))
                trackingState.value = "ACTIVE"
                lastPointTime.value = capturedAt
            }
            sync.scheduleSync(user, company)
        }
    }
    override fun onProviderDisabled(provider: String) { trackingState.value = "UNAVAILABLE" }
    override fun onDestroy() { manager?.removeUpdates(this); scope.cancel(); if (trackingState.value != "UNAVAILABLE") trackingState.value = "STOPPED"; super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
    companion object {
        val trackingState = MutableStateFlow("STOPPED")
        val lastPointTime = MutableStateFlow(0L)
        private val stoppedAt = MutableStateFlow(0L)
        fun start(context: Context, shiftId: String) {
            stoppedAt.value = 0; trackingState.value = "WAITING"
            try { context.startForegroundService(Intent(context, ShiftTrackingService::class.java).putExtra("shiftId", shiftId)) }
            catch (_: Exception) { trackingState.value = "UNAVAILABLE" }
        }
        fun stop(context: Context) {
            stoppedAt.value = System.currentTimeMillis()
            trackingState.value = "STOPPED"
            context.stopService(Intent(context, ShiftTrackingService::class.java))
        }
    }
}
