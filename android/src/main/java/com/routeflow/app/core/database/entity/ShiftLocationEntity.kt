package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "shift_locations_outbox")
data class ShiftLocationEntity(
    @PrimaryKey val id: String,
    val shiftId: String,
    val userId: String,
    val companyId: String,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val timestamp: Long,
    val isSynced: Boolean = false
)
