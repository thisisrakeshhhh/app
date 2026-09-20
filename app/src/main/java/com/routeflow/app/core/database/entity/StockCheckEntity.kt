package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "stock_checks")
data class StockCheckEntity(
    @PrimaryKey val id: String,
    val visitId: String,
    val productId: String,
    val observedQuantity: Int,
    val timestamp: Long
)
