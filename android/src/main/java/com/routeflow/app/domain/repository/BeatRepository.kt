package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.BeatDto
import com.routeflow.app.core.network.dto.CreateBeatRequest

interface BeatRepository {
    suspend fun getBeats(): Result<List<BeatDto>>
    suspend fun createBeat(request: CreateBeatRequest): Result<BeatDto>
    suspend fun assignBeat(beatId: String, userId: String): Result<Unit>
}
