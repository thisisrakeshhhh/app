package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "delivery_records")
data class DeliveryRecordEntity(
    @PrimaryKey val id: String,
    val orderId: String,
    val deliveryCode: String,
    val deliveredAt: Long? = null,
    val recipientName: String? = null,
    val status: String // PENDING, DELIVERED
)
