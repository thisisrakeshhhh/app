package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.OrderWithItemsRequest
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.domain.repository.OrderRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject

class NetworkOrderRepository @Inject constructor(
    private val database: RouteFlowDatabase,
    private val api: RouteFlowApi,
    private val json: Json
) : OrderRepository {

    override fun getAllOrders(): Flow<List<OrderEntity>> = database.orderDao().getAllOrders()
    override fun getOrderById(orderId: String): Flow<OrderEntity?> = database.orderDao().getOrderById(orderId)
    override fun getItemsForOrder(orderId: String): Flow<List<OrderItemEntity>> = database.orderDao().getItemsForOrder(orderId)

    override suspend fun createOrder(order: OrderEntity, items: List<OrderItemEntity>): Result<Unit> {
        return try {
            val idempotencyKey = UUID.randomUUID().toString()
            val request = OrderWithItemsRequest(order, items, idempotencyKey)
            val payload = json.encodeToString(request)

            database.withTransaction {
                database.orderDao().insertOrder(order)
                database.orderDao().insertOrderItems(items)
                database.syncOutboxDao().insertSyncItem(
                    SyncOutboxEntity(
                        type = "ORDER_SUBMISSION",
                        payload = payload,
                        idempotencyKey = idempotencyKey
                    )
                )
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun approveOrder(orderId: String): Result<Unit> = try {
        val response = api.approveOrder(orderId)
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "APPROVED", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Approval failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun rejectOrder(orderId: String, reason: String): Result<Unit> = try {
        database.orderDao().updateOrderStatus(orderId, "REJECTED", System.currentTimeMillis())
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun startPicking(orderId: String): Result<Unit> = try {
        database.orderDao().updateOrderStatus(orderId, "PICKING", System.currentTimeMillis())
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun markPacked(orderId: String): Result<Unit> = try {
        database.orderDao().updateOrderStatus(orderId, "PACKED", System.currentTimeMillis())
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun dispatchOrder(orderId: String): Result<Unit> = try {
        val response = api.dispatchOrder(orderId)
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "OUT_FOR_DELIVERY", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Dispatch failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun completeDelivery(orderId: String, paymentMethod: String): Result<Unit> = try {
        database.orderDao().updateOrderStatus(orderId, "DELIVERED", System.currentTimeMillis())
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateItemPickingStatus(orderId: String, productId: String, isPicked: Boolean): Result<Unit> = try {
        database.orderDao().updateItemPickingStatus(orderId, productId, isPicked)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }
}
