package com.routeflow.app.domain.repository

import com.routeflow.app.domain.model.Product
import kotlinx.coroutines.flow.Flow

interface ProductRepository {
    fun getAllProducts(): Flow<List<Product>>
    fun getProductsByCategory(category: String): Flow<List<Product>>
    suspend fun saveProducts(products: List<Product>)
}
