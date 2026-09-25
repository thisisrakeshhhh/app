package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.PaymentEntity
import com.routeflow.app.domain.repository.OrderRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import java.util.UUID
import javax.inject.Inject

class OfflineOrderRepository @Inject constructor(
    private val database: RouteFlowDatabase
) : OrderRepository {

    override fun getAllOrders(): Flow<List<OrderEntity>> = database.orderDao().getAllOrders()
    override fun getOrderById(orderId: String): Flow<OrderEntity?> = database.orderDao().getOrderById(orderId)
    override fun getItemsForOrder(orderId: String): Flow<List<OrderItemEntity>> = database.orderDao().getItemsForOrder(orderId)
    override fun getPendingSyncOutbox(): Flow<List<com.routeflow.app.core.database.entity.SyncOutboxEntity>> =
        database.syncOutboxDao().observeAllPendingSyncs()

    override suspend fun createOrder(order: OrderEntity, items: List<OrderItemEntity>): Result<Unit> {
        return try {
            database.orderDao().createOrderWithItems(order, items)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun approveOrder(orderId: String): Result<Unit> = try {
        database.withTransaction {
            val order = database.orderDao().getOrderById(orderId).first() 
                ?: throw Exception("Order not found")
            
            if (order.status != "SUBMITTED") throw Exception("Invalid status for approval")
            
            val items = database.orderDao().getItemsForOrder(orderId).first()
            val products = database.productDao().getAllProducts().first()
            
            // Check and reserve stock
            items.forEach { item ->
                val product = products.find { it.id == item.productId }
                    ?: throw Exception("Product ${item.productId} not found")
                
                val required = item.quantity + item.freeQuantity
                val available = product.stockQuantity - product.reservedQuantity
                if (available < required) {
                    throw Exception("Insufficient stock for ${product.name}")
                }
                
                database.productDao().updateReservation(product.id, product.reservedQuantity + required)
            }
            
            database.orderDao().updateOrderStatus(orderId, "APPROVED", System.currentTimeMillis())
            Result.success(Unit)
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun rejectOrder(orderId: String, reason: String): Result<Unit> = try {
        database.orderDao().updateOrderStatus(orderId, "REJECTED", System.currentTimeMillis())
        // If we reject an already approved order (if that's allowed), we'd need to release reservation.
        // For now, only SUBMITTED can be approved/rejected.
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

    override suspend fun dispatchOrder(orderId: String, deliveryEmployeeId: String): Result<Unit> = try {
        database.withTransaction {
            val order = database.orderDao().getOrderById(orderId).first()
                ?: throw Exception("Order not found")
            
            if (order.status != "PACKED") throw Exception("Order must be PACKED before dispatch")
            
            val items = database.orderDao().getItemsForOrder(orderId).first()
            val products = database.productDao().getAllProducts().first()
            
            // Consume stock and release reservation exactly once
            items.forEach { item ->
                val product = products.find { it.id == item.productId }
                    ?: throw Exception("Product ${item.productId} not found")
                
                val totalToDeduct = item.quantity + item.freeQuantity
                val newStock = product.stockQuantity - totalToDeduct
                val newReserved = (product.reservedQuantity - totalToDeduct).coerceAtLeast(0)
                
                if (newStock < 0) throw Exception("Stock went negative for ${product.name}")
                
                database.productDao().updateStock(product.id, newStock)
                database.productDao().updateReservation(product.id, newReserved)
            }
            
            database.orderDao().updateOrderStatus(orderId, "OUT_FOR_DELIVERY", System.currentTimeMillis())
            Result.success(Unit)
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getDeliveryExecutives(): Result<List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto>> =
        Result.success(emptyList())

    override suspend fun completeDelivery(orderId: String, paymentMethod: String): Result<Unit> = try {
        database.withTransaction {
            val order = database.orderDao().getOrderById(orderId).first()
                ?: throw Exception("Order not found")
            
            if (order.status != "OUT_FOR_DELIVERY") throw Exception("Order is not out for delivery")
            
            // Update order status
            database.orderDao().updateOrderStatus(orderId, "DELIVERED", System.currentTimeMillis())
            
            if (paymentMethod == "CREDIT") {
                val retailer = database.retailerDao().getRetailerById(order.retailerId).first()
                    ?: throw Exception("Retailer not found")
                val newOutstanding = retailer.outstandingAmountPaise + order.totalAmountPaise
                database.retailerDao().updateOutstanding(order.retailerId, newOutstanding)
            } else if (paymentMethod == "CASH") {
                val payment = PaymentEntity(
                    id = UUID.randomUUID().toString(),
                    orderId = orderId,
                    retailerId = order.retailerId,
                    amountPaise = order.totalAmountPaise,
                    method = "CASH",
                    timestamp = System.currentTimeMillis()
                )
                database.paymentDao().insertPayment(payment)
            }
            
            Result.success(Unit)
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateItemPickingStatus(
        orderId: String,
        productId: String,
        isPicked: Boolean
    ): Result<Unit> = try {
        database.orderDao().updateItemPickingStatus(orderId, productId, isPicked)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }
}
