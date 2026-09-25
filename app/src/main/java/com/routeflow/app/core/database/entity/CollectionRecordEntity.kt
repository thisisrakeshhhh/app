package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "collection_records")
data class CollectionRecordEntity(
    @PrimaryKey val id: String,
    val receiptId: String,
    val retailerId: String,
    val retailerName: String,
    val amountPaise: Long,
    val paymentMethod: String, // CASH, UPI, CHEQUE
    val notes: String? = null,
    val collectedBy: String,
    val companyId: String,
    val timestamp: Long,
    val isSynced: Boolean = false
)
