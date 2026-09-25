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

