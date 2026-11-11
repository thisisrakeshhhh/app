package com.routeflow.app.data.repository

import android.content.Context
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.LocalShiftEntity
import com.routeflow.app.core.location.ShiftTrackingService
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.repository.ShiftRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkShiftRepository @Inject constructor(private val api: RouteFlowApi,
    @ApplicationContext private val context: Context, private val db: RouteFlowDatabase,
    private val tokens: TokenStorage, private val json: Json, private val events: DurableFieldRepository,
    private val session: SessionRepository) : ShiftRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    override val activeShift: StateFlow<ShiftDto?> = session.activeEmployee.flatMapLatest { employee ->
        if (employee == null) flowOf(null) else db.fieldRecordDao().observeShift(employee.id, tokens.getCompanyId().orEmpty())
            .map { it?.let { s -> ShiftDto(s.id, s.status, s.startTime, s.endTime) } }
    }.stateIn(scope, SharingStarted.Eagerly, null)

    override suspend fun startShift(latitude: Double?, longitude: Double?): Result<ShiftDto> = runCatching {
        val user = requireNotNull(tokens.getUserId()); val company = requireNotNull(tokens.getCompanyId())
        val current = db.fieldRecordDao().observeShift(user, company).first()
        if (current != null) {
            // Recovery requires an explicit user action; don't silently restart tracking.
            if (current.status == "ON_BREAK") resumeShift().getOrThrow()
            else ShiftTrackingService.start(context, current.id)
            return@runCatching ShiftDto(current.id, "ON_SHIFT", current.startTime)
        }
        val req = StartShiftRequest(latitude = latitude, longitude = longitude)
        val entity = LocalShiftEntity(req.shiftId, user, company, "ON_SHIFT", req.startTime)
        events.queue("SHIFT_START", json.encodeToString(req), req.idempotencyKey) { db.fieldRecordDao().saveShift(entity) }
        ShiftTrackingService.start(context, req.shiftId)
        ShiftDto(req.shiftId, "ON_SHIFT", req.startTime)
    }
    override suspend fun endShift(latitude: Double?, longitude: Double?): Result<ShiftDto> {
        ShiftTrackingService.stop(context)
        return runCatching {
            val user = requireNotNull(tokens.getUserId()); val company = requireNotNull(tokens.getCompanyId())
            val current = requireNotNull(db.fieldRecordDao().observeShift(user, company).first())
            val req = EndShiftRequest(shiftId = current.id, latitude = latitude, longitude = longitude)
            events.queue("SHIFT_END", json.encodeToString(req), req.idempotencyKey) { db.fieldRecordDao().saveShift(current.copy(status = "OFF_SHIFT", endTime = req.endTime)) }
            ShiftDto(current.id, "OFF_SHIFT", current.startTime, req.endTime)
        }
    }
    override suspend fun pauseShift(): Result<Unit> = changeBreak(true)
    override suspend fun resumeShift(): Result<Unit> = changeBreak(false)
    private suspend fun changeBreak(pause: Boolean): Result<Unit> {
        if (pause) ShiftTrackingService.stop(context)
        return runCatching {
            val current = requireNotNull(db.fieldRecordDao().observeShift(requireNotNull(tokens.getUserId()), requireNotNull(tokens.getCompanyId())).first())
            val req = ShiftPauseRequest(current.id)
            events.queue(if (pause) "SHIFT_PAUSE" else "SHIFT_RESUME", json.encodeToString(req), req.idempotencyKey) {
                db.fieldRecordDao().saveShift(current.copy(status = if (pause) "ON_BREAK" else "ON_SHIFT"))
            }
            if (!pause) ShiftTrackingService.start(context, current.id)
        }
    }
    override suspend fun uploadLocations(shiftId: String, points: List<LocationPoint>): Result<Unit> = runCatching {
        events.queue("LOCATIONS", json.encodeToString(ShiftLocationsRequest(shiftId, points)), "locations_${points.first().id}")
    }
    override suspend fun getTeamStatus(): Result<List<TeamMemberStatusDto>> = runCatching { api.getTeamStatus() }
}
