package com.routeflow.app.data.repository

import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.AssignBeatRequest
import com.routeflow.app.core.network.dto.BeatDto
import com.routeflow.app.core.network.dto.CreateBeatRequest
import com.routeflow.app.domain.repository.BeatRepository
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfflineBeatRepository @Inject constructor(
    private val api: RouteFlowApi
) : BeatRepository {

    override suspend fun getBeats(): Result<List<BeatDto>> = try {
        Result.success(api.getBeats())
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun createBeat(request: CreateBeatRequest): Result<BeatDto> = try {
        val resp = api.createBeat(request)
        if (resp.success && resp.beat != null) {
            Result.success(resp.beat)
        } else {
            Result.failure(Exception("Failed to create beat"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun assignBeat(beatId: String, userId: String): Result<Unit> = try {
        val resp = api.assignBeat(beatId, AssignBeatRequest(userId))
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to assign beat"))
    } catch (e: Exception) {
        Result.failure(e)
    }
}
