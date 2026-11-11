package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CreateDispatchBatchRequest
import com.routeflow.app.core.network.dto.CreateWarehouseBatchRequest
import com.routeflow.app.core.network.dto.DispatchBatchDto
import com.routeflow.app.core.network.dto.InspectWarehouseReturnRequest
import com.routeflow.app.core.network.dto.InspectWarehouseReturnResponse
import com.routeflow.app.core.network.dto.PickingOrderDto
import com.routeflow.app.core.network.dto.ProductDto
import com.routeflow.app.core.network.dto.StockMovementDto
import com.routeflow.app.core.network.dto.WarehouseBatchDto
import com.routeflow.app.core.network.dto.WarehouseReturnsResponse
import com.routeflow.app.core.network.dto.WarehouseStockAdjustResponse
import com.routeflow.app.core.network.dto.WarehouseStockAuditResponse
import com.routeflow.app.core.network.dto.WarehouseStockResponse

interface WarehouseRepository {
    suspend fun getStock(search: String? = null, filter: String? = null): Result<WarehouseStockResponse>
    suspend fun findProductByBarcode(barcode: String): Result<ProductDto>
    suspend fun adjustStock(productId: String, changeQuantity: Int, reason: String, notes: String? = null, batchId: String? = null): Result<WarehouseStockAdjustResponse>
    suspend fun auditStock(productId: String, physicalCount: Int, notes: String? = null): Result<WarehouseStockAuditResponse>
    suspend fun getMovements(productId: String? = null): Result<List<StockMovementDto>>
    suspend fun getBatches(productId: String? = null): Result<List<WarehouseBatchDto>>
    suspend fun createBatch(request: CreateWarehouseBatchRequest): Result<WarehouseBatchDto>
    suspend fun getNearExpiryBatches(): Result<List<WarehouseBatchDto>>
    suspend fun getPickingQueue(): Result<List<PickingOrderDto>>
    suspend fun startPicking(orderId: String): Result<Unit>
    suspend fun scanPickItem(orderId: String, barcode: String? = null, productId: String? = null): Result<Unit>
    suspend fun markOrderPacked(orderId: String, cartonsCount: Int, notes: String? = null, photoUrl: String? = null, weightGrams: Int? = null): Result<Unit>
    suspend fun createDispatchBatch(orderIds: List<String>, driverId: String? = null, routeId: String? = null, notes: String? = null): Result<DispatchBatchDto>
    suspend fun getDispatchBatches(): Result<List<DispatchBatchDto>>
    suspend fun assignDispatchDriver(batchId: String, driverId: String): Result<Unit>
    suspend fun handoverDispatchBatch(batchId: String): Result<Unit>
    suspend fun getReturns(): Result<WarehouseReturnsResponse>
    suspend fun inspectReturn(request: InspectWarehouseReturnRequest): Result<InspectWarehouseReturnResponse>
    suspend fun updateProductImage(productId: String, imageUrl: String?, imageKey: String? = null): Result<Unit>
}
