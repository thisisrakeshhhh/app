package com.routeflow.app.core.network.dto

import kotlinx.serialization.Serializable

@Serializable
data class WarehouseStockItemDto(
    val id: String,
    val name: String,
    val hindiName: String? = null,
    val category: String,
    val pricePaise: Long,
    val mrpPaise: Long? = null,
    val stockQuantity: Int,
    val reservedQuantity: Int = 0,
    val availableQuantity: Int = 0,
    val unit: String,
    val sku: String? = null,
    val barcode: String? = null,
    val imageUrl: String? = null,
    val productImageKey: String? = null,
    val tracksExpiry: Int? = null,
    val batchCount: Int = 0,
    val damagedQuantity: Int = 0,
    val nearExpiryBatchCount: Int = 0,
    val isLowStock: Boolean = false,
    val isOutOfStock: Boolean = false,
    val isNearExpiry: Boolean = false
)

@Serializable
data class WarehouseStockResponse(
    val products: List<WarehouseStockItemDto> = emptyList(),
    val total: Int = 0
)

@Serializable
data class WarehouseStockAdjustRequest(
    val productId: String,
    val changeQuantity: Int,
    val reason: String,
    val notes: String? = null,
    val batchId: String? = null,
    val idempotencyKey: String? = null
)

@Serializable
data class WarehouseStockAdjustResponse(
    val success: Boolean,
    val movementId: String? = null,
    val productId: String? = null,
    val productName: String? = null,
    val stockBefore: Int = 0,
    val newStockQuantity: Int = 0
)

@Serializable
data class WarehouseStockAuditRequest(
    val productId: String,
    val physicalCount: Int,
    val notes: String? = null
)

@Serializable
data class WarehouseStockAuditResponse(
    val success: Boolean,
    val movementId: String? = null,
    val productId: String? = null,
    val previousStock: Int = 0,
    val newStockQuantity: Int = 0,
    val difference: Int = 0
)

@Serializable
data class StockMovementDto(
    val id: String,
    val productId: String,
    val productName: String? = null,
    val batchId: String? = null,
    val movementType: String,
    val quantity: Int,
    val stockBefore: Int,
    val stockAfter: Int,
    val reason: String,
    val notes: String? = null,
    val createdByName: String? = null,
    val createdAt: Long
)

@Serializable
data class WarehouseBatchDto(
    val id: String,
    val productId: String,
    val productName: String? = null,
    val batchNo: String,
    val mfgDate: Long? = null,
    val expiryDate: Long? = null,
    val rackBin: String? = null,
    val receivedQuantity: Int = 0,
    val remainingQuantity: Int = 0,
    val damagedQuantity: Int = 0,
    val purchasePricePaise: Long? = null,
    val supplierName: String? = null,
    val status: String = "ACTIVE",
    val createdAt: Long = 0
)

@Serializable
data class CreateWarehouseBatchRequest(
    val productId: String,
    val batchNo: String,
    val receivedQuantity: Int,
    val expiryDate: Long? = null,
    val mfgDate: Long? = null,
    val rackBin: String? = null,
    val purchasePricePaise: Long? = null,
    val supplierName: String? = null
)

@Serializable
data class SuggestedBatchDto(
    val id: String,
    val batchNo: String,
    val rackBin: String? = null,
    val expiryDate: Long? = null,
    val remainingQuantity: Int = 0
)

@Serializable
data class PickingOrderItemDto(
    val id: String,
    val orderId: String,
    val productId: String,
    val productName: String? = null,
    val hindiName: String? = null,
    val sku: String? = null,
    val barcode: String? = null,
    val imageUrl: String? = null,
    val availableStock: Int = 0,
    val quantity: Int,
    val freeQuantity: Int = 0,
    val isPicked: Boolean = false,
    val suggestedBatch: SuggestedBatchDto? = null
)

@Serializable
data class PickingOrderDto(
    val id: String,
    val retailerId: String,
    val retailerName: String,
    val retailerAddress: String? = null,
    val status: String,
    val totalAmountPaise: Long,
    val createdAt: Long,
    val cartonsCount: Int = 1,
    val packingNotes: String? = null,
    val items: List<PickingOrderItemDto> = emptyList(),
    val allPicked: Boolean = false
)

@Serializable
data class PickingQueueResponse(
    val orders: List<PickingOrderDto> = emptyList()
)

@Serializable
data class ScanPickRequest(
    val barcode: String? = null,
    val productId: String? = null,
    val batchId: String? = null
)

@Serializable
data class MarkPackedRequest(
    val cartonsCount: Int = 1,
    val packagePhotoUrl: String? = null,
    val packageWeightGrams: Int? = null,
    val packingNotes: String? = null
)

@Serializable
data class CreateDispatchBatchRequest(
    val orderIds: List<String>,
    val deliveryExecutiveId: String? = null,
    val routeId: String? = null,
    val notes: String? = null
)

@Serializable
data class DispatchBatchDto(
    val id: String,
    val batchCode: String,
    val deliveryExecutiveId: String? = null,
    val deliveryExecutiveName: String? = null,
    val routeId: String? = null,
    val status: String = "CREATED",
    val totalOrders: Int = 0,
    val totalCartons: Int = 0,
    val notes: String? = null,
    val handedOverAt: Long? = null,
    val createdAt: Long = 0
)

@Serializable
data class AssignDispatchDriverRequest(
    val deliveryExecutiveId: String
)

@Serializable
data class WarehouseReturnItemDto(
    val id: String,
    val orderId: String? = null,
    val productId: String,
    val productName: String? = null,
    val quantity: Int,
    val driverId: String? = null,
    val driverName: String? = null,
    val status: String? = null,
    val reason: String? = null,
    val condition: String? = null,
    val actionTaken: String? = null,
    val photoUrl: String? = null,
    val notes: String? = null,
    val createdAt: Long = 0
)

@Serializable
data class WarehouseReturnsResponse(
    val pendingUndelivered: List<WarehouseReturnItemDto> = emptyList(),
    val inspectionsHistory: List<WarehouseReturnItemDto> = emptyList()
)

@Serializable
data class InspectWarehouseReturnRequest(
    val returnId: String? = null,
    val orderId: String? = null,
    val retailerId: String? = null,
    val productId: String,
    val quantity: Int,
    val condition: String, // SALEABLE, DAMAGED, EXPIRED, MISSING
    val photoUrl: String? = null,
    val notes: String? = null
)

@Serializable
data class InspectWarehouseReturnResponse(
    val success: Boolean,
    val inspectionId: String? = null,
    val actionTaken: String? = null,
    val condition: String? = null,
    val restocked: Boolean = false,
    val newStockQuantity: Int = 0
)

@Serializable
data class UploadProductImageRequest(
    val imageUrl: String? = null,
    val imageKey: String? = null
)
