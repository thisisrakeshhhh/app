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
    val status: String,
    val visited_at: Long? = null,
    val notes: String? = null,
    val updated_at: Long? = null
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
