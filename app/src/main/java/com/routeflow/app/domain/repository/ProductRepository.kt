package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CreateProductRequest
import com.routeflow.app.core.network.dto.StockAdjustmentRequest
import com.routeflow.app.core.network.dto.UpdateProductRequest
import com.routeflow.app.domain.model.Product
import kotlinx.coroutines.flow.Flow

interface ProductRepository {
    fun getAllProducts(): Flow<List<Product>>
    fun getProductsByCategory(category: String): Flow<List<Product>>
    suspend fun saveProducts(products: List<Product>)
    suspend fun createProduct(request: CreateProductRequest): Result<Unit>
    suspend fun updateProduct(id: String, request: UpdateProductRequest): Result<Unit>
    suspend fun adjustStock(request: StockAdjustmentRequest): Result<Int>
    suspend fun syncProductsFromServer(): Result<Unit>
    suspend fun createBatch(request: com.routeflow.app.core.network.dto.CreateBatchRequest): Result<com.routeflow.app.core.network.dto.BatchDto>
    suspend fun getBatchesForProduct(productId: String): Result<com.routeflow.app.core.network.dto.BatchListResponse>
    suspend fun getExpiryAlerts(): Result<com.routeflow.app.core.network.dto.ExpiryAlertsResponse>
}
