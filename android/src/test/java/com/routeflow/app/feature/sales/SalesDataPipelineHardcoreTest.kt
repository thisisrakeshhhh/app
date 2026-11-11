package com.routeflow.app.feature.sales

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.database.entity.VisitEntity
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.domain.model.Retailer
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class SalesDataPipelineHardcoreTest {

    private lateinit var database: RouteFlowDatabase

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun testRetailer_CRUD_and_scoping() = runBlocking {
        val retailerDao = database.retailerDao()

        // 1. CREATE (Insert / Post Retailer)
        val retailer1 = RetailerEntity(
            id = "RET-001",
            name = "Gupta Provision Store",
            beatId = "BEAT-04",
            address = "Shop 12, Tonk Road",
            contactNumber = "9829011223",
            latitude = 26.9124,
            longitude = 75.7873,
            creditLimitPaise = 5000000,
            outstandingAmountPaise = 1500000,
            companyId = "comp_1",
            lastSyncedAt = System.currentTimeMillis(),
            source = "SERVER"
        )
        val retailer2 = RetailerEntity(
            id = "RET-002",
            name = "Sharma Kirana",
            beatId = "BEAT-05",
            address = "Shop 4, Mansarovar",
            contactNumber = "9829011224",
            latitude = 26.8500,
            longitude = 75.7600,
            creditLimitPaise = 3000000,
            outstandingAmountPaise = 500000,
            companyId = "comp_1",
            lastSyncedAt = System.currentTimeMillis(),
            source = "SERVER"
        )
        retailerDao.insertRetailers(listOf(retailer1, retailer2))

        // 2. READ (Get All & Get By Beat & Get By ID)
        val all = retailerDao.getAllRetailers().first()
        assertEquals(2, all.size)

        val beat4Retailers = retailerDao.getRetailersByBeat("BEAT-04").first()
        assertEquals(1, beat4Retailers.size)
        assertEquals("Gupta Provision Store", beat4Retailers.first().name)

        val single = retailerDao.getRetailerById("RET-001").first()
        assertNotNull(single)
        assertEquals("Gupta Provision Store", single?.name)

        // 3. UPDATE (Put / Update outstanding balance)
        retailerDao.updateOutstanding("RET-001", 1200000)
        val updated = retailerDao.getRetailerById("RET-001").first()
        assertEquals(1200000L, updated?.outstandingAmountPaise)

        // 4. DELETE (Delete Server / Clear all)
        retailerDao.deleteServerRetailers()
        val afterDelete = retailerDao.getAllRetailers().first()
        assertEquals(0, afterDelete.size)
    }

    @Test
    fun testOrderBooking_and_Items_CRUD() = runBlocking {
        val orderDao = database.orderDao()

        // 1. CREATE Order with Items
        val orderId = "ORD-TEST-100"
        val order = OrderEntity(
            id = orderId,
            retailerId = "RET-001",
            employeeId = "user_sales",
            status = "SUBMITTED",
            totalAmountPaise = 90000,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        val items = listOf(
            OrderItemEntity(
                id = "ITEM-1",
                orderId = orderId,
                productId = "P1",
                quantity = 2,
                freeQuantity = 0,
                pricePaiseAtTime = 45000,
                isPicked = false
            )
        )
        orderDao.createOrderWithItems(order, items)

        // 2. READ Order & Items
        val savedOrder = orderDao.getOrderById(orderId).first()
        assertNotNull(savedOrder)
        assertEquals(90000L, savedOrder?.totalAmountPaise)

        val savedItems = orderDao.getItemsForOrder(orderId).first()
        assertEquals(1, savedItems.size)
        assertEquals("P1", savedItems.first().productId)
        assertEquals(2, savedItems.first().quantity)

        // 3. UPDATE Status
        orderDao.updateOrderStatus(orderId, "APPROVED", System.currentTimeMillis())
        val updatedOrder = orderDao.getOrderById(orderId).first()
        assertEquals("APPROVED", updatedOrder?.status)

        // 4. DELETE / Clear
        orderDao.deleteAllOrders()
        orderDao.deleteAllOrderItems()
        val remaining = orderDao.getAllOrders().first()
        assertEquals(0, remaining.size)
    }

    @Test
    fun testShopVisit_CheckIn_and_CheckOut() = runBlocking {
        val visitDao = database.visitDao()
        val visitId = "VISIT-001"
        val employeeId = "user_sales"
        val checkIn = System.currentTimeMillis()

        // 1. Check-in (Insert ACTIVE visit)
        val visit = VisitEntity(
            id = visitId,
            retailerId = "RET-001",
            employeeId = employeeId,
            checkInTime = checkIn,
            checkOutTime = null,
            latitude = 26.9124,
            longitude = 75.7873,
            accuracy = 5.0f,
            companyId = "comp_1",
            notes = null,
            noOrderReason = null,
            status = "ACTIVE"
        )
        visitDao.insertVisit(visit)

        // Verify active visit exists
        val active = visitDao.getActiveVisit(employeeId).first()
        assertNotNull(active)
        assertEquals("ACTIVE", active?.status)
        assertEquals(visitId, active?.id)

        // 2. Check-out (Complete visit)
        val checkOut = checkIn + 30000
        visitDao.completeVisit(visitId, checkOut)

        val activeAfter = visitDao.getActiveVisit(employeeId).first()
        assertNull(activeAfter)

        val visits = visitDao.getVisitsByEmployee(employeeId).first()
        assertEquals(1, visits.size)
        assertEquals("COMPLETED", visits.first().status)
    }

    @Test
    fun testCollection_Record_and_SyncConfirmation() = runBlocking {
        val collectionDao = database.collectionRecordDao()
        val colId = "COL-LOCAL-001"
        val companyId = "comp_1"
        val userId = "user_sales"

        // 1. Record Collection locally
        val record = CollectionRecordEntity(
            id = colId,
            companyId = companyId,
            retailerId = "RET-001",
            retailerName = "Gupta Provision Store",
            amountPaise = 250000,
            paymentMethod = "CASH",
            receiptId = "REC-1234",
            notes = "Test collection",
            collectedBy = userId,
            timestamp = System.currentTimeMillis(),
            isSynced = false,
            paymentState = "RECORDED"
        )
        collectionDao.insertCollection(record)

        // 2. Observe collections
        val list = collectionDao.observeCollections(companyId, userId).first()
        assertEquals(1, list.size)
        assertEquals(250000L, list.first().amountPaise)
        assertEquals(false, list.first().isSynced)

        // 3. Confirm sync
        collectionDao.confirm(colId, "SETTLED", "SERVER-COL-1", "REC-1234")
        val confirmed = collectionDao.observeCollections(companyId, userId).first()
        assertEquals(true, confirmed.first().isSynced)
        assertEquals("SETTLED", confirmed.first().paymentState)
    }
}
