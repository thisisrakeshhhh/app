package com.routeflow.app.core.network.dto

import kotlinx.serialization.Serializable

@Serializable
data class UpdateStopStatusRequest(
    val status: String,
    val notes: String? = null,
    val visitedAt: Long? = null,
    val clientTimestamp: Long = System.currentTimeMillis()
)

@Serializable
data class PlannedRouteStopNetworkDto(
    val id: String,
    val route_id: String? = null,
    val company_id: String? = null,
    val retailer_id: String? = null,
    val retailer_name: String? = null,
    val stop_sequence: Int? = null,
    val address: String? = null,
    val contact_number: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val status: String,
    val visited_at: Long? = null,
    val notes: String? = null,
    val updated_at: Long? = null
)

@Serializable
data class PlannedRouteNetworkDto(
    val id: String,
    val company_id: String? = null,
    val route_date: String? = null,
    val name: String,
    val salesperson_id: String? = null,
    val salesperson_name: String? = null,
    val status: String,
    val total_stops: Int = 0,
    val road_distance_meters: Double = 0.0,
    val road_duration_seconds: Double = 0.0,
    val route_geometry: String? = null,
    val routing_provider: String? = "OSRM",
    val routing_calculated_at: Long? = null,
    val version: Int = 1,
    val published_at: Long? = null,
    val published_by: String? = null,
    val cancelled_at: Long? = null,
    val cancelled_by: String? = null,
    val cancellation_reason: String? = null,
    val created_by: String? = null,
    val created_at: Long? = null,
    val updated_at: Long? = null
)

@Serializable
data class PlannedRouteDetailResponse(
    val success: Boolean,
    val route: PlannedRouteNetworkDto? = null,
    val stops: List<PlannedRouteStopNetworkDto>? = null,
    val error: String? = null
)

@Serializable
data class PlannedRoutesListResponse(
    val success: Boolean,
    val routes: List<PlannedRouteNetworkDto> = emptyList(),
    val error: String? = null
)

@Serializable
data class UpdateStopStatusResponse(
    val success: Boolean,
    val stop: PlannedRouteStopNetworkDto? = null,
    val idempotent: Boolean = false,
    val ignoredStale: Boolean = false,
    val message: String? = null
)

@Serializable
data class RouteStopStatusSyncPayload(
    val routeId: String,
    val stopId: String,
    val status: String,
    val visitedAt: Long?,
    val notes: String?,
    val clientTimestamp: Long
)
