package com.routeflow.app.core.network.api

import com.routeflow.app.core.network.dto.AuthResponse
import com.routeflow.app.core.network.dto.DeliveryCompletionRequest
import com.routeflow.app.core.network.dto.DispatchOrderRequest
import com.routeflow.app.core.network.dto.ItemPickRequest
import com.routeflow.app.core.network.dto.LoginRequest
import com.routeflow.app.core.network.dto.OrderDetailsResponse
import com.routeflow.app.core.network.dto.OrderDto
import com.routeflow.app.core.network.dto.OrderRejectionRequest
import com.routeflow.app.core.network.dto.OrderSubmitRequest
import com.routeflow.app.core.network.dto.OrderSubmitResponse
import com.routeflow.app.core.network.dto.ProductDto
import com.routeflow.app.core.network.dto.RefreshRequest
import com.routeflow.app.core.network.dto.RetailerDto
import com.routeflow.app.core.network.dto.StatusResponse
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
    suspend fun getRetailers(): List<RetailerDto>

    @GET("products")
    suspend fun getProducts(): List<ProductDto>

    @GET("orders")
    suspend fun getOrders(): List<OrderDto>

    @GET("orders/pending")
    suspend fun getPendingOrders(): List<OrderDto>

    @GET("orders/{id}")
    suspend fun getOrderDetails(@Path("id") orderId: String): OrderDetailsResponse

    @POST("orders")
    suspend fun submitOrder(@Body request: OrderSubmitRequest): OrderSubmitResponse

    @POST("orders/{id}/approve")
    suspend fun approveOrder(@Path("id") orderId: String): StatusResponse

    @POST("orders/{id}/reject")
    suspend fun rejectOrder(@Path("id") orderId: String, @Body request: OrderRejectionRequest): StatusResponse

    @GET("delivery-executives")
    suspend fun getDeliveryExecutives(): List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto>

    @POST("orders/{id}/start-picking")
    suspend fun startPicking(@Path("id") orderId: String): StatusResponse

    @POST("orders/{id}/pick-item")
    suspend fun pickItem(@Path("id") orderId: String, @Body request: ItemPickRequest): StatusResponse

    @POST("orders/{id}/pack")
    suspend fun packOrder(@Path("id") orderId: String): StatusResponse

    @POST("orders/{id}/dispatch")
    suspend fun dispatchOrder(@Path("id") orderId: String, @Body request: DispatchOrderRequest): StatusResponse

    @POST("orders/{id}/deliver")
    suspend fun completeDelivery(@Path("id") orderId: String, @Body request: DeliveryCompletionRequest): StatusResponse
}
