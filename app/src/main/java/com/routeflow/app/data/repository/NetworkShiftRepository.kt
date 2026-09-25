package com.routeflow.app.data.repository

import android.content.Context
import android.content.Intent
import android.os.Build
import com.routeflow.app.core.location.ShiftTrackingService
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.EndShiftRequest
import com.routeflow.app.core.network.dto.LocationPoint
import com.routeflow.app.core.network.dto.ShiftDto
import com.routeflow.app.core.network.dto.ShiftLocationsRequest
import com.routeflow.app.core.network.dto.StartShiftRequest
import com.routeflow.app.core.network.dto.TeamMemberStatusDto
import com.routeflow.app.domain.repository.ShiftRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkShiftRepository @Inject constructor(
    private val api: RouteFlowApi,
    @ApplicationContext private val context: Context
) : ShiftRepository {

    private val _activeShift = MutableStateFlow<ShiftDto?>(null)
    override val activeShift: StateFlow<ShiftDto?> = _activeShift.asStateFlow()

    override suspend fun startShift(latitude: Double?, longitude: Double?): Result<ShiftDto> = try {
        val resp = api.startShift(StartShiftRequest(latitude = latitude, longitude = longitude))
        if (resp.success && resp.shift != null) {
            _activeShift.value = resp.shift
            // Start foreground GPS service
            val serviceIntent = Intent(context, ShiftTrackingService::class.java).apply {
                putExtra(ShiftTrackingService.EXTRA_SHIFT_ID, resp.shift.id)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Result.success(resp.shift)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to start shift"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun endShift(latitude: Double?, longitude: Double?): Result<ShiftDto> = try {
        val resp = api.endShift(EndShiftRequest(latitude = latitude, longitude = longitude))
        if (resp.success && resp.shift != null) {
            _activeShift.value = null
            // Stop foreground GPS service
            val serviceIntent = Intent(context, ShiftTrackingService::class.java).apply {
                action = ShiftTrackingService.ACTION_STOP_TRACKING
            }
            context.startService(serviceIntent)
            Result.success(resp.shift)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to end shift"))
        }
    } catch (e: Exception) {
        Result.failure(e)
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
