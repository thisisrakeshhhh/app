package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "visits")
data class VisitEntity(
    @PrimaryKey val id: String,
    val retailerId: String,
    val employeeId: String,
    val checkInTime: Long,
    val checkOutTime: Long? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val accuracy: Float? = null,
    val status: String // ACTIVE, COMPLETED
)
