package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "retailers")
data class RetailerEntity(
    @PrimaryKey val id: String,
    val name: String,
    val beatId: String,
    val address: String,
    val contactNumber: String,
    val latitude: Double,
    val longitude: Double,
    val creditLimitPaise: Long,
    val outstandingAmountPaise: Long
)
