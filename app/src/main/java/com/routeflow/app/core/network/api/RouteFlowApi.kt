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
    suspend fun submitOrder(@Body request: OrderSubmitRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): OrderSubmitResponse

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

    @POST("orders/{id}/request-otp")
    suspend fun requestDeliveryOtp(@Path("id") orderId: String): com.routeflow.app.core.network.dto.OtpResponse

    // --- Master Data Endpoints ---
    @POST("products")
    suspend fun createProduct(@Body request: com.routeflow.app.core.network.dto.CreateProductRequest): StatusResponse

    @retrofit2.http.PUT("products/{id}")
    suspend fun updateProduct(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.UpdateProductRequest): StatusResponse

    @POST("inventory/adjust")
    suspend fun adjustInventory(@Body request: com.routeflow.app.core.network.dto.StockAdjustmentRequest): com.routeflow.app.core.network.dto.StockAdjustmentResponse

    @POST("retailers")
    suspend fun createRetailer(@Body request: com.routeflow.app.core.network.dto.CreateRetailerRequest): StatusResponse

    @retrofit2.http.PUT("retailers/{id}")
    suspend fun updateRetailer(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.UpdateRetailerRequest): StatusResponse

    @GET("employees")
    suspend fun getEmployees(): List<com.routeflow.app.core.network.dto.EmployeeDto>

    @POST("employees")
    suspend fun createEmployee(@Body request: com.routeflow.app.core.network.dto.CreateEmployeeRequest): StatusResponse

    @retrofit2.http.PUT("employees/{id}/deactivate")
    suspend fun deactivateEmployee(@Path("id") id: String): StatusResponse

    // --- Visits & Stock Checks ---
    @POST("visits")
    suspend fun submitVisit(@Body request: com.routeflow.app.core.network.dto.VisitDto, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): StatusResponse

    @GET("visits")
    suspend fun getVisits(): List<com.routeflow.app.core.network.dto.VisitDto>

    @retrofit2.http.PUT("visits/{id}/checkout")
    suspend fun checkoutVisit(@Path("id") visitId: String, @Body request: com.routeflow.app.core.network.dto.CheckoutVisitRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): StatusResponse

    @POST("stock-checks")
    suspend fun submitStockCheck(@Body request: com.routeflow.app.core.network.dto.StockCheckDto, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): StatusResponse

    // --- Beats & Territory ---
    @GET("beats")
    suspend fun getBeats(): List<com.routeflow.app.core.network.dto.BeatDto>

    @POST("beats")
    suspend fun createBeat(@Body request: com.routeflow.app.core.network.dto.CreateBeatRequest): com.routeflow.app.core.network.dto.CreateBeatResponse

    @POST("beats/{id}/assign")
    suspend fun assignBeat(@Path("id") beatId: String, @Body request: com.routeflow.app.core.network.dto.AssignBeatRequest): StatusResponse

    // --- Shifts & Location Tracking ---
    @POST("shifts/start")
    suspend fun startShift(@Body request: com.routeflow.app.core.network.dto.StartShiftRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.ShiftResponse

    @POST("shifts/end")
    suspend fun endShift(@Body request: com.routeflow.app.core.network.dto.EndShiftRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.ShiftResponse

    @POST("shifts/locations")
    suspend fun uploadShiftLocations(@Body request: com.routeflow.app.core.network.dto.ShiftLocationsRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): StatusResponse

    @GET("team/status")
    suspend fun getTeamStatus(): List<com.routeflow.app.core.network.dto.TeamMemberStatusDto>

    // --- Daily Activity Review ---
    @GET("owner/visits/daily")
    suspend fun getDailyVisits(@retrofit2.http.Query("date") date: String? = null): List<com.routeflow.app.core.network.dto.DailyVisitDto>

    // --- Collections ---
    @POST("collections")
    suspend fun recordCollection(@Body request: com.routeflow.app.core.network.dto.RecordCollectionRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.RecordCollectionResponse

    @GET("collections")
    suspend fun getCollections(@retrofit2.http.Query("retailerId") retailerId: String? = null): com.routeflow.app.core.network.dto.CollectionsListResponse

    // --- Cash Handover ---
    @GET("handovers/summary")
    suspend fun getHandoverSummary(): com.routeflow.app.core.network.dto.CashHandoverSummaryResponse

    @POST("handovers/request")
    suspend fun submitHandoverRequest(@Body request: com.routeflow.app.core.network.dto.SubmitHandoverRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.SubmitHandoverResponse

    @GET("owner/handovers")
    suspend fun getOwnerHandovers(): com.routeflow.app.core.network.dto.OwnerHandoversResponse

    @POST("owner/handovers/{id}/acknowledge")
    suspend fun acknowledgeHandover(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.AcknowledgeHandoverRequest): com.routeflow.app.core.network.dto.AcknowledgeHandoverResponse

    // --- Returns ---
    @POST("returns")
    suspend fun createReturn(@Body request: com.routeflow.app.core.network.dto.CreateReturnRequest): com.routeflow.app.core.network.dto.CreateReturnResponse

    @GET("returns/pending")
    suspend fun getPendingReturns(): com.routeflow.app.core.network.dto.PendingReturnsResponse

    @POST("returns/{id}/inspect")
    suspend fun inspectReturn(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.InspectReturnRequest): com.routeflow.app.core.network.dto.InspectReturnResponse

    @GET("owner/closing")
    suspend fun getClosing(): com.routeflow.app.core.network.dto.ClosingResponse = error("Not implemented")
    @POST("owner/closing")
    suspend fun closeDay(@Body request: com.routeflow.app.core.network.dto.ClosingRequest): StatusResponse = error("Not implemented")
    @POST("collections/{id}/review")
    suspend fun reviewCollection(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.CollectionReviewRequest): StatusResponse = error("Not implemented")
    @POST("returns/{id}/{step}")
    suspend fun returnAction(@Path("id") id: String, @Path("step") step: String, @Body request: com.routeflow.app.core.network.dto.ReturnActionRequest): StatusResponse = error("Not implemented")
    @POST("shifts/{action}")
    suspend fun pauseShift(@Path("action") action: String, @Body request: com.routeflow.app.core.network.dto.ShiftPauseRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.ShiftResponse = error("Not implemented")
    @GET("shifts/current")
    suspend fun currentShift(): com.routeflow.app.core.network.dto.ShiftResponse = error("Not implemented")
}
