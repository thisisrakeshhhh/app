package com.routeflow.app.core.network.dto

import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RetailerDto(
    val id: String,
    val name: String,
    val beatId: String,
    val address: String,
    val contactNumber: String,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val creditLimitPaise: Long,
    val outstandingAmountPaise: Long
)

fun RetailerDto.toEntity(): RetailerEntity = RetailerEntity(
    id = id,
    name = name,
    beatId = beatId,
    address = address,
    contactNumber = contactNumber,
    latitude = latitude ?: 0.0,
    longitude = longitude ?: 0.0,
    creditLimitPaise = creditLimitPaise,
    outstandingAmountPaise = outstandingAmountPaise
)

fun RetailerEntity.toDto(): RetailerDto = RetailerDto(
    id = id,
    name = name,
    beatId = beatId,
    address = address,
    contactNumber = contactNumber,
    latitude = latitude,
    longitude = longitude,
    creditLimitPaise = creditLimitPaise,
    outstandingAmountPaise = outstandingAmountPaise
)

@Serializable
data class ProductDto(
    val id: String,
    val name: String,
    val category: String,
    val pricePaise: Long,
    val stockQuantity: Int,
    val reservedQuantity: Int = 0,
    val unit: String,
    val imageUrl: String? = null
)

fun ProductDto.toEntity(): ProductEntity = ProductEntity(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    reservedQuantity = reservedQuantity,
    unit = unit,
    imageUrl = imageUrl
)

fun ProductEntity.toDto(): ProductDto = ProductDto(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    reservedQuantity = reservedQuantity,
    unit = unit,
    imageUrl = imageUrl
)

@Serializable
data class OrderDto(
    val id: String,
    val retailerId: String,
    val employeeId: String,
    val status: String,
    val totalAmountPaise: Long,
    val createdAt: Long,
    val updatedAt: Long,
    val deliveryEmployeeId: String? = null,
    val rejectionReason: String? = null,
    val paymentMethod: String? = null
)

fun OrderDto.toEntity(): OrderEntity = OrderEntity(
    id = id,
    retailerId = retailerId,
    employeeId = employeeId,
    status = status,
    totalAmountPaise = totalAmountPaise,
    createdAt = createdAt,
    updatedAt = updatedAt,
    rejectionReason = rejectionReason
)

fun OrderEntity.toDto(
    deliveryEmployeeId: String? = null,
    paymentMethod: String? = null
): OrderDto = OrderDto(
    id = id,
    retailerId = retailerId,
    employeeId = employeeId,
    status = status,
    totalAmountPaise = totalAmountPaise,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deliveryEmployeeId = deliveryEmployeeId,
    rejectionReason = rejectionReason,
    paymentMethod = paymentMethod
)

@Serializable
data class OrderItemDto(
    val id: String,
    val orderId: String,
    val productId: String,
    val quantity: Int,
    val freeQuantity: Int = 0,
    val pricePaiseAtTime: Long,
    val isPicked: Boolean = false
)

fun OrderItemDto.toEntity(): OrderItemEntity = OrderItemEntity(
    id = id,
    orderId = orderId,
    productId = productId,
    quantity = quantity,
    freeQuantity = freeQuantity,
    pricePaiseAtTime = pricePaiseAtTime,
    isPicked = isPicked
)

fun OrderItemEntity.toDto(): OrderItemDto = OrderItemDto(
    id = id,
    orderId = orderId,
    productId = productId,
    quantity = quantity,
    freeQuantity = freeQuantity,
    pricePaiseAtTime = pricePaiseAtTime,
    isPicked = isPicked
)

@Serializable
data class LoginRequest(
    val username: String,
    val password: String
)

@Serializable
data class RefreshRequest(
    @SerialName("refresh_token")
    val refreshToken: String
)

@Serializable
data class UserDto(
    val id: String,
    val name: String,
    val role: String,
    @SerialName("company_id")
    val companyId: String
)

@Serializable
data class AuthResponse(
    @SerialName("access_token")
    val accessToken: String,
    @SerialName("refresh_token")
    val refreshToken: String,
    val user: UserDto? = null
)

@Serializable
data class OrderSubmitRequest(
    val order: OrderDto,
    val items: List<OrderItemDto>,
    val idempotencyKey: String
)

@Serializable
data class OrderSubmitResponse(
    val success: Boolean,
    val orderId: String,
    val idempotent: Boolean = false,
    val message: String? = null
)

@Serializable
data class OrderDetailsResponse(
    val order: OrderDto,
    val items: List<OrderItemDto>
)

@Serializable
data class StatusResponse(
    val success: Boolean,
    val message: String? = null,
    val idempotent: Boolean = false
)

@Serializable
data class ItemPickRequest(
    val productId: String,
    val isPicked: Boolean
)

@Serializable
data class DispatchOrderRequest(
    val deliveryEmployeeId: String
)

@Serializable
data class DeliveryCompletionRequest(
    val paymentMethod: String = "CASH",
    val otp: String = "",
    val recipientName: String = "",
    val proofPhotoUrl: String? = null,
    val signatureUrl: String? = null
)

@Serializable
data class OtpResponse(
    val success: Boolean,
    val message: String? = null,
    val expiresAt: Long? = null,
    val debugOtp: String? = null
)

@Serializable
data class OrderRejectionRequest(
    val reason: String
)

@Serializable
data class DeliveryExecutiveDto(
    val id: String,
    val fullName: String,
    val username: String,
    val isActive: Boolean = true
)

@Serializable
data class CreateProductRequest(
    val id: String? = null,
    val name: String,
    val hindiName: String? = null,
    val category: String = "General",
    val pricePaise: Long,
    val mrpPaise: Long? = null,
    val stockQuantity: Int = 0,
    val unit: String,
    val sku: String? = null,
    val imageUrl: String? = null
)

@Serializable
data class UpdateProductRequest(
    val name: String? = null,
    val hindiName: String? = null,
    val category: String? = null,
    val pricePaise: Long? = null,
    val mrpPaise: Long? = null,
    val unit: String? = null,
    val sku: String? = null,
    val isActive: Boolean? = null,
    val imageUrl: String? = null
)

@Serializable
data class StockAdjustmentRequest(
    val productId: String,
    val changeQuantity: Int,
    val reason: String,
    val notes: String? = null,
    val idempotencyKey: String? = null
)

@Serializable
data class StockAdjustmentResponse(
    val success: Boolean,
    val adjustmentId: String? = null,
    val newStockQuantity: Int? = null,
    val idempotent: Boolean = false,
    val message: String? = null
)

@Serializable
data class CreateRetailerRequest(
    val id: String? = null,
    val name: String,
    val beatId: String,
    val address: String,
    val contactNumber: String,
    val creditLimitPaise: Long,
    val paymentTermsDays: Int = 7,
    val latitude: Double? = null,
    val longitude: Double? = null
)

@Serializable
data class UpdateRetailerRequest(
    val name: String? = null,
    val beatId: String? = null,
    val address: String? = null,
    val contactNumber: String? = null,
    val creditLimitPaise: Long? = null,
    val paymentTermsDays: Int? = null,
    val isActive: Boolean? = null,
    val latitude: Double? = null,
    val longitude: Double? = null
)

@Serializable
data class EmployeeDto(
    val id: String,
    val username: String,
    val fullName: String,
    val role: String,
    val isActive: Boolean = true,
    val assignedBeats: List<String> = emptyList()
)

@Serializable
data class CreateEmployeeRequest(
    val id: String? = null,
    val username: String,
    val password: String,
    val fullName: String,
    val role: String,
    val beatId: String? = null
)

@Serializable
data class VisitDto(
    val id: String,
    val retailerId: String,
    val checkInTime: Long,
    val checkOutTime: Long? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val accuracy: Float? = null,
    val durationSeconds: Long = 0,
    val status: String = "COMPLETED",
    val noOrderReason: String? = null,
    val notes: String? = null,
    val idempotencyKey: String? = null
)

@Serializable
data class StockCheckDto(
    val id: String? = null,
    val retailerId: String,
    val productId: String,
    val quantity: Int
)

@Serializable
data class BeatDto(
    val id: String,
    val name: String,
    val description: String? = null,
    val workingDays: List<String> = emptyList(),
    val isActive: Boolean = true,
    val retailerCount: Int = 0,
    val assignedSalespeople: List<String> = emptyList()
)

@Serializable
data class CreateBeatRequest(
    val id: String? = null,
    val name: String,
    val description: String? = null,
    val workingDays: List<String> = emptyList()
)

@Serializable
data class CreateBeatResponse(
    val success: Boolean,
    val beat: BeatDto? = null
)

@Serializable
data class AssignBeatRequest(
    val userId: String
)

@Serializable
data class LocationPoint(
    val id: String? = null,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val timestamp: Long
)

@Serializable
data class ShiftLocationsRequest(
    val shiftId: String,
    val points: List<LocationPoint>
)

@Serializable
data class StartShiftRequest(
    val latitude: Double? = null,
    val longitude: Double? = null
)

@Serializable
data class EndShiftRequest(
    val latitude: Double? = null,
    val longitude: Double? = null
)

@Serializable
data class ShiftDto(
    val id: String,
    val status: String,
    val startTime: Long,
    val endTime: Long? = null
)

@Serializable
data class ShiftResponse(
    val success: Boolean,
    val shift: ShiftDto? = null,
    val idempotent: Boolean = false,
    val message: String? = null
)

@Serializable
data class TeamLocationDto(
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val timestamp: Long,
    val isStale: Boolean = false
)

@Serializable
data class TeamMemberStatusDto(
    val id: String,
    val fullName: String,
    val role: String,
    val shiftStatus: String,
    val shiftStartTime: Long? = null,
    val shiftEndTime: Long? = null,
    val lastLocation: TeamLocationDto? = null,
    val assignedBeats: List<String> = emptyList(),
    val completedStops: Int = 0,
    val totalStops: Int = 0,
    val lastSyncTime: Long? = null
)

@Serializable
data class DailyVisitDto(
    val id: String,
    val retailerId: String,
    val retailerName: String,
    val beatId: String,
    val employeeId: String,
    val employeeName: String,
    val checkInTime: Long,
    val checkOutTime: Long? = null,
    val durationSeconds: Long = 0,
    val status: String,
    val noOrderReason: String? = null,
    val notes: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val accuracy: Float? = null,
    val locationDiscrepancy: Boolean = false,
    val ordersCount: Int = 0,
    val stockChecksCount: Int = 0
)

@Serializable
data class CheckoutVisitRequest(
    val checkOutTime: Long = System.currentTimeMillis(),
    val durationSeconds: Long = 0,
    val noOrderReason: String? = null,
    val notes: String? = null
)

// --- Collections ---

@Serializable
data class RecordCollectionRequest(
    val retailerId: String,
    val amountPaise: Long,
    val paymentMethod: String,
    val receiptId: String? = null,
    val notes: String? = null,
    val idempotencyKey: String? = null
)

@Serializable
data class RecordCollectionResponse(
    val success: Boolean,
    val collectionId: String? = null,
    val receiptId: String? = null,
    val balanceAfterPaise: Long = 0,
    val idempotent: Boolean = false
)

@Serializable
data class CollectionDto(
    val id: String,
    val company_id: String = "",
    val retailer_id: String,
    val retailer_name: String? = null,
    val collected_by: String,
    val collected_by_name: String? = null,
    val amount_paise: Long,
    val payment_method: String,
    val receipt_id: String,
    val notes: String? = null,
    val created_at: Long
)

@Serializable
data class CollectionsListResponse(
    val collections: List<CollectionDto>
)

// --- Cash Handover ---

@Serializable
data class CashHandoverDto(
    val id: String,
    val company_id: String = "",
    val user_id: String,
    val employee_name: String? = null,
    val employee_role: String? = null,
    val amount_paise: Long,
    val status: String,
    val submitted_at: Long,
    val acknowledged_at: Long? = null,
    val acknowledged_by: String? = null,
    val received_amount_paise: Long? = null,
    val discrepancy_paise: Long? = null,
    val notes: String? = null
)

@Serializable
data class CashHandoverSummaryResponse(
    val cashHeldPaise: Long,
    val totalCollectedPaise: Long,
    val totalSettledPaise: Long,
    val pendingHandover: CashHandoverDto? = null,
    val recentHandovers: List<CashHandoverDto> = emptyList()
)

@Serializable
data class SubmitHandoverRequest(
    val amountPaise: Long,
    val notes: String? = null
)

@Serializable
data class SubmitHandoverResponse(
    val success: Boolean,
    val handoverId: String? = null,
    val status: String? = null,
    val amountPaise: Long = 0
)

@Serializable
data class OwnerHandoversResponse(
    val handovers: List<CashHandoverDto>
)

@Serializable
data class AcknowledgeHandoverRequest(
    val action: String,
    val receivedAmountPaise: Long? = null,
    val notes: String? = null
)

@Serializable
data class AcknowledgeHandoverResponse(
    val success: Boolean,
    val status: String,
    val receivedAmountPaise: Long? = null,
    val discrepancyPaise: Long? = null
)

// --- Returns Workflow ---

@Serializable
data class ReturnItemRequest(
    val productId: String,
    val requestedQuantity: Int
)

@Serializable
data class CreateReturnRequest(
    val orderId: String,
    val items: List<ReturnItemRequest>,
    val notes: String? = null
)

@Serializable
data class CreateReturnResponse(
    val success: Boolean,
    val returnId: String? = null,
    val status: String? = null
)

@Serializable
data class ReturnItemDto(
    val id: String,
    val return_id: String,
    val product_id: String,
    val product_name: String? = null,
    val product_hindi_name: String? = null,
    val sku: String? = null,
    val requested_quantity: Int,
    val saleable_quantity: Int = 0,
    val damaged_quantity: Int = 0,
    val unit_price_paise: Long
)

@Serializable
data class ReturnRequestDto(
    val id: String,
    val company_id: String = "",
    val order_id: String,
    val retailer_id: String,
    val retailer_name: String? = null,
    val created_by: String,
    val created_by_name: String? = null,
    val status: String,
    val created_at: Long,
    val inspected_at: Long? = null,
    val inspected_by: String? = null,
    val notes: String? = null,
    val items: List<ReturnItemDto> = emptyList()
)

@Serializable
data class PendingReturnsResponse(
    val returns: List<ReturnRequestDto>
)

@Serializable
data class InspectItemRequest(
    val productId: String,
    val saleableQuantity: Int,
    val damagedQuantity: Int
)

@Serializable
data class InspectReturnRequest(
    val action: String,
    val items: List<InspectItemRequest>? = null,
    val notes: String? = null
)

@Serializable
data class InspectReturnResponse(
    val success: Boolean,
    val status: String,
    val totalCreditNotePaise: Long = 0
)


