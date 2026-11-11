package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "product_batches")
data class ProductBatchEntity(
    @PrimaryKey val id: String,
    val companyId: String,
    val productId: String,
    val batchNo: String,
    val mfgDate: Long? = null,
    val expiryDate: Long? = null,
    val rackBin: String? = null,
    val receivedQuantity: Int,
    val remainingQuantity: Int,
    val committedQuantity: Int = 0,
    val damagedQuantity: Int = 0,
    val purchasePricePaise: Long? = null,
    val supplierName: String? = null,
    val status: String = "ACTIVE",
    val createdAt: Long = System.currentTimeMillis()
)
