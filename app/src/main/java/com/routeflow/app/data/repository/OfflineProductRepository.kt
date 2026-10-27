package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.StockMovementDao
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.StockMovementEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateProductRequest
import com.routeflow.app.core.network.dto.StockAdjustmentRequest
import com.routeflow.app.core.network.dto.UpdateProductRequest
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID
import javax.inject.Inject

class OfflineProductRepository @Inject constructor(
    private val productDao: ProductDao,
    private val api: RouteFlowApi,
    private val stockMovementDao: StockMovementDao,
    private val database: RouteFlowDatabase,
    private val tokenStorage: TokenStorage
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
        saveLocalProduct(request)
        try {
            api.createProduct(request)
        } catch (_: Exception) {
            // Keep local persistence if server is offline
        }
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    private suspend fun saveLocalProduct(request: CreateProductRequest) {
        val id = request.id ?: "PROD-${System.currentTimeMillis()}"
        val entity = ProductEntity(
            id = id,
            name = request.name,
            category = request.category,
            pricePaise = request.pricePaise,
            stockQuantity = 0,
            reservedQuantity = 0,
            unit = request.unit,
            sku = request.sku,
            isActive = true,
            minStockThreshold = 10
        )
        productDao.insertProducts(listOf(entity))
        if (request.stockQuantity > 0) {
            recordStockMovement(
                productId = id,
                quantityChange = request.stockQuantity,
                movementType = "OPENING_STOCK",
                reason = "Opening stock at product creation"
            )
        }
    }

    override suspend fun updateProduct(id: String, request: UpdateProductRequest): Result<Unit> = try {
        saveLocalProductUpdate(id, request)
        try {
            api.updateProduct(id, request)
        } catch (_: Exception) {
            // Keep local persistence if server is offline
        }
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    private suspend fun saveLocalProductUpdate(id: String, request: UpdateProductRequest) {
        val existing = productDao.getProductById(id)
        if (existing != null) {
            val updated = existing.copy(
                name = request.name ?: existing.name,
                category = request.category ?: existing.category,
                pricePaise = request.pricePaise ?: existing.pricePaise,
                unit = request.unit ?: existing.unit,
                isActive = request.isActive ?: existing.isActive
            )
            productDao.insertProducts(listOf(updated))
        }
    }

    override suspend fun adjustStock(request: StockAdjustmentRequest): Result<Int> = try {
        val localResult = recordStockAdjustment(
            productId = request.productId,
            changeQuantity = request.changeQuantity,
            reason = request.reason,
            notes = request.notes
        )
        try {
            api.adjustInventory(request)
        } catch (_: Exception) {
            // Keep local update
        }
        localResult
    } catch (e: Exception) {
        recordStockAdjustment(
            productId = request.productId,
            changeQuantity = request.changeQuantity,
            reason = request.reason,
            notes = request.notes
        )
    }

    override suspend fun syncProductsFromServer(): Result<Unit> = try {
        val productsDto = api.getProducts()
        if (productsDto.isNotEmpty()) {
            val entities = productsDto.map { dto ->
                ProductEntity(
                    id = dto.id,
                    name = dto.name,
                    category = dto.category,
                    pricePaise = dto.pricePaise,
                    stockQuantity = dto.stockQuantity,
                    reservedQuantity = dto.reservedQuantity,
                    unit = dto.unit,
                    imageUrl = dto.imageUrl,
                    barcode = dto.barcode,
                    sku = dto.sku,
                    hindiName = dto.hindiName,
                    isActive = true,
                    minStockThreshold = 10
                )
            }
            productDao.insertProducts(entities)
        }
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun createBatch(request: com.routeflow.app.core.network.dto.CreateBatchRequest): Result<com.routeflow.app.core.network.dto.BatchDto> = try {
        val batch = api.createBatch(request)
        syncProductsFromServer()
        Result.success(batch)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getBatchesForProduct(productId: String): Result<com.routeflow.app.core.network.dto.BatchListResponse> = try {
        Result.success(api.getBatchesForProduct(productId))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getExpiryAlerts(): Result<com.routeflow.app.core.network.dto.ExpiryAlertsResponse> = try {
        Result.success(api.getExpiryAlerts())
    } catch (e: Exception) {
        Result.failure(e)
    }

    // Phase 1 One-Warehouse Inventory Core Actions
    override suspend fun recordOpeningStock(productId: String, openingQuantity: Int, userId: String?): Result<Int> {
        val product = productDao.getProductById(productId)
            ?: return Result.failure(Exception("Product not found: $productId"))
        val delta = openingQuantity - product.stockQuantity
        return recordStockMovement(
            productId = productId,
            quantityChange = delta,
            movementType = "OPENING_STOCK",
            reason = "Opening stock setup",
            userId = userId
        )
    }

    override suspend fun recordStockReceipt(productId: String, receivedQuantity: Int, userId: String?, notes: String?): Result<Int> {
        if (receivedQuantity <= 0) return Result.failure(Exception("Received quantity must be positive"))
        return recordStockMovement(
            productId = productId,
            quantityChange = receivedQuantity,
            movementType = "STOCK_RECEIPT",
            reason = "Stock received into warehouse",
            notes = notes,
            userId = userId
        )
    }

    override suspend fun recordStockAdjustment(productId: String, changeQuantity: Int, reason: String, userId: String?, notes: String?): Result<Int> {
        if (changeQuantity == 0) return Result.failure(Exception("Adjustment change quantity cannot be zero"))
        val movementType = if (reason.contains("DAMAGE", ignoreCase = true)) "DAMAGE" else "ADJUSTMENT"
        return recordStockMovement(
            productId = productId,
            quantityChange = changeQuantity,
            movementType = movementType,
            reason = reason,
            notes = notes,
            userId = userId
        )
    }

    override suspend fun deactivateProduct(productId: String): Result<Unit> = try {
        productDao.updateProductActiveStatus(productId, false)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun activateProduct(productId: String): Result<Unit> = try {
        productDao.updateProductActiveStatus(productId, true)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override fun getMovementsForProduct(productId: String): Flow<List<StockMovementEntity>> =
        stockMovementDao.getMovementsForProduct(productId)

    private suspend fun recordStockMovement(
        productId: String,
        quantityChange: Int,
        movementType: String,
        reason: String,
        notes: String? = null,
        userId: String? = null
    ): Result<Int> = try {
        database.withTransaction {
            val product = productDao.getProductById(productId)
                ?: throw Exception("Product not found: $productId")

            val stockBefore = product.stockQuantity
            val stockAfter = stockBefore + quantityChange
            if (stockAfter < 0) {
                throw Exception("Stock cannot be negative: resulting stock would be $stockAfter")
            }

            // Enforce Phase 1 Invariant: available = on_hand - reserved >= 0
            val available = stockAfter - product.reservedQuantity
            if (available < 0) {
                throw Exception("Available stock cannot be negative. Stock after: $stockAfter, Reserved: ${product.reservedQuantity}")
            }

            val rowsUpdated = productDao.updateStockSafely(productId, stockAfter)
            if (rowsUpdated == 0) {
                throw Exception("Failed to update stock: invariant violated or product modified concurrently")
            }

            val movement = StockMovementEntity(
                id = "MOV-${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(6)}",
                companyId = tokenStorage.getCompanyId() ?: "",
                productId = productId,
                batchId = null,
                movementType = movementType,
                quantity = quantityChange,
                stockBefore = stockBefore,
                stockAfter = stockAfter,
                reason = reason,
                notes = notes,
                createdBy = userId ?: tokenStorage.getUserId() ?: "system",
                createdAt = System.currentTimeMillis(),
                syncStatus = "PENDING"
            )
            stockMovementDao.insertMovement(movement)
            Result.success(stockAfter)
        }
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
    imageUrl = imageUrl,
    reservedQuantity = reservedQuantity,
    barcode = barcode,
    sku = sku,
    hindiName = hindiName,
    isActive = isActive,
    minStockThreshold = minStockThreshold
)

private fun Product.asEntity() = ProductEntity(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    reservedQuantity = reservedQuantity,
    unit = unit,
    imageUrl = imageUrl,
    barcode = barcode,
    sku = sku,
    hindiName = hindiName,
    isActive = isActive,
    minStockThreshold = minStockThreshold
)
