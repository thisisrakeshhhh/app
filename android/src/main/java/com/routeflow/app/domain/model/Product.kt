package com.routeflow.app.domain.model

data class Product(
    val id: String,
    val name: String,
    val category: String,
    val pricePaise: Long,
    val stockQuantity: Int,
    val unit: String,
    val imageUrl: String? = null,
    val reservedQuantity: Int = 0,
    val barcode: String? = null,
    val sku: String? = null,
    val hindiName: String? = null,
    val isActive: Boolean = true,
    val minStockThreshold: Int = 10
) {
    val availableQuantity: Int
        get() = maxOf(0, stockQuantity - reservedQuantity)

    val isLowStock: Boolean
        get() = availableQuantity in 1..minStockThreshold
}
