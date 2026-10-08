package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "stock_movements")
data class StockMovementEntity(
    @PrimaryKey val id: String,
    val companyId: String,
    val productId: String,
    val batchId: String? = null,
    val movementType: String,
    val quantity: Int,
    val stockBefore: Int,
    val stockAfter: Int,
    val reason: String,
    val notes: String? = null,
    val createdBy: String,
    val createdAt: Long = System.currentTimeMillis(),
    val syncStatus: String = "SYNCED"
)
