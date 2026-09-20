package com.routeflow.app.core.network.api

import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface RouteFlowApi {
    @GET("retailers")
    suspend fun getRetailers(): List<RetailerEntity>

    @GET("products")
    suspend fun getProducts(): List<ProductEntity>

    @POST("orders")
    suspend fun submitOrder(@Body request: OrderWithItemsRequest): OrderResponse

    @POST("orders/{id}/approve")
    suspend fun approveOrder(@Path("id") orderId: String): StatusResponse

    @POST("orders/{id}/dispatch")
    suspend fun dispatchOrder(@Path("id") orderId: String): StatusResponse
}

data class OrderWithItemsRequest(
    val order: OrderEntity,
    val items: List<OrderItemEntity>
)

data class OrderResponse(val success: Boolean, val orderId: String)
data class StatusResponse(val success: Boolean, val message: String? = null)
