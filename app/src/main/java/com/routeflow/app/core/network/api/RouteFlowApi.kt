package com.routeflow.app.core.network.api

import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface RouteFlowApi {
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshRequest): AuthResponse

    @POST("auth/logout")
    suspend fun logout(): StatusResponse

    @GET("retailers")
    suspend fun getRetailers(): List<RetailerEntity>

    @GET("products")
    suspend fun getProducts(): List<ProductEntity>

    @GET("orders/pending")
    suspend fun getPendingOrders(): List<OrderEntity>

    @GET("orders/{id}")
    suspend fun getOrderDetails(@Path("id") orderId: String): OrderWithItemsResponse

    @POST("orders")
    suspend fun submitOrder(@Body request: OrderWithItemsRequest): OrderResponse

    @POST("orders/{id}/approve")
    suspend fun approveOrder(@Path("id") orderId: String): StatusResponse

    @POST("orders/{id}/dispatch")
    suspend fun dispatchOrder(@Path("id") orderId: String): StatusResponse
}

@Serializable
data class LoginRequest(val username: String, val password: String)

@Serializable
data class RefreshRequest(val refresh_token: String)

@Serializable
data class AuthResponse(
    val access_token: String,
    val refresh_token: String,
    val user: UserDto? = null
)

@Serializable
data class UserDto(
    val id: String,
    val name: String,
    val role: String,
    val company_id: String
)

@Serializable
data class OrderWithItemsRequest(
    val order: OrderEntity,
    val items: List<OrderItemEntity>,
    val idempotency_key: String
)

@Serializable
data class OrderWithItemsResponse(
    val order: OrderEntity,
    val items: List<OrderItemEntity>
)

@Serializable
data class StatusResponse(val success: Boolean, val message: String? = null)
