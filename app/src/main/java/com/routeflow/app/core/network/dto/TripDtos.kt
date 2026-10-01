package com.routeflow.app.core.network.dto

import kotlinx.serialization.Serializable

@Serializable
data class TripStopDto(
    val orderId: String,
    val retailerId: String,
    val retailerName: String,
    val address: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val sequenceOrder: Int,
    val totalAmountPaise: Long,
    val status: String, // ASSIGNED, OUT_FOR_DELIVERY, DELIVERED, PARTIALLY_DELIVERED, FAILED
    val deliveredAmountPaise: Long = 0,
    val failureReason: String? = null
)

@Serializable
data class TripDto(
    val id: String,
    val tripNumber: String,
    val driverId: String,
    val driverName: String? = null,
    val vehicleNumber: String,
    val routeArea: String,
    val status: String, // CREATED, IN_TRANSIT, COMPLETED
    val startTime: Long,
    val endTime: Long? = null,
    val totalStops: Int = 0,
    val completedStops: Int = 0,
    val failedStops: Int = 0,
    val totalValuePaise: Long = 0,
    val cashCollectedPaise: Long = 0,
    val stops: List<TripStopDto> = emptyList()
)

@Serializable
data class CreateTripRequest(
    val driverId: String,
    val vehicleNumber: String,
    val routeArea: String,
    val orderIds: List<String>,
    val startTime: Long = System.currentTimeMillis()
)

@Serializable
data class ReorderStopsRequest(
    val stopOrder: List<String> // list of orderIds in sequence
)
