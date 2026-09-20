package com.routeflow.app.domain.repository

import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import kotlinx.coroutines.flow.Flow

interface OrderRepository {
    fun getAllOrders(): Flow<List<OrderEntity>>
    fun getOrderById(orderId: String): Flow<OrderEntity?>
    fun getItemsForOrder(orderId: String): Flow<List<OrderItemEntity>>
    
    suspend fun createOrder(order: OrderEntity, items: List<OrderItemEntity>): Result<Unit>
    suspend fun approveOrder(orderId: String): Result<Unit>
    suspend fun rejectOrder(orderId: String, reason: String): Result<Unit>
    suspend fun startPicking(orderId: String): Result<Unit>
    suspend fun markPacked(orderId: String): Result<Unit>
    suspend fun dispatchOrder(orderId: String): Result<Unit>
    suspend fun completeDelivery(orderId: String, paymentMethod: String): Result<Unit>
    suspend fun updateItemPickingStatus(orderId: String, productId: String, isPicked: Boolean): Result<Unit>
}
