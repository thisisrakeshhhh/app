package com.routeflow.app.domain.repository

import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.StopStatus
import kotlinx.coroutines.flow.Flow

data class RoadCalculationResult(
    val distanceMeters: Double,
    val durationSeconds: Double,
    val geometry: String?,
    val provider: String,
    val isFallback: Boolean
)

interface PlannedRouteRepository {
    fun observeAllRoutes(companyId: String): Flow<List<PlannedRoute>>
    fun observeRoutesByDate(companyId: String, date: String): Flow<List<PlannedRoute>>
    fun observePublishedRoutesForSalesperson(companyId: String, salespersonId: String): Flow<List<PlannedRoute>>
    fun observeTodayRouteForSalesperson(companyId: String, salespersonId: String, date: String): Flow<PlannedRoute?>
    suspend fun getRouteById(routeId: String): PlannedRoute?
    fun observeStopsForRoute(routeId: String): Flow<List<PlannedRouteStop>>
    suspend fun calculateRoad(coordinates: List<Pair<Double, Double>>): Result<RoadCalculationResult>
    suspend fun createDraftRoute(
        routeDate: String,
        name: String,
        salespersonId: String,
        salespersonName: String,
        stops: List<PlannedRouteStop>
    ): Result<PlannedRoute>
    suspend fun updateDraftRoute(
        routeId: String,
        routeDate: String,
        name: String,
        salespersonId: String,
        salespersonName: String,
        stops: List<PlannedRouteStop>
    ): Result<PlannedRoute>
    suspend fun publishRoute(routeId: String): Result<PlannedRoute>
    suspend fun cancelRoute(routeId: String, reason: String?): Result<Unit>
    suspend fun updateStopStatus(stopId: String, routeId: String, status: StopStatus, notes: String?): Result<Unit>
}
