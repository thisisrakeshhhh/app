package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "stock_checks")
data class StockCheckEntity(
    @PrimaryKey val id: String,
    val visitId: String = "",
    val retailerId: String = "",
    val productId: String,
    val productName: String = "",
    val observedQuantity: Int,
    val suggestedQuantity: Int = 0,
    val notes: String = "",
    val syncStatus: String = "PENDING", // PENDING, SYNCED, FAILED
    val timestamp: Long = System.currentTimeMillis()
)
