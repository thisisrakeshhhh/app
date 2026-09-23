package com.routeflow.app.data.repository

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class OfflineOrderRepositoryTest {

    private lateinit var database: RouteFlowDatabase
    private lateinit var repository: OfflineOrderRepository

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        repository = OfflineOrderRepository(database)
        
        runBlocking {
            // Seed a product
            database.productDao().insertProducts(listOf(
                ProductEntity("P1", "Premium Tea", "Beverages", 1000, 10, 0, "Unit")
            ))
            // Seed a retailer
            database.retailerDao().insertRetailers(listOf(
                RetailerEntity("R1", "Store", "B1", "Addr", "123", 0.0, 0.0, 10000, 0)
            ))
        }
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun approveOrder_checksStock() = runBlocking {
        val orderId = "O1"
        val order = OrderEntity(orderId, "R1", "E1", "SUBMITTED", 1000, 0, 0)
        val items = listOf(OrderItemEntity("I1", orderId, "P1", 11, 0, 1000)) // 11 > 10 stock
        
        repository.createOrder(order, items)
        
        val result = repository.approveOrder(orderId)
        assertTrue(result.isFailure)
        assertEquals("Insufficient stock for Premium Tea", result.exceptionOrNull()?.message)
    }

    @Test
    fun dispatchOrder_deductsStock() = runBlocking {
        val orderId = "O1"
        val order = OrderEntity(orderId, "R1", "E1", "SUBMITTED", 1000, 0, 0)
        val items = listOf(OrderItemEntity("I1", orderId, "P1", 5, 0, 1000))
        
        repository.createOrder(order, items)
        repository.approveOrder(orderId)
        database.orderDao().updateOrderStatus(orderId, "PACKED", 0) // Skip picking for test
        
        val result = repository.dispatchOrder(orderId)
        assertTrue(result.isSuccess)
        
        val product = database.productDao().getAllProducts().first().first()
        assertEquals(5, product.stockQuantity) // 10 - 5 = 5
    }
}
