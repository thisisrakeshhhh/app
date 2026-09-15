package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "orders")
data class OrderEntity(
    @PrimaryKey val id: String,
    val retailerId: String,
    val employeeId: String,
    val status: String,
    val totalAmountPaise: Long,
    val createdAt: Long,
    val updatedAt: Long,
    val rejectionReason: String? = null
)
