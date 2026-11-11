package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "retailer_price_overrides",
    indices = [Index(value = ["retailerId", "productId"], unique = true)]
)
data class RetailerPriceOverrideEntity(
    @PrimaryKey val id: String,
    val retailerId: String,
    val productId: String,
    val pricePaise: Long,
    val isActive: Boolean = true
)
