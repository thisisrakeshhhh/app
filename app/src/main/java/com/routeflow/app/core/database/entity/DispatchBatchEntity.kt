package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "dispatch_batches")
data class DispatchBatchEntity(
    @PrimaryKey val id: String,
    val companyId: String,
    val batchCode: String,
    val deliveryExecutiveId: String? = null,
    val routeId: String? = null,
    val status: String = "CREATED",
    val totalOrders: Int = 0,
    val totalCartons: Int = 0,
    val createdBy: String,
    val notes: String? = null,
    val handedOverAt: Long? = null,
    val receivedByDriverAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val syncStatus: String = "SYNCED"
)
