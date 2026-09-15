package com.routeflow.app.domain.model

data class Product(
    val id: String,
    val name: String,
    val category: String,
    val price: Double,
    val stockQuantity: Int,
    val unit: String,
    val imageUrl: String? = null
)
