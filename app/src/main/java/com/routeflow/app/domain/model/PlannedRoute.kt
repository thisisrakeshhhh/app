package com.routeflow.app.domain.model

enum class RouteStatus {
    DRAFT,
    PUBLISHED,
    CANCELLED
}

enum class StopStatus {
    PENDING,
    VISITED,
    SKIPPED
}

data class PlannedRouteStop(
    val id: String,
    val routeId: String,
    val companyId: String,
    val retailerId: String,
    val retailerName: String,
    val stopSequence: Int,
    val address: String = "",
    val contactNumber: String = "",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    val status: StopStatus = StopStatus.PENDING,
    val visitedAt: Long? = null,
    val notes: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

data class PlannedRoute(
    val id: String,
    val companyId: String,
    val routeDate: String, // "YYYY-MM-DD"
    val name: String,
    val salespersonId: String,
    val salespersonName: String,
    val status: RouteStatus = RouteStatus.DRAFT,
    val totalStops: Int = 0,
    val roadDistanceMeters: Double = 0.0,
    val roadDurationSeconds: Double = 0.0,
    val routeGeometry: String? = null,
    val routingProvider: String = "OSRM",
    val routingCalculatedAt: Long? = null,
    val version: Int = 1,
    val publishedAt: Long? = null,
    val publishedBy: String? = null,
    val cancelledAt: Long? = null,
    val cancelledBy: String? = null,
    val cancellationReason: String? = null,
    val createdBy: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val stops: List<PlannedRouteStop> = emptyList()
)
