package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "warehouse_returns")
data class WarehouseReturnEntity(
    @PrimaryKey val id: String,
    val companyId: String,
    val orderId: String? = null,
    val productId: String,
    val quantity: Int,
    val condition: String, // SALEABLE, DAMAGED, EXPIRED, MISSING
    val photoUrl: String? = null,
    val actionTaken: String,
    val notes: String? = null,
    val inspectedBy: String,
    val createdAt: Long = System.currentTimeMillis(),
    val syncStatus: String = "SYNCED"
)
