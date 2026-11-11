package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "payments")
data class PaymentEntity(
    @PrimaryKey val id: String,
    val orderId: String,
    val retailerId: String,
    val amountPaise: Long,
    val method: String, // CASH, CREDIT
    val timestamp: Long
)
