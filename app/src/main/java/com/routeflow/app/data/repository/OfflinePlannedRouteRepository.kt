package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.PlannedRouteDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.entity.PlannedRouteEntity
import com.routeflow.app.core.database.entity.PlannedRouteStopEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.dto.RouteStopStatusSyncPayload
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.data.sync.SyncManager
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.model.StopStatus
import com.routeflow.app.domain.repository.PlannedRouteRepository
import com.routeflow.app.domain.repository.RoadCalculationResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfflinePlannedRouteRepository @Inject constructor(
    private val database: RouteFlowDatabase,
    private val plannedRouteDao: PlannedRouteDao,
    private val retailerDao: RetailerDao,
    private val tokenStorage: TokenStorage,
    private val syncManager: SyncManager,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : PlannedRouteRepository {

    override fun observeAllRoutes(companyId: String): Flow<List<PlannedRoute>> =
        plannedRouteDao.observeAllRoutes(companyId).map { entities ->
            entities.map { it.toDomain() }
        }

    override fun observeRoutesByDate(companyId: String, date: String): Flow<List<PlannedRoute>> =
        plannedRouteDao.observeRoutesByDate(companyId, date).map { entities ->
            entities.map { it.toDomain() }
        }

    override fun observePublishedRoutesForSalesperson(
        companyId: String,
        salespersonId: String
    ): Flow<List<PlannedRoute>> =
        plannedRouteDao.observePublishedRoutesForSalesperson(companyId, salespersonId).map { entities ->
            entities.map { it.toDomain() }
        }

    override fun observeTodayRouteForSalesperson(
        companyId: String,
        salespersonId: String,
        date: String
    ): Flow<PlannedRoute?> =
        plannedRouteDao.observeTodayPublishedRouteForSalesperson(companyId, salespersonId, date).map { it?.toDomain() }

    override suspend fun getRouteById(routeId: String): PlannedRoute? {
        val entity = plannedRouteDao.getRouteById(routeId) ?: return null
        val stops = plannedRouteDao.getStopsForRoute(routeId).map { it.toDomain() }
        return entity.toDomain(stops)
    }

    override fun observeStopsForRoute(routeId: String): Flow<List<PlannedRouteStop>> =
        plannedRouteDao.observeStopsForRoute(routeId).map { entities ->
            entities.map { it.toDomain() }
        }

    override suspend fun calculateRoad(coordinates: List<Pair<Double, Double>>): Result<RoadCalculationResult> =
        withContext(Dispatchers.IO) {
            try {
                if (coordinates.size < 2) {
                    return@withContext Result.success(
                        RoadCalculationResult(
                            distanceMeters = 0.0,
                            durationSeconds = 0.0,
                            geometry = null,
                            provider = "NONE",
                            isFallback = false
                        )
                    )
                }

                // Attempt OSRM driving route via direct public router or configured base
                try {
                    val coordsParam = coordinates.joinToString(";") { (lat, lon) ->
                        // OSRM format is longitude,latitude
                        String.format(java.util.Locale.US, "%.6f,%.6f", lon, lat)
                    }
                    val urlString = "https://router.project-osrm.org/route/v1/driving/$coordsParam?overview=full&geometries=polyline6&steps=false"
                    val url = URL(urlString)
                    val conn = url.openConnection() as HttpURLConnection
                    conn.connectTimeout = 4000
                    conn.readTimeout = 4000
                    conn.requestMethod = "GET"
                    conn.setRequestProperty("Accept", "application/json")

                    if (conn.responseCode == 200) {
                        val reader = BufferedReader(InputStreamReader(conn.inputStream))
                        val responseText = reader.readText()
                        reader.close()

                        val json = JSONObject(responseText)
                        if (json.optString("code") == "Ok") {
                            val routes = json.getJSONArray("routes")
                            if (routes.length() > 0) {
                                val firstRoute = routes.getJSONObject(0)
                                val distance = firstRoute.optDouble("distance", 0.0)
                                val duration = firstRoute.optDouble("duration", 0.0)
                                val geometry = if (firstRoute.has("geometry")) firstRoute.getString("geometry") else null

                                return@withContext Result.success(
                                    RoadCalculationResult(
                                        distanceMeters = distance,
                                        durationSeconds = duration,
                                        geometry = geometry,
                                        provider = "OSRM",
                                        isFallback = false
                                    )
                                )
                            }
                        }
                    }
                } catch (_: Exception) {
                    // Network timeout or offline - use graceful haversine fallback
                }

                // Fallback: Haversine distance and 25 km/h driving duration
                var totalDistance = 0.0
                for (i in 1 until coordinates.size) {
                    totalDistance += haversineDistanceMeters(
                        coordinates[i - 1].first, coordinates[i - 1].second,
                        coordinates[i].first, coordinates[i].second
                    )
                }
                // 25 km/h = ~6.94 m/s
                val durationSec = (totalDistance / (25.0 * 1000.0 / 3600.0))

                Result.success(
                    RoadCalculationResult(
                        distanceMeters = totalDistance,
                        durationSeconds = durationSec,
                        geometry = null,
                        provider = "HAVERSINE_FALLBACK",
                        isFallback = true
                    )
                )
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    override suspend fun createDraftRoute(
        routeDate: String,
        name: String,
        salespersonId: String,
        salespersonName: String,
        stops: List<PlannedRouteStop>
    ): Result<PlannedRoute> = withContext(Dispatchers.IO) {
        try {
            val companyId = tokenStorage.getCompanyId() ?: "comp_1"
            val userId = tokenStorage.getUserId() ?: "owner"
            val routeId = UUID.randomUUID().toString()
            val now = System.currentTimeMillis()

            // Calculate road metrics
            val coords = stops.filter { it.latitude != 0.0 && it.longitude != 0.0 }
                .map { Pair(it.latitude, it.longitude) }
            val routing = calculateRoad(coords).getOrDefault(
                RoadCalculationResult(0.0, 0.0, null, "NONE", false)
            )

            val routeEntity = PlannedRouteEntity(
                id = routeId,
                companyId = companyId,
                routeDate = routeDate,
                name = name.trim(),
                salespersonId = salespersonId,
                salespersonName = salespersonName,
                status = RouteStatus.DRAFT.name,
                totalStops = stops.size,
                roadDistanceMeters = routing.distanceMeters,
                roadDurationSeconds = routing.durationSeconds,
                routeGeometry = routing.geometry,
                routingProvider = routing.provider,
                routingCalculatedAt = now,
                version = 1,
                createdBy = userId,
                createdAt = now,
                updatedAt = now,
                syncStatus = "PENDING_CREATE"
            )

            val stopEntities = stops.mapIndexed { idx, s ->
                PlannedRouteStopEntity(
                    id = if (s.id.isBlank()) UUID.randomUUID().toString() else s.id,
                    routeId = routeId,
                    companyId = companyId,
                    retailerId = s.retailerId,
                    retailerName = s.retailerName,
                    stopSequence = idx + 1,
                    address = s.address,
                    contactNumber = s.contactNumber,
                    latitude = s.latitude,
                    longitude = s.longitude,
                    status = StopStatus.PENDING.name,
                    visitedAt = null,
                    notes = s.notes,
                    createdAt = now,
                    updatedAt = now
                )
            }

            plannedRouteDao.replaceRouteWithStops(routeEntity, stopEntities)
            Result.success(routeEntity.toDomain(stopEntities.map { it.toDomain() }))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun updateDraftRoute(
        routeId: String,
        routeDate: String,
        name: String,
        salespersonId: String,
        salespersonName: String,
        stops: List<PlannedRouteStop>
    ): Result<PlannedRoute> = withContext(Dispatchers.IO) {
        try {
            val existing = plannedRouteDao.getRouteById(routeId)
                ?: return@withContext Result.failure(IllegalStateException("Route not found: $routeId"))

            if (existing.status != RouteStatus.DRAFT.name) {
                return@withContext Result.failure(IllegalStateException("Cannot modify non-draft route: ${existing.status}"))
            }

            val now = System.currentTimeMillis()
            val coords = stops.filter { it.latitude != 0.0 && it.longitude != 0.0 }
                .map { Pair(it.latitude, it.longitude) }
            val routing = calculateRoad(coords).getOrDefault(
                RoadCalculationResult(0.0, 0.0, null, "NONE", false)
            )

            val updatedEntity = existing.copy(
                routeDate = routeDate,
                name = name.trim(),
                salespersonId = salespersonId,
                salespersonName = salespersonName,
                totalStops = stops.size,
                roadDistanceMeters = routing.distanceMeters,
                roadDurationSeconds = routing.durationSeconds,
                routeGeometry = routing.geometry,
                routingProvider = routing.provider,
                routingCalculatedAt = now,
                version = existing.version + 1,
                updatedAt = now,
                syncStatus = "PENDING_UPDATE"
            )

            val stopEntities = stops.mapIndexed { idx, s ->
                PlannedRouteStopEntity(
                    id = if (s.id.isBlank()) UUID.randomUUID().toString() else s.id,
                    routeId = routeId,
                    companyId = existing.companyId,
                    retailerId = s.retailerId,
                    retailerName = s.retailerName,
                    stopSequence = idx + 1,
                    address = s.address,
                    contactNumber = s.contactNumber,
                    latitude = s.latitude,
                    longitude = s.longitude,
                    status = s.status.name,
                    visitedAt = s.visitedAt,
                    notes = s.notes,
                    createdAt = s.createdAt,
                    updatedAt = now
                )
            }

            plannedRouteDao.replaceRouteWithStops(updatedEntity, stopEntities)
            Result.success(updatedEntity.toDomain(stopEntities.map { it.toDomain() }))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun publishRoute(routeId: String): Result<PlannedRoute> = withContext(Dispatchers.IO) {
        try {
            val existing = plannedRouteDao.getRouteById(routeId)
                ?: return@withContext Result.failure(IllegalStateException("Route not found: $routeId"))

            if (existing.status == RouteStatus.PUBLISHED.name) {
                val stops = plannedRouteDao.getStopsForRoute(routeId).map { it.toDomain() }
                return@withContext Result.success(existing.toDomain(stops))
            }

            if (existing.status != RouteStatus.DRAFT.name) {
                return@withContext Result.failure(IllegalStateException("Cannot publish route with status ${existing.status}"))
            }

            if (existing.totalStops < 1) {
                return@withContext Result.failure(IllegalStateException("Cannot publish route with zero stops"))
            }

            val userId = tokenStorage.getUserId() ?: "owner"
            val now = System.currentTimeMillis()

            // STRICT BUSINESS RULE: Publishing route does NOT modify inventory or create orders.
            val publishedEntity = existing.copy(
                status = RouteStatus.PUBLISHED.name,
                publishedAt = now,
                publishedBy = userId,
                updatedAt = now,
                syncStatus = "PENDING_UPDATE"
            )

            plannedRouteDao.updateRoute(publishedEntity)
            val stops = plannedRouteDao.getStopsForRoute(routeId).map { it.toDomain() }
            Result.success(publishedEntity.toDomain(stops))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun cancelRoute(routeId: String, reason: String?): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val existing = plannedRouteDao.getRouteById(routeId)
                ?: return@withContext Result.failure(IllegalStateException("Route not found: $routeId"))

            val userId = tokenStorage.getUserId() ?: "owner"
            val now = System.currentTimeMillis()

            val cancelledEntity = existing.copy(
                status = RouteStatus.CANCELLED.name,
                cancelledAt = now,
                cancelledBy = userId,
                cancellationReason = reason ?: "Cancelled by owner",
                updatedAt = now,
                syncStatus = "PENDING_UPDATE"
            )

            plannedRouteDao.updateRoute(cancelledEntity)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun updateStopStatus(
        stopId: String,
        routeId: String,
        status: StopStatus,
        notes: String?
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val userId = tokenStorage.getUserId()
            val companyId = tokenStorage.getCompanyId()
            if (userId.isNullOrBlank() || companyId.isNullOrBlank()) {
                return@withContext Result.failure(
                    IllegalStateException("Cannot sync route stop: authenticated user and company identity required")
                )
            }

            val existing = plannedRouteDao.getStopById(stopId)
                ?: return@withContext Result.failure(IllegalStateException("Stop not found: $stopId"))

            val now = System.currentTimeMillis()
            val visitedAt = if (status == StopStatus.VISITED) (existing.visitedAt ?: now) else null

            database.withTransaction {
                // 1. Local SQLite update for instant UI responsiveness
                plannedRouteDao.updateStopStatus(
                    stopId = stopId,
                    status = status.name,
                    visitedAt = visitedAt,
                    notes = notes ?: existing.notes,
                    updatedAt = now
                )

                // 2. Atomic Outbox Enqueue with a stable unique event UUID
                val eventId = UUID.randomUUID().toString()
                val payloadObj = RouteStopStatusSyncPayload(
                    routeId = routeId,
                    stopId = stopId,
                    status = status.name,
                    visitedAt = visitedAt,
                    notes = notes ?: existing.notes,
                    clientTimestamp = now
                )
                val outboxItem = SyncOutboxEntity(
                    type = "ROUTE_STOP_STATUS",
                    payload = json.encodeToString(payloadObj),
                    idempotencyKey = "stop_status_${eventId}",
                    userId = userId,
                    companyId = companyId,
                    createdAt = now,
                    syncState = "SAVED_OFFLINE"
                )
                database.syncOutboxDao().insertSyncItem(outboxItem)
            }

            // 3. Dispatch via WorkManager using account-scoped sync manager
            try {
                syncManager.scheduleSync(userId, companyId)
            } catch (_: Exception) {}
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun haversineDistanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return r * c
    }

    private fun PlannedRouteEntity.toDomain(stops: List<PlannedRouteStop> = emptyList()): PlannedRoute =
        PlannedRoute(
            id = id,
            companyId = companyId,
            routeDate = routeDate,
            name = name,
            salespersonId = salespersonId,
            salespersonName = salespersonName,
            status = try { RouteStatus.valueOf(status) } catch (_: Exception) { RouteStatus.DRAFT },
            totalStops = totalStops,
            roadDistanceMeters = roadDistanceMeters,
            roadDurationSeconds = roadDurationSeconds,
            routeGeometry = routeGeometry,
            routingProvider = routingProvider,
            routingCalculatedAt = routingCalculatedAt,
            version = version,
            publishedAt = publishedAt,
            publishedBy = publishedBy,
            cancelledAt = cancelledAt,
            cancelledBy = cancelledBy,
            cancellationReason = cancellationReason,
            createdBy = createdBy,
            createdAt = createdAt,
            updatedAt = updatedAt,
            stops = stops
        )

    private fun PlannedRouteStopEntity.toDomain(): PlannedRouteStop =
        PlannedRouteStop(
            id = id,
            routeId = routeId,
            companyId = companyId,
            retailerId = retailerId,
            retailerName = retailerName,
            stopSequence = stopSequence,
            address = address,
            contactNumber = contactNumber,
            latitude = latitude,
            longitude = longitude,
            status = try { StopStatus.valueOf(status) } catch (_: Exception) { StopStatus.PENDING },
            visitedAt = visitedAt,
            notes = notes,
            createdAt = createdAt,
            updatedAt = updatedAt
        )
}
