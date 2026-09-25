package com.routeflow.app.data.repository

import android.content.Context
import androidx.room.withTransaction
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.DeliveryCompletionRequest
import com.routeflow.app.core.network.dto.DeliveryExecutiveDto
import com.routeflow.app.core.network.dto.DispatchOrderRequest
import com.routeflow.app.core.network.dto.ItemPickRequest
import com.routeflow.app.core.network.dto.OrderRejectionRequest
import com.routeflow.app.core.network.dto.OrderSubmitRequest
import com.routeflow.app.core.network.dto.toDto
import com.routeflow.app.core.network.dto.toEntity
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.sync.OrderSyncWorker
import com.routeflow.app.domain.repository.OrderRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject

class NetworkOrderRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val database: RouteFlowDatabase,
    private val api: RouteFlowApi,
    private val tokenStorage: TokenStorage,
    private val syncManager: com.routeflow.app.data.sync.SyncManager,
    private val json: Json
) : OrderRepository {

    override fun getAllOrders(): Flow<List<OrderEntity>> = database.orderDao().getAllOrders()
    override fun getOrderById(orderId: String): Flow<OrderEntity?> = database.orderDao().getOrderById(orderId)
    override fun getItemsForOrder(orderId: String): Flow<List<OrderItemEntity>> = database.orderDao().getItemsForOrder(orderId)
    override fun getPendingSyncOutbox(): Flow<List<com.routeflow.app.core.database.entity.SyncOutboxEntity>> =
        database.syncOutboxDao().observeAllPendingSyncs()

    override suspend fun createOrder(order: OrderEntity, items: List<OrderItemEntity>): Result<Unit> {
        return try {
            val idempotencyKey = UUID.randomUUID().toString()
            val request = OrderSubmitRequest(
                order = order.toDto(),
                items = items.map { it.toDto() },
                idempotencyKey = idempotencyKey
            )
            val payload = json.encodeToString(request)
            val currentUserId = tokenStorage.getUserId() ?: ""
            val currentCompanyId = tokenStorage.getCompanyId() ?: ""

            database.withTransaction {
                database.orderDao().insertOrder(order)
                database.orderDao().insertOrderItems(items)
                database.syncOutboxDao().insertSyncItem(
                    SyncOutboxEntity(
                        type = "ORDER_SUBMISSION",
                        payload = payload,
                        idempotencyKey = idempotencyKey,
                        userId = currentUserId,
                        companyId = currentCompanyId
                    )
                )
            }

            // Immediately attempt submission over network if available
            try {
                val response = api.submitOrder(request)
                if (response.success) {
                    val syncItem = database.syncOutboxDao().getAllPendingSyncs()
                        .firstOrNull { it.idempotencyKey == idempotencyKey }
                    if (syncItem != null) {
                        database.syncOutboxDao().deleteSyncItem(syncItem)
                    }
                }
            } catch (_: Exception) {
                // Centralized sync scheduling without cancelling active workers
                syncManager.scheduleSync(currentUserId, currentCompanyId)
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
        val response = api.rejectOrder(orderId, OrderRejectionRequest(reason))
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "REJECTED", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Rejection failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun startPicking(orderId: String): Result<Unit> = try {
        val response = api.startPicking(orderId)
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "PICKING", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Failed to start picking"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateItemPickingStatus(orderId: String, productId: String, isPicked: Boolean): Result<Unit> = try {
        val response = api.pickItem(orderId, ItemPickRequest(productId, isPicked))
        if (response.success) {
            database.orderDao().updateItemPickingStatus(orderId, productId, isPicked)
            database.orderDao().updateOrderStatus(orderId, "PICKING", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Failed to update item picking"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun markPacked(orderId: String): Result<Unit> = try {
        val response = api.packOrder(orderId)
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "PACKED", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Failed to pack order"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun dispatchOrder(orderId: String, deliveryEmployeeId: String): Result<Unit> = try {
        val response = api.dispatchOrder(orderId, DispatchOrderRequest(deliveryEmployeeId = deliveryEmployeeId))
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "OUT_FOR_DELIVERY", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Dispatch failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getDeliveryExecutives(): Result<List<DeliveryExecutiveDto>> = try {
        Result.success(api.getDeliveryExecutives())
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun completeDelivery(orderId: String, paymentMethod: String): Result<Unit> = try {
        val response = api.completeDelivery(orderId, DeliveryCompletionRequest(paymentMethod = paymentMethod))
        if (response.success) {
            database.orderDao().updateOrderStatus(orderId, "DELIVERED", System.currentTimeMillis())
            Result.success(Unit)
        } else {
            Result.failure(Exception(response.message ?: "Delivery completion failed"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    suspend fun syncOrdersFromServer(): Result<Unit> = try {
        val currentUserId = tokenStorage.getUserId() ?: ""
        val currentCompanyId = tokenStorage.getCompanyId() ?: ""

        val ordersDto = api.getOrders()
        // 1. Fetch details outside any transaction
        val orderWithItemsList = ordersDto.map { orderDto ->
            val items = try {
                api.getOrderDetails(orderDto.id).items.map { it.toEntity() }
            } catch (_: Exception) {
                emptyList()
            }
            orderDto.toEntity() to items
        }

        // 2. Verify account context has not switched mid-fetch
        if (tokenStorage.getUserId() != currentUserId || tokenStorage.getCompanyId() != currentCompanyId) {
            Result.failure(IllegalStateException("Account switched during orders fetch"))
        } else {
            // 3. Short atomic Room transaction
            database.withTransaction {
                orderWithItemsList.forEach { (orderEntity, itemEntities) ->
                    database.orderDao().insertOrder(orderEntity)
                    if (itemEntities.isNotEmpty()) {
                        database.orderDao().insertOrderItems(itemEntities)
                    }
                }
            }
            Result.success(Unit)
        }
    } catch (e: Exception) {
        Result.failure(e)
    }
}
