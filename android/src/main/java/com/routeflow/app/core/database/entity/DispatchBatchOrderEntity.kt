package com.routeflow.app.core.database.entity

import androidx.room.Entity

@Entity(tableName = "dispatch_batch_orders", primaryKeys = ["dispatchBatchId", "orderId"])
data class DispatchBatchOrderEntity(
    val dispatchBatchId: String,
    val orderId: String,
    val cartonsCount: Int = 1,
    val createdAt: Long = System.currentTimeMillis()
)
