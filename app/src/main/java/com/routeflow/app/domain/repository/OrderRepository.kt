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
        signatureUrl: String? = null
    ): Result<Unit>
    suspend fun updateItemPickingStatus(orderId: String, productId: String, isPicked: Boolean): Result<Unit>
    suspend fun syncPendingOrders(): Result<Int>
}
