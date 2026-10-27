package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "planned_route_stops",
    foreignKeys = [
        ForeignKey(
            entity = PlannedRouteEntity::class,
            parentColumns = ["id"],
            childColumns = ["routeId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["routeId", "stopSequence"], unique = true),
        Index(value = ["routeId", "retailerId"], unique = true),
        Index(value = ["companyId", "retailerId"])
    ]
)
data class PlannedRouteStopEntity(
    @PrimaryKey
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
    val status: String = "PENDING", // "PENDING", "VISITED", "SKIPPED"
    val visitedAt: Long? = null,
    val notes: String? = null,
    val createdAt: Long,
    val updatedAt: Long
)
