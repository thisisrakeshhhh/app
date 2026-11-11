package com.routeflow.app.core.design.map

enum class LogisticsMarkerType {
    RETAILER,
    DELIVERY_STOP,
    VEHICLE,
    WAREHOUSE_HUB
}

enum class LogisticsMarkerStatus {
    PENDING,
    IN_PROGRESS,
    COMPLETED,
    ALERT,
    VISITED,
    UNVISITED
}

/**
 * Unified spatial marker model used across Google Maps and the Logistics Canvas fallback.
 */
data class LogisticsMarker(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val latitude: Double,
    val longitude: Double,
    val type: LogisticsMarkerType,
    val status: LogisticsMarkerStatus = LogisticsMarkerStatus.PENDING,
    val sequenceNumber: Int? = null,
    val balancePaise: Long? = null,
    val creditLimitPaise: Long? = null,
    val address: String? = null,
    val contactPhone: String? = null,
    val extraTag: String? = null,
    val orderId: String? = null,
    val retailerId: String? = null
) {
    val hasValidCoordinates: Boolean
        get() = latitude != 0.0 && longitude != 0.0 &&
                latitude >= -90.0 && latitude <= 90.0 &&
                longitude >= -180.0 && longitude <= 180.0
}
