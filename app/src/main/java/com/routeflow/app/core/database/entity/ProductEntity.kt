package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "products")
data class ProductEntity(
    @PrimaryKey val id: String,
    val name: String,
    val category: String,
    val pricePaise: Long,
    val stockQuantity: Int,
    val unit: String,
    val imageUrl: String? = null
)
