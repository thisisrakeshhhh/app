package com.routeflow.app.data.repository

import android.content.Context
import android.content.Intent
import android.os.Build
import com.routeflow.app.core.database.dao.SyncOutboxDao
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.location.ShiftTrackingService
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.EndShiftRequest
import com.routeflow.app.core.network.dto.LocationPoint
import com.routeflow.app.core.network.dto.ShiftDto
import com.routeflow.app.core.network.dto.ShiftLocationsRequest
import com.routeflow.app.core.network.dto.StartShiftRequest
import com.routeflow.app.core.network.dto.TeamMemberStatusDto
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.repository.ShiftRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkShiftRepository @Inject constructor(
    private val api: RouteFlowApi,
    @ApplicationContext private val context: Context,
    private val syncOutboxDao: SyncOutboxDao,
    private val tokenStorage: TokenStorage,
    private val json: Json
) : ShiftRepository {

    private val prefs = context.getSharedPreferences("rf_shift_prefs", Context.MODE_PRIVATE)
    private val _activeShift = MutableStateFlow<ShiftDto?>(restoreSavedShift())
    override val activeShift: StateFlow<ShiftDto?> = _activeShift.asStateFlow()

    private fun restoreSavedShift(): ShiftDto? {
        val raw = prefs.getString("active_shift", null) ?: return null
        return try {
            json.decodeFromString<ShiftDto>(raw)
        } catch (_: Exception) {
            null
        }
    }

    override suspend fun startShift(latitude: Double?, longitude: Double?): Result<ShiftDto> = try {
        val resp = api.startShift(StartShiftRequest(latitude = latitude, longitude = longitude))
        if (resp.success && resp.shift != null) {
            _activeShift.value = resp.shift
            prefs.edit().putString("active_shift", json.encodeToString(resp.shift)).apply()

            // Start foreground GPS service
            ShiftTrackingService.start(context, resp.shift.id)
            Result.success(resp.shift)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to start shift"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun endShift(latitude: Double?, longitude: Double?): Result<ShiftDto> {
        // 1. Immediately stop foreground GPS service locally before network call
        ShiftTrackingService.stop(context)

        val currentShift = _activeShift.value
        _activeShift.value = null
        prefs.edit().remove("active_shift").apply()

        val endReq = EndShiftRequest(latitude = latitude, longitude = longitude)
        return try {
            val resp = api.endShift(endReq)
            if (resp.success && resp.shift != null) {
                Result.success(resp.shift)
            } else {
                enqueueShiftEnd(endReq, currentShift?.id)
                Result.success(fallbackCompletedShift(currentShift, latitude, longitude))
            }
        } catch (e: Exception) {
            // Offline or network error: durable queue in sync_outbox
            enqueueShiftEnd(endReq, currentShift?.id)
            Result.success(fallbackCompletedShift(currentShift, latitude, longitude))
        }
    }

    private suspend fun enqueueShiftEnd(req: EndShiftRequest, shiftId: String?) {
        try {
            syncOutboxDao.insertSyncItem(
                SyncOutboxEntity(
                    type = "SHIFT_END",
                    payload = json.encodeToString(req),
                    idempotencyKey = "shift_end_${shiftId ?: System.currentTimeMillis()}",
                    userId = tokenStorage.getUserId().orEmpty(),
                    companyId = tokenStorage.getCompanyId().orEmpty()
                )
            )
        } catch (_: Exception) {}
    }

    private fun fallbackCompletedShift(currentShift: ShiftDto?, lat: Double?, lng: Double?): ShiftDto {
        val now = System.currentTimeMillis()
        return currentShift?.copy(
            status = "OFF_SHIFT",
            endTime = now
        ) ?: ShiftDto(
            id = "shift_ended_$now",
            status = "OFF_SHIFT",
            startTime = now,
            endTime = now
        )
    }

    override suspend fun uploadLocations(shiftId: String, points: List<LocationPoint>): Result<Unit> = try {
        val resp = api.uploadShiftLocations(ShiftLocationsRequest(shiftId = shiftId, points = points))
        if (resp.success) Result.success(Unit) else Result.failure(Exception("Failed to upload locations"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getTeamStatus(): Result<List<TeamMemberStatusDto>> = try {
        Result.success(api.getTeamStatus())
    } catch (e: Exception) {
        Result.failure(e)
    }
}
