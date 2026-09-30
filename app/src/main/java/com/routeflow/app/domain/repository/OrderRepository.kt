package com.routeflow.app.domain.repository

import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.dto.DeliveryExecutiveDto
import com.routeflow.app.core.network.dto.OtpResponse
import kotlinx.coroutines.flow.Flow

interface OrderRepository {
    fun getAllOrders(): Flow<List<OrderEntity>>
    fun getOrderById(orderId: String): Flow<OrderEntity?>
    fun getItemsForOrder(orderId: String): Flow<List<OrderItemEntity>>
    fun getPendingSyncOutbox(): Flow<List<SyncOutboxEntity>>
    
    suspend fun createOrder(order: OrderEntity, items: List<OrderItemEntity>): Result<Unit>
    suspend fun approveOrder(orderId: String): Result<Unit>
    suspend fun rejectOrder(orderId: String, reason: String): Result<Unit>
    suspend fun startPicking(orderId: String): Result<Unit>
    suspend fun markPacked(orderId: String): Result<Unit>
    suspend fun dispatchOrder(orderId: String, deliveryEmployeeId: String): Result<Unit>
    suspend fun getDeliveryExecutives(): Result<List<DeliveryExecutiveDto>>
    suspend fun requestDeliveryOtp(orderId: String): Result<OtpResponse>
    suspend fun completeDelivery(
        orderId: String,
        paymentMethod: String,
        otp: String = "",
        recipientName: String = "",
        proofPhotoUrl: String? = null,
        signatureUrl: String? = null,
        items: List<com.routeflow.app.core.network.dto.DeliveryItemCompletionRequest>? = null
    ): Result<Unit>
    suspend fun failDelivery(
        orderId: String,
        reason: String,
        rescheduledDate: String? = null,
        notes: String? = null
    ): Result<Unit>
    suspend fun getUndeliveredGoods(status: String? = null): Result<List<com.routeflow.app.core.network.dto.UndeliveredGoodsDto>>
    suspend fun acknowledgeUndeliveredGoods(
        id: String,
        request: com.routeflow.app.core.network.dto.AcknowledgeUndeliveredRequest
    ): Result<Unit>
    suspend fun getDeliveryExceptions(): Result<List<com.routeflow.app.core.network.dto.DeliveryExceptionDto>>
    suspend fun getDriverHeldStock(): Result<List<com.routeflow.app.core.network.dto.DriverHeldStockDto>>
    suspend fun retryDelivery(
        orderId: String,
        deliveryEmployeeId: String,
        rescheduledDate: String? = null,
        notes: String? = null
    ): Result<Unit>
    suspend fun updateItemPickingStatus(orderId: String, productId: String, isPicked: Boolean): Result<Unit>
    suspend fun syncPendingOrders(): Result<Int>

    /**
     * Fetches order items from the server for [orderId] and inserts them into Room.
     * Call this when the detail screen opens and the Room Flow emits an empty list,
     * indicating the order was not included in the bounded login pre-fetch.
     * Returns [Result.failure] when offline or the server returns an error.
     */
    suspend fun fetchAndCacheOrderItems(orderId: String): Result<Unit>
}
