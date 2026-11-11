package com.routeflow.app.data.repository

import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.DispatchBatchDao
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.ProductBatchDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.StockMovementDao
import com.routeflow.app.core.database.dao.WarehouseReturnDao
import com.routeflow.app.core.database.entity.ProductBatchEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.StockMovementEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.AssignDispatchDriverRequest
import com.routeflow.app.core.network.dto.CreateDispatchBatchRequest
import com.routeflow.app.core.network.dto.CreateWarehouseBatchRequest
import com.routeflow.app.core.network.dto.DispatchBatchDto
import com.routeflow.app.core.network.dto.InspectWarehouseReturnRequest
import com.routeflow.app.core.network.dto.InspectWarehouseReturnResponse
import com.routeflow.app.core.network.dto.MarkPackedRequest
import com.routeflow.app.core.network.dto.PickingOrderDto
import com.routeflow.app.core.network.dto.ProductDto
import com.routeflow.app.core.network.dto.ScanPickRequest
import com.routeflow.app.core.network.dto.StockMovementDto
import com.routeflow.app.core.network.dto.UploadProductImageRequest
import com.routeflow.app.core.network.dto.WarehouseBatchDto
import com.routeflow.app.core.network.dto.WarehouseReturnsResponse
import com.routeflow.app.core.network.dto.WarehouseStockAdjustRequest
import com.routeflow.app.core.network.dto.WarehouseStockAdjustResponse
import com.routeflow.app.core.network.dto.WarehouseStockAuditRequest
import com.routeflow.app.core.network.dto.WarehouseStockAuditResponse
import com.routeflow.app.core.network.dto.WarehouseStockItemDto
import com.routeflow.app.core.network.dto.WarehouseStockResponse
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.repository.WarehouseRepository
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfflineWarehouseRepository @Inject constructor(
    private val api: RouteFlowApi,
    private val productDao: ProductDao,
    private val productBatchDao: ProductBatchDao,
    private val stockMovementDao: StockMovementDao,
    private val dispatchBatchDao: DispatchBatchDao,
    private val warehouseReturnDao: WarehouseReturnDao,
    private val orderDao: OrderDao,
    private val tokenStorage: TokenStorage,
    private val database: RouteFlowDatabase
) : WarehouseRepository {

    override suspend fun getStock(search: String?, filter: String?): Result<WarehouseStockResponse> = try {
        val remote = api.getWarehouseStock(search, filter)
        // Cache products locally
        val entities = remote.products.map { p ->
            ProductEntity(
                id = p.id,
                name = p.name,
                category = p.category,
                pricePaise = p.pricePaise,
                stockQuantity = p.stockQuantity,
                reservedQuantity = p.reservedQuantity,
                unit = p.unit,
                imageUrl = p.imageUrl,
                barcode = p.barcode,
                sku = p.sku,
                hindiName = p.hindiName
            )
        }
        productDao.insertProducts(entities)
        Result.success(remote)
    } catch (e: Exception) {
        // Fallback to local Room products
        try {
            val localProducts = productDao.getAllProducts().first()
            val mapped = localProducts.map { p ->
                val available = Math.max(0, p.stockQuantity - p.reservedQuantity)
                WarehouseStockItemDto(
                    id = p.id,
                    name = p.name,
                    hindiName = p.hindiName,
                    category = p.category,
                    pricePaise = p.pricePaise,
                    stockQuantity = p.stockQuantity,
                    reservedQuantity = p.reservedQuantity,
                    availableQuantity = available,
                    unit = p.unit,
                    sku = p.sku,
                    barcode = p.barcode,
                    imageUrl = p.imageUrl,
                    isLowStock = available > 0 && available < 10,
                    isOutOfStock = available <= 0
                )
            }
            Result.success(WarehouseStockResponse(products = mapped, total = mapped.size))
        } catch (localEx: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun findProductByBarcode(barcode: String): Result<ProductDto> = try {
        val remote = api.getProductByBarcode(barcode)
        Result.success(remote)
    } catch (e: Exception) {
        // Fallback to Room DB
        val local = productDao.getProductByBarcode(barcode)
        if (local != null) {
            Result.success(
                ProductDto(
                    id = local.id,
                    name = local.name,
                    category = local.category,
                    pricePaise = local.pricePaise,
                    stockQuantity = local.stockQuantity,
                    reservedQuantity = local.reservedQuantity,
                    unit = local.unit,
                    imageUrl = local.imageUrl,
                    barcode = local.barcode,
                    sku = local.sku,
                    hindiName = local.hindiName
                )
            )
        } else {
            Result.failure(e)
        }
    }

    override suspend fun adjustStock(
        productId: String,
        changeQuantity: Int,
        reason: String,
        notes: String?,
        batchId: String?
    ): Result<WarehouseStockAdjustResponse> = try {
        val resp = api.adjustWarehouseStock(
            WarehouseStockAdjustRequest(
                productId = productId,
                changeQuantity = changeQuantity,
                reason = reason,
                notes = notes,
                batchId = batchId
            )
        )
        // Update local database on success
        val local = productDao.getProductById(productId)
        if (local != null) {
            productDao.updateStock(productId, resp.newStockQuantity)
        }
        Result.success(resp)
    } catch (e: Exception) {
        // Offline optimistic update
        val local = productDao.getProductById(productId)
        if (local != null) {
            val newQty = local.stockQuantity + changeQuantity
            if (newQty >= 0) {
                productDao.updateStock(productId, newQty)
                stockMovementDao.insertMovement(
                    StockMovementEntity(
                        id = "LOC_MOV_${System.currentTimeMillis()}",
                        companyId = tokenStorage.getCompanyId() ?: "",
                        productId = productId,
                        batchId = batchId,
                        movementType = reason,
                        quantity = changeQuantity,
                        stockBefore = local.stockQuantity,
                        stockAfter = newQty,
                        reason = reason,
                        notes = notes,
                        createdBy = tokenStorage.getUserId() ?: "offline",
                        syncStatus = "PENDING"
                    )
                )
                Result.success(
                    WarehouseStockAdjustResponse(
                        success = true,
                        productId = productId,
                        stockBefore = local.stockQuantity,
                        newStockQuantity = newQty
                    )
                )
            } else {
                Result.failure(Exception("Stock cannot be negative"))
            }
        } else {
            Result.failure(e)
        }
    }

    override suspend fun auditStock(
        productId: String,
        physicalCount: Int,
        notes: String?
    ): Result<WarehouseStockAuditResponse> = try {
        val resp = api.auditWarehouseStock(
            WarehouseStockAuditRequest(productId = productId, physicalCount = physicalCount, notes = notes)
        )
        productDao.updateStock(productId, resp.newStockQuantity)
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getMovements(productId: String?): Result<List<StockMovementDto>> = try {
        val resp = api.getWarehouseMovements(productId = productId)
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getBatches(productId: String?): Result<List<WarehouseBatchDto>> = try {
        val resp = api.getWarehouseBatches(productId = productId)
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun createBatch(request: CreateWarehouseBatchRequest): Result<WarehouseBatchDto> = try {
        val resp = api.createWarehouseBatch(request)
        // Refresh product stock
        val local = productDao.getProductById(request.productId)
        if (local != null) {
            productDao.updateStock(request.productId, local.stockQuantity + request.receivedQuantity)
        }
        productBatchDao.insertBatch(
            ProductBatchEntity(
                id = resp.id,
                companyId = tokenStorage.getCompanyId() ?: "",
                productId = resp.productId,
                batchNo = resp.batchNo,
                mfgDate = resp.mfgDate,
                expiryDate = resp.expiryDate,
                rackBin = resp.rackBin,
                receivedQuantity = resp.receivedQuantity,
                remainingQuantity = resp.remainingQuantity,
                damagedQuantity = resp.damagedQuantity,
                purchasePricePaise = resp.purchasePricePaise,
                supplierName = resp.supplierName,
                status = resp.status
            )
        )
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getNearExpiryBatches(): Result<List<WarehouseBatchDto>> = try {
        val resp = api.getWarehouseNearExpiryBatches()
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getPickingQueue(): Result<List<PickingOrderDto>> = try {
        val resp = api.getWarehousePickingQueue()
        Result.success(resp.orders)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun startPicking(orderId: String): Result<Unit> = try {
        val resp = api.startWarehousePicking(orderId)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun scanPickItem(orderId: String, barcode: String?, productId: String?): Result<Unit> = try {
        val resp = api.scanPickItem(orderId, ScanPickRequest(barcode = barcode, productId = productId))
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun markOrderPacked(
        orderId: String,
        cartonsCount: Int,
        notes: String?,
        photoUrl: String?,
        weightGrams: Int?
    ): Result<Unit> = try {
        val resp = api.markOrderPackedWarehouse(
            orderId,
            MarkPackedRequest(
                cartonsCount = cartonsCount,
                packingNotes = notes,
                packagePhotoUrl = photoUrl,
                packageWeightGrams = weightGrams
            )
        )
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun createDispatchBatch(
        orderIds: List<String>,
        driverId: String?,
        routeId: String?,
        notes: String?
    ): Result<DispatchBatchDto> = try {
        val resp = api.createDispatchBatch(
            CreateDispatchBatchRequest(
                orderIds = orderIds,
                deliveryExecutiveId = driverId,
                routeId = routeId,
                notes = notes
            )
        )
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getDispatchBatches(): Result<List<DispatchBatchDto>> = try {
        val resp = api.getDispatchBatches()
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun assignDispatchDriver(batchId: String, driverId: String): Result<Unit> = try {
        val resp = api.assignDispatchDriver(batchId, AssignDispatchDriverRequest(driverId))
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun handoverDispatchBatch(batchId: String): Result<Unit> = try {
        val resp = api.handoverDispatchBatch(batchId)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getReturns(): Result<WarehouseReturnsResponse> = try {
        val resp = api.getWarehouseReturns()
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun inspectReturn(request: InspectWarehouseReturnRequest): Result<InspectWarehouseReturnResponse> = try {
        val resp = api.inspectWarehouseReturn(request)
        if (resp.success && resp.restocked) {
            val local = productDao.getProductById(request.productId)
            if (local != null) {
                productDao.updateStock(request.productId, local.stockQuantity + request.quantity)
            }
        }
        Result.success(resp)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateProductImage(productId: String, imageUrl: String?, imageKey: String?): Result<Unit> = try {
        val resp = api.updateProductImage(productId, UploadProductImageRequest(imageUrl, imageKey))
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed"))
    } catch (e: Exception) {
        Result.failure(e)
    }
}
