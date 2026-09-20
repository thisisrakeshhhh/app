package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "order_items")
data class OrderItemEntity(
    @PrimaryKey val id: String,
    val orderId: String,
    val productId: String,
    val quantity: Int,
    val freeQuantity: Int,
    val pricePaiseAtTime: Long,
    val isPicked: Boolean = false // Added for persisted picking
)
