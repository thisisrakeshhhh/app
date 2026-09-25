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
    val latitude: Double,
    val longitude: Double,
    val creditLimitPaise: Long,
    val outstandingAmountPaise: Long
)

fun RetailerDto.toEntity(): RetailerEntity = RetailerEntity(
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
    val paymentMethod: String = "CASH"
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

