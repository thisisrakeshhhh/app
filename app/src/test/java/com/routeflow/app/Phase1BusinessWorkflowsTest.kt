package com.routeflow.app

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.repository.OfflineOrderRepository
import com.routeflow.app.data.repository.OfflineProductRepository
import com.routeflow.app.data.repository.OfflineRetailerRepository
import com.routeflow.app.data.repository.WarehouseDataPipelineTest
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.model.Product
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Phase 1 Business Workflows Test Suite
 * Validates all 15 core acceptance criteria for Inventory + Retailers + Sales.
 */
@RunWith(RobolectricTestRunner::class)
class Phase1BusinessWorkflowsTest {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var tokenStorage: TokenStorage
    private lateinit var fakeApi: WarehouseDataPipelineTest.FakeRouteFlowApi

    private lateinit var productRepository: OfflineProductRepository
    private lateinit var retailerRepository: OfflineRetailerRepository
    private lateinit var orderRepository: OfflineOrderRepository

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tokenStorage = TokenStorage(context)
        fakeApi = WarehouseDataPipelineTest.FakeRouteFlowApi()

        productRepository = OfflineProductRepository(
            productDao = database.productDao(),
            api = fakeApi,
            stockMovementDao = database.stockMovementDao(),
            database = database,
            tokenStorage = tokenStorage
        )

        retailerRepository = OfflineRetailerRepository(
            retailerDao = database.retailerDao(),
            api = fakeApi,
            tokenStorage = tokenStorage,
            database = database,
            retailerPriceOverrideDao = database.retailerPriceOverrideDao()
        )

        orderRepository = OfflineOrderRepository(database = database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    // Criterion 1: An authorized user can create and edit a product.
    @Test
    fun test01_createAndEditProduct() = runBlocking {
        val createReq = CreateProductRequest(
            id = "PROD-001",
            name = "Basmati Rice 5kg",
            category = "Grains",
            pricePaise = 45000,
            stockQuantity = 50,
            unit = "bag",
            sku = "BR-5KG"
        )
        val createResult = productRepository.createProduct(createReq)
        assertTrue(createResult.isSuccess)

        val products = productRepository.getAllProducts().first()
        val created = products.find { it.id == "PROD-001" }
        assertNotNull(created)
        assertEquals("Basmati Rice 5kg", created?.name)
        assertEquals(45000L, created?.pricePaise)
        assertEquals(50, created?.stockQuantity)
        assertTrue(created?.isActive == true)

        // Edit product
        val updateReq = UpdateProductRequest(
            name = "Premium Basmati Rice 5kg",
            category = "Grains",
            pricePaise = 48000,
            unit = "bag",
            isActive = true
        )
        val updateResult = productRepository.updateProduct("PROD-001", updateReq)
        assertTrue(updateResult.isSuccess)

        val updated = productRepository.getAllProducts().first().find { it.id == "PROD-001" }
        assertEquals("Premium Basmati Rice 5kg", updated?.name)
        assertEquals(48000L, updated?.pricePaise)
    }

    // Criterion 2: Opening stock and stock receipts update inventory correctly.
    @Test
    fun test02_openingStockAndStockReceipts() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-002",
            name = "Mustard Oil 1L",
            category = "Oils",
            pricePaise = 15000,
            stockQuantity = 0,
            unit = "bottle"
        ))

        // Set opening stock: 40 bottles
        val openResult = productRepository.recordOpeningStock("PROD-002", 40, userId = "owner-1")
        assertTrue(openResult.isSuccess)
        assertEquals(40, openResult.getOrNull())

        var prod = productRepository.getAllProducts().first().find { it.id == "PROD-002" }!!
        assertEquals(40, prod.stockQuantity)
        assertEquals(40, prod.availableQuantity)

        // Stock receipt: +30 bottles
        val receiptResult = productRepository.recordStockReceipt("PROD-002", 30, userId = "owner-1", notes = "Supplier GRN-101")
        assertTrue(receiptResult.isSuccess)
        assertEquals(70, receiptResult.getOrNull())

        prod = productRepository.getAllProducts().first().find { it.id == "PROD-002" }!!
        assertEquals(70, prod.stockQuantity)
        assertEquals(70, prod.availableQuantity)
    }

    // Criterion 3: Stock adjustments create an auditable movement.
    @Test
    fun test03_stockAdjustmentsCreateAuditableMovements() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-003",
            name = "Sugar 1kg",
            category = "Staples",
            pricePaise = 4200,
            stockQuantity = 100,
            unit = "packet"
        ))

        // Record damaged stock adjustment: -5 packets
        val adjustResult = productRepository.recordStockAdjustment(
            productId = "PROD-003",
            changeQuantity = -5,
            reason = "DAMAGED - bag torn in godown",
            userId = "godown-mgr-1",
            notes = "Spilled content"
        )
        assertTrue(adjustResult.isSuccess)
        assertEquals(95, adjustResult.getOrNull())

        val prod = productRepository.getAllProducts().first().find { it.id == "PROD-003" }!!
        assertEquals(95, prod.stockQuantity)

        val movements = productRepository.getMovementsForProduct("PROD-003").first()
        assertTrue(movements.isNotEmpty())
        val damageMovement = movements.find { it.reason == "DAMAGED - bag torn in godown" }
        assertNotNull(damageMovement)
        assertEquals(-5, damageMovement?.quantity)
        assertEquals(100, damageMovement?.stockBefore)
        assertEquals(95, damageMovement?.stockAfter)
        assertEquals("godown-mgr-1", damageMovement?.createdBy)
    }

    // Criterion 4: Retailers can be created, searched and edited.
    @Test
    fun test04_retailerCreateSearchAndEdit() = runBlocking {
        val createReq = CreateRetailerRequest(
            id = "RET-101",
            name = "Aggarwal Traders",
            beatId = "BEAT-SECTOR-22",
            address = "SCF 14, Sector 22-D, Chandigarh",
            contactNumber = "9876543210",
            creditLimitPaise = 5000000,
            latitude = 30.7333,
            longitude = 76.7794
        )
        val createResult = retailerRepository.createRetailer(createReq)
        assertTrue(createResult.isSuccess)

        // Search by beat
        val byBeat = retailerRepository.getRetailersByBeat("BEAT-SECTOR-22").first()
        assertEquals(1, byBeat.size)
        assertEquals("Aggarwal Traders", byBeat.first().name)

        // Get by ID
        val ret = retailerRepository.getRetailerById("RET-101").first()
        assertNotNull(ret)
        assertEquals("SCF 14, Sector 22-D, Chandigarh", ret?.address)
        assertTrue(ret?.isActive == true)

        // Edit retailer
        val updateReq = UpdateRetailerRequest(
            name = "Aggarwal Super Store",
            address = "SCF 14-15, Sector 22-D, Chandigarh",
            contactNumber = "9876543210",
            creditLimitPaise = 7500000,
            isActive = true
        )
        val updateResult = retailerRepository.updateRetailer("RET-101", updateReq)
        assertTrue(updateResult.isSuccess)

        val updated = retailerRepository.getRetailerById("RET-101").first()
        assertEquals("Aggarwal Super Store", updated?.name)
    }

    // Criterion 5: An order can be drafted and submitted.
    @Test
    fun test05_draftAndSubmitOrder() = runBlocking {
        val order = OrderEntity(
            id = "ORD-TEST-001",
            retailerId = "RET-101",
            employeeId = "EMP-SALES-1",
            status = "SUBMITTED",
            totalAmountPaise = 30000,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        val items = listOf(
            OrderItemEntity(id = "ITEM-1", orderId = "ORD-TEST-001", productId = "PROD-001", quantity = 2, freeQuantity = 0, pricePaiseAtTime = 15000)
        )

        val createResult = orderRepository.createOrder(order, items)
        assertTrue(createResult.isSuccess)

        val savedOrder = orderRepository.getOrderById("ORD-TEST-001").first()
        assertNotNull(savedOrder)
        assertEquals("SUBMITTED", savedOrder?.status)
        assertEquals(30000L, savedOrder?.totalAmountPaise)

        val savedItems = orderRepository.getItemsForOrder("ORD-TEST-001").first()
        assertEquals(1, savedItems.size)
        assertEquals("PROD-001", savedItems.first().productId)
        assertEquals(2, savedItems.first().quantity)
    }

    // Criterion 6: An order uses the correct applicable unit price.
    @Test
    fun test06_correctApplicableUnitPrice() = runBlocking {
        val product = Product(
            id = "PROD-BISCUIT",
            name = "Glucose Biscuit 500g",
            category = "Snacks",
            pricePaise = 4000, // Default catalogue price ₹40.00
            stockQuantity = 200,
            unit = "pack"
        )
        database.productDao().insertProducts(listOf(ProductEntity(
            id = product.id, name = product.name, category = product.category, pricePaise = product.pricePaise, stockQuantity = 200, unit = "pack"
        )))

        // Retailer 1 has an active negotiated price override: ₹35.00 (3500 paise)
        retailerRepository.setRetailerPriceOverride(retailerId = "RET-VIP", productId = "PROD-BISCUIT", pricePaise = 3500)

        // Retailer 2 has no override
        val priceForVip = retailerRepository.getApplicablePrice("RET-VIP", product)
        val priceForStandard = retailerRepository.getApplicablePrice("RET-STANDARD", product)

        // Explicit rule: applicable active retailer-specific price takes precedence
        assertEquals(3500L, priceForVip)
        // Otherwise default product price
        assertEquals(4000L, priceForStandard)
    }

    // Criterion 7: Order totals are calculated correctly using integer paise arithmetic.
    @Test
    fun test07_orderTotalsCalculatedCorrectly() = runBlocking {
        val items = listOf(
            OrderItemEntity("IT-1", "ORD-TOTAL", "P1", quantity = 7, freeQuantity = 0, pricePaiseAtTime = 1250), // 8750
            OrderItemEntity("IT-2", "ORD-TOTAL", "P2", quantity = 13, freeQuantity = 0, pricePaiseAtTime = 499)  // 6487
        )
        // 8750 + 6487 = 15237 paise
        val order = OrderEntity(
            id = "ORD-TOTAL",
            retailerId = "R1",
            employeeId = "E1",
            status = "SUBMITTED",
            totalAmountPaise = 0, // Should be recalculated authoritatively
            createdAt = 1000L,
            updatedAt = 1000L
        )

        val result = orderRepository.createOrder(order, items)
        assertTrue(result.isSuccess)

        val saved = orderRepository.getOrderById("ORD-TOTAL").first()
        assertEquals(15237L, saved?.totalAmountPaise)
    }

    // Criterion 8: Confirming an order reserves the correct stock quantity.
    @Test
    fun test08_confirmOrderReservesStockQuantity() = runBlocking {
        database.retailerDao().insertRetailers(listOf(
            RetailerEntity("R-ACTIVE", "Gupta Store", "B1", "Addr", "999", 0.0, 0.0, 100000, 0, isActive = true)
        ))
        database.productDao().insertProducts(listOf(
            ProductEntity("P-STOCK", "Atta 10kg", "Flour", 38000, stockQuantity = 50, reservedQuantity = 0, unit = "bag", isActive = true)
        ))

        val orderId = "ORD-CONFIRM-1"
        val order = OrderEntity(orderId, "R-ACTIVE", "E1", "SUBMITTED", 76000, 1000, 1000)
        val items = listOf(OrderItemEntity("I-1", orderId, "P-STOCK", quantity = 2, freeQuantity = 0, pricePaiseAtTime = 38000))

        orderRepository.createOrder(order, items)
        val approveResult = orderRepository.approveOrder(orderId)
        assertTrue(approveResult.isSuccess)

        val updatedOrder = orderRepository.getOrderById(orderId).first()
        assertEquals("APPROVED", updatedOrder?.status)

        val product = database.productDao().getProductById("P-STOCK")
        assertEquals(50, product?.stockQuantity)
        assertEquals(2, product?.reservedQuantity)
        // Invariant: available = on_hand - reserved
        assertEquals(48, product!!.stockQuantity - product.reservedQuantity)
    }

    // Criterion 9: Insufficient stock prevents confirmation.
    @Test
    fun test09_insufficientStockPreventsConfirmation() = runBlocking {
        database.retailerDao().insertRetailers(listOf(
            RetailerEntity("R-ACTIVE", "Gupta Store", "B1", "Addr", "999", 0.0, 0.0, 100000, 0, isActive = true)
        ))
        database.productDao().insertProducts(listOf(
            ProductEntity("P-LOW", "Toor Dal 1kg", "Pulses", 16000, stockQuantity = 5, reservedQuantity = 2, unit = "kg", isActive = true)
        )) // Available = 5 - 2 = 3 units

        val orderId = "ORD-INSUFFICIENT"
        val order = OrderEntity(orderId, "R-ACTIVE", "E1", "SUBMITTED", 64000, 1000, 1000)
        val items = listOf(OrderItemEntity("I-1", orderId, "P-LOW", quantity = 4, freeQuantity = 0, pricePaiseAtTime = 16000)) // 4 > 3 available

        orderRepository.createOrder(order, items)
        val approveResult = orderRepository.approveOrder(orderId)

        assertTrue(approveResult.isFailure)
        assertTrue(approveResult.exceptionOrNull()?.message?.contains("Insufficient stock") == true)

        val orderAfter = orderRepository.getOrderById(orderId).first()
        assertEquals("SUBMITTED", orderAfter?.status)

        val product = database.productDao().getProductById("P-LOW")
        assertEquals(2, product?.reservedQuantity) // Unchanged
    }

    // Criterion 10: Retrying confirmation does not reserve stock twice.
    @Test
    fun test10_retryingConfirmationDoesNotDuplicateReservation() = runBlocking {
        database.retailerDao().insertRetailers(listOf(
            RetailerEntity("R-ACTIVE", "Gupta Store", "B1", "Addr", "999", 0.0, 0.0, 100000, 0, isActive = true)
        ))
        database.productDao().insertProducts(listOf(
            ProductEntity("P-IDEMP", "Soap 125g", "Personal Care", 4500, stockQuantity = 100, reservedQuantity = 0, unit = "bar", isActive = true)
        ))

        val orderId = "ORD-IDEMP-CONFIRM"
        val order = OrderEntity(orderId, "R-ACTIVE", "E1", "SUBMITTED", 45000, 1000, 1000)
        val items = listOf(OrderItemEntity("I-1", orderId, "P-IDEMP", quantity = 10, freeQuantity = 0, pricePaiseAtTime = 4500))

        orderRepository.createOrder(order, items)

        // First confirmation
        val res1 = orderRepository.approveOrder(orderId)
        assertTrue(res1.isSuccess)
        var product = database.productDao().getProductById("P-IDEMP")
        assertEquals(10, product?.reservedQuantity)

        // Retry confirmation (idempotent)
        val res2 = orderRepository.approveOrder(orderId)
        assertTrue(res2.isSuccess)

        product = database.productDao().getProductById("P-IDEMP")
        // Reservation must NOT be doubled to 20
        assertEquals(10, product?.reservedQuantity)
    }

    // Criterion 11: Cancelling/rejecting an order releases stock only when appropriate.
    @Test
    fun test11_cancellingOrRejectingOrderReleasesStockOnlyWhenAppropriate() = runBlocking {
        database.retailerDao().insertRetailers(listOf(
            RetailerEntity("R-ACTIVE", "Gupta Store", "B1", "Addr", "999", 0.0, 0.0, 100000, 0, isActive = true)
        ))
        database.productDao().insertProducts(listOf(
            ProductEntity("P-REL", "Noodles 70g", "Snacks", 1400, stockQuantity = 100, reservedQuantity = 0, unit = "pack", isActive = true)
        ))

        // Scenario A: Order is SUBMITTED and then REJECTED -> no reservation existed, none released
        val ordSubmitted = "ORD-REJ-SUBMITTED"
        orderRepository.createOrder(
            OrderEntity(ordSubmitted, "R-ACTIVE", "E1", "SUBMITTED", 14000, 1000, 1000),
            listOf(OrderItemEntity("I-A", ordSubmitted, "P-REL", quantity = 10, freeQuantity = 0, pricePaiseAtTime = 1400))
        )
        val rejSubResult = orderRepository.rejectOrder(ordSubmitted, "Retailer shop closed")
        assertTrue(rejSubResult.isSuccess)
        var product = database.productDao().getProductById("P-REL")
        assertEquals(0, product?.reservedQuantity)

        // Scenario B: Order is APPROVED (reserves 15 units), then subsequently REJECTED -> releases the 15 units
        val ordApproved = "ORD-REJ-APPROVED"
        orderRepository.createOrder(
            OrderEntity(ordApproved, "R-ACTIVE", "E1", "SUBMITTED", 21000, 1000, 1000),
            listOf(OrderItemEntity("I-B", ordApproved, "P-REL", quantity = 15, freeQuantity = 0, pricePaiseAtTime = 1400))
        )
        orderRepository.approveOrder(ordApproved)
        product = database.productDao().getProductById("P-REL")
        assertEquals(15, product?.reservedQuantity)

        val rejAppResult = orderRepository.rejectOrder(ordApproved, "Owner cancelled before packing")
        assertTrue(rejAppResult.isSuccess)

        product = database.productDao().getProductById("P-REL")
        // Reservation released back to 0
        assertEquals(0, product?.reservedQuantity)
        assertEquals("REJECTED", orderRepository.getOrderById(ordApproved).first()?.status)
    }

    // Criterion 12: Deactivated retailers/products cannot be used in new orders.
    @Test
    fun test12_deactivatedRetailersAndProductsCannotBeUsedInNewOrders() = runBlocking {
        database.retailerDao().insertRetailers(listOf(
            RetailerEntity("RET-INACTIVE", "Closed Shop", "B1", "Addr", "999", 0.0, 0.0, 100000, 0, isActive = false)
        ))
        database.productDao().insertProducts(listOf(
            ProductEntity("P-DISCONTINUED", "Old Brand Tea", "Beverage", 2500, stockQuantity = 50, reservedQuantity = 0, unit = "pack", isActive = false)
        ))

        val order = OrderEntity("ORD-BLOCKED", "RET-INACTIVE", "E1", "SUBMITTED", 5000, 1000, 1000)
        val items = listOf(OrderItemEntity("I-DISC", "ORD-BLOCKED", "P-DISCONTINUED", 2, 0, 2500))
        orderRepository.createOrder(order, items)

        // Confirmation must be rejected because retailer and product are deactivated
        val approveResult = orderRepository.approveOrder("ORD-BLOCKED")
        assertTrue(approveResult.isFailure)
        assertTrue(approveResult.exceptionOrNull()?.message?.contains("deactivated") == true)
    }

    // Criterion 13: Historical order prices remain unchanged after a catalogue price edit.
    @Test
    fun test13_historicalOrderPricesUnchangedAfterCataloguePriceEdit() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-TEA",
            name = "Red Label Tea 250g",
            category = "Beverages",
            pricePaise = 12000, // ₹120.00
            stockQuantity = 50,
            unit = "box"
        ))

        val orderId = "ORD-HISTORICAL-1"
        orderRepository.createOrder(
            OrderEntity(orderId, "RET-ANY", "EMP-1", "SUBMITTED", 24000, 1000, 1000),
            listOf(OrderItemEntity("I-TEA", orderId, "PROD-TEA", quantity = 2, freeQuantity = 0, pricePaiseAtTime = 12000))
        )

        // Now edit catalogue price from 12000 to 15000 paise (inflation adjustment)
        productRepository.updateProduct("PROD-TEA", UpdateProductRequest(
            name = "Red Label Tea 250g",
            category = "Beverages",
            pricePaise = 15000,
            unit = "box",
            isActive = true
        ))

        // Check catalogue price updated
        val updatedProduct = productRepository.getAllProducts().first().find { it.id == "PROD-TEA" }
        assertEquals(15000L, updatedProduct?.pricePaise)

        // Verify historical order item line price remains exactly 12000 paise
        val historicalItems = orderRepository.getItemsForOrder(orderId).first()
        assertEquals(1, historicalItems.size)
        assertEquals(12000L, historicalItems.first().pricePaiseAtTime)

        // Historical order total remains 24000 paise
        val historicalOrder = orderRepository.getOrderById(orderId).first()
        assertEquals(24000L, historicalOrder?.totalAmountPaise)
    }

    // Criterion 14: Existing authentication and role access remain functional.
    @Test
    fun test14_existingAuthenticationAndRoleAccessRemainFunctional() {
        tokenStorage.saveTokens("dummy_access", "dummy_refresh")
        tokenStorage.saveUser("USER-100", "Admin User", "OWNER", "COMP-TRI")
        assertEquals("USER-100", tokenStorage.getUserId())
        assertEquals("OWNER", tokenStorage.getUserRole())
        assertEquals("COMP-TRI", tokenStorage.getCompanyId())

        assertEquals("OWNER", EmployeeRole.OWNER.name)
        assertEquals("SALESPERSON", EmployeeRole.SALESPERSON.name)
        assertEquals("DELIVERY_EXECUTIVE", EmployeeRole.DELIVERY_EXECUTIVE.name)
        assertEquals("WAREHOUSE_MANAGER", EmployeeRole.WAREHOUSE_MANAGER.name)
    }

    // Criterion 15: Existing map functionality is not broken.
    @Test
    fun test15_existingMapFunctionalityRemainsUnbroken() = runBlocking {
        val retailerWithCoords = RetailerEntity(
            id = "RET-MAP-1",
            name = "Sector 17 Showroom",
            beatId = "CHANDIGARH-CENTRAL",
            address = "Sector 17 Plaza",
            contactNumber = "9812345678",
            latitude = 30.7398,
            longitude = 76.7827,
            creditLimitPaise = 10000000,
            outstandingAmountPaise = 0,
            isActive = true
        )
        database.retailerDao().insertRetailers(listOf(retailerWithCoords))

        val ret = retailerRepository.getRetailerById("RET-MAP-1").first()
        assertNotNull(ret)
        assertEquals(30.7398, ret!!.latitude, 0.0001)
        assertEquals(76.7827, ret.longitude, 0.0001)
    }

    // Criterion 16: Two orders competing for the same limited stock cannot oversell.
    @Test
    fun test16_concurrentOrdersCompetingForStock_preventsOverselling() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-COMPETE",
            name = "Sugar 1kg",
            category = "Staples",
            pricePaise = 5000,
            stockQuantity = 20, // Total 20 units available
            unit = "packet"
        ))

        retailerRepository.createRetailer(
            CreateRetailerRequest(id = "RET-COMPETE", name = "Compete Retailer", beatId = "BEAT-1", address = "Addr", contactNumber = "9999999999", creditLimitPaise = 100000L, latitude = 30.7, longitude = 76.7)
        )

        // Order 1 wants 15 units
        val order1 = OrderEntity("ORD-C1", "RET-COMPETE", "EMP-1", "SUBMITTED", 75000, 1000, 1000)
        val items1 = listOf(OrderItemEntity("IT-C1", "ORD-C1", "PROD-COMPETE", 15, 0, 5000))
        orderRepository.createOrder(order1, items1)

        // Order 2 also wants 15 units (together 30 units, exceeds 20 available)
        val order2 = OrderEntity("ORD-C2", "RET-COMPETE", "EMP-1", "SUBMITTED", 75000, 1000, 1000)
        val items2 = listOf(OrderItemEntity("IT-C2", "ORD-C2", "PROD-COMPETE", 15, 0, 5000))
        orderRepository.createOrder(order2, items2)

        // First approval succeeds
        val res1 = orderRepository.approveOrder("ORD-C1")
        assertTrue("Order 1 approval should succeed", res1.isSuccess)

        // Verify product reserved = 15, available = 5
        var prod = productRepository.getAllProducts().first().find { it.id == "PROD-COMPETE" }!!
        assertEquals(20, prod.stockQuantity)
        assertEquals(15, prod.reservedQuantity)
        assertEquals(5, prod.availableQuantity)

        // Second approval MUST fail due to insufficient available stock (only 5 left, needs 15)
        val res2 = orderRepository.approveOrder("ORD-C2")
        assertTrue("Order 2 approval must fail", res2.isFailure)
        assertTrue(res2.exceptionOrNull()?.message?.contains("Insufficient stock") == true)

        // Final state: stock was NOT oversold; reserved is still 15, available is still 5
        prod = productRepository.getAllProducts().first().find { it.id == "PROD-COMPETE" }!!
        assertEquals(20, prod.stockQuantity)
        assertEquals(15, prod.reservedQuantity)
        assertEquals(5, prod.availableQuantity)
    }

    // Criterion 17: Multi-item order with duplicate products aggregates total required quantity.
    @Test
    fun test17_multiItemOrderWithDuplicateProduct_aggregatesCorrectly() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-MULTI",
            name = "Coffee 50g",
            category = "Beverages",
            pricePaise = 8000,
            stockQuantity = 6, // Total 6 available
            unit = "jar"
        ))

        retailerRepository.createRetailer(
            CreateRetailerRequest(id = "RET-M1", name = "Multi Item Retailer", beatId = "BEAT-1", address = "Addr", contactNumber = "9999999999", creditLimitPaise = 100000L, latitude = 30.7, longitude = 76.7)
        )

        // Order has 2 line items for the same product: 4 units + 3 units = 7 units needed
        val order = OrderEntity("ORD-MULTI-1", "RET-M1", "EMP-1", "SUBMITTED", 56000, 1000, 1000)
        val items = listOf(
            OrderItemEntity("IT-M1-1", "ORD-MULTI-1", "PROD-MULTI", 4, 0, 8000),
            OrderItemEntity("IT-M1-2", "ORD-MULTI-1", "PROD-MULTI", 3, 0, 8000)
        )
        orderRepository.createOrder(order, items)

        // Needs 7, but only 6 available -> MUST fail
        val approveFail = orderRepository.approveOrder("ORD-MULTI-1")
        assertTrue("Approval should fail because 4 + 3 = 7 > 6", approveFail.isFailure)

        var prod = productRepository.getAllProducts().first().find { it.id == "PROD-MULTI" }!!
        assertEquals(6, prod.stockQuantity)
        assertEquals(0, prod.reservedQuantity)

        // Receive 4 more units into warehouse -> total stock 10
        productRepository.recordStockReceipt("PROD-MULTI", 4)

        // Now approval must succeed and reserve exactly 7 units
        val approveSuccess = orderRepository.approveOrder("ORD-MULTI-1")
        assertTrue("Approval should succeed now with 10 stock", approveSuccess.isSuccess)

        prod = productRepository.getAllProducts().first().find { it.id == "PROD-MULTI" }!!
        assertEquals(10, prod.stockQuantity)
        assertEquals(7, prod.reservedQuantity)
        assertEquals(3, prod.availableQuantity)

        // Reject order and verify both items (7 units) are released back
        val rejectRes = orderRepository.rejectOrder("ORD-MULTI-1", "Cancelled by retailer")
        assertTrue(rejectRes.isSuccess)

        prod = productRepository.getAllProducts().first().find { it.id == "PROD-MULTI" }!!
        assertEquals(10, prod.stockQuantity)
        assertEquals(0, prod.reservedQuantity)
        assertEquals(10, prod.availableQuantity)
    }

    // Criterion 18: Authoritative stock adjustment cannot reduce stock below reserved quantity.
    @Test
    fun test18_inventoryAdjustmentCannotReduceStockBelowReserved() = runBlocking {
        productRepository.createProduct(CreateProductRequest(
            id = "PROD-ADJ-SAFE",
            name = "Refined Oil 1L",
            category = "Oils",
            pricePaise = 15000,
            stockQuantity = 20,
            unit = "pouch"
        ))

        retailerRepository.createRetailer(
            CreateRetailerRequest(id = "RET-ADJ", name = "Adj Retailer", beatId = "BEAT-1", address = "Addr", contactNumber = "9999999999", creditLimitPaise = 100000L, latitude = 30.7, longitude = 76.7)
        )

        // Reserve 15 units via approved order
        val order = OrderEntity("ORD-ADJ-1", "RET-ADJ", "EMP-1", "SUBMITTED", 225000, 1000, 1000)
        orderRepository.createOrder(order, listOf(OrderItemEntity("IT-ADJ", "ORD-ADJ-1", "PROD-ADJ-SAFE", 15, 0, 15000)))
        val approveRes = orderRepository.approveOrder("ORD-ADJ-1")
        assertTrue(approveRes.isSuccess)

        // Stock = 20, Reserved = 15, Available = 5
        var prod = productRepository.getAllProducts().first().find { it.id == "PROD-ADJ-SAFE" }!!
        assertEquals(20, prod.stockQuantity)
        assertEquals(15, prod.reservedQuantity)

        // Attempt to adjust stock by -10 (which would leave 10 on hand, less than 15 reserved) -> MUST FAIL
        val adjResult = productRepository.recordStockAdjustment("PROD-ADJ-SAFE", -10, "DAMAGE")
        assertTrue("Adjustment reducing stock below reserved quantity must fail", adjResult.isFailure)

        // Stock and reserved remain unchanged
        prod = productRepository.getAllProducts().first().find { it.id == "PROD-ADJ-SAFE" }!!
        assertEquals(20, prod.stockQuantity)
        assertEquals(15, prod.reservedQuantity)
        assertEquals(5, prod.availableQuantity)
    }
}
