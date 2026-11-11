package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.LocationPoint
import com.routeflow.app.core.network.dto.ShiftDto
import com.routeflow.app.core.network.dto.TeamMemberStatusDto
import kotlinx.coroutines.flow.StateFlow

interface ShiftRepository {
    val activeShift: StateFlow<ShiftDto?>
    suspend fun startShift(latitude: Double?, longitude: Double?): Result<ShiftDto>
    suspend fun endShift(latitude: Double?, longitude: Double?): Result<ShiftDto>
    suspend fun pauseShift(): Result<Unit>
    suspend fun resumeShift(): Result<Unit>
    suspend fun uploadLocations(shiftId: String, points: List<LocationPoint>): Result<Unit>
    suspend fun getTeamStatus(): Result<List<TeamMemberStatusDto>>
}
