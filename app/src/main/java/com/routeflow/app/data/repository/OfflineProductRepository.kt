package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateProductRequest
import com.routeflow.app.core.network.dto.StockAdjustmentRequest
import com.routeflow.app.core.network.dto.UpdateProductRequest
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class OfflineProductRepository @Inject constructor(
    private val productDao: ProductDao,
    private val api: RouteFlowApi
) : ProductRepository {
    override fun getAllProducts(): Flow<List<Product>> =
        productDao.getAllProducts().map { entities ->
            entities.map { it.asDomainModel() }
        }

    override fun getProductsByCategory(category: String): Flow<List<Product>> =
        productDao.getProductsByCategory(category).map { entities ->
            entities.map { it.asDomainModel() }
        }

    override suspend fun saveProducts(products: List<Product>) {
        productDao.insertProducts(products.map { it.asEntity() })
    }

    override suspend fun createProduct(request: CreateProductRequest): Result<Unit> = try {
        val resp = api.createProduct(request)
        if (resp.success) {
            syncProductsFromServer()
            Result.success(Unit)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to create product"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateProduct(id: String, request: UpdateProductRequest): Result<Unit> = try {
        val resp = api.updateProduct(id, request)
        if (resp.success) {
            syncProductsFromServer()
            Result.success(Unit)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to update product"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun adjustStock(request: StockAdjustmentRequest): Result<Int> = try {
        val resp = api.adjustInventory(request)
        if (resp.success) {
            syncProductsFromServer()
            Result.success(resp.newStockQuantity ?: 0)
        } else {
            Result.failure(Exception("Stock adjustment failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun syncProductsFromServer(): Result<Unit> = try {
        val productsDto = api.getProducts()
        val entities = productsDto.map { dto ->
            ProductEntity(
                id = dto.id,
                name = dto.name,
                category = dto.category,
                pricePaise = dto.pricePaise,
                stockQuantity = dto.stockQuantity,
                unit = dto.unit,
                imageUrl = dto.imageUrl
            )
        }
        productDao.insertProducts(entities)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }
}

private fun ProductEntity.asDomainModel() = Product(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    unit = unit,
    imageUrl = imageUrl
)

private fun Product.asEntity() = ProductEntity(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    unit = unit,
    imageUrl = imageUrl
)
