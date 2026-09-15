package com.routeflow.app.domain.model

data class Product(
    val id: String,
    val name: String,
    val category: String,
    val pricePaise: Long,
    val stockQuantity: Int,
    val unit: String,
    val imageUrl: String? = null
)
