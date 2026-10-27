package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "planned_routes",
    indices = [
        Index(value = ["companyId", "routeDate"]),
        Index(value = ["companyId", "salespersonId", "status"])
    ]
)
data class PlannedRouteEntity(
    @PrimaryKey
    val id: String,
    val companyId: String,
    val routeDate: String, // "YYYY-MM-DD"
    val name: String,
    val salespersonId: String,
    val salespersonName: String,
    val status: String, // "DRAFT", "PUBLISHED", "CANCELLED"
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
    val createdAt: Long,
    val updatedAt: Long,
    val syncStatus: String = "SYNCED"
)
