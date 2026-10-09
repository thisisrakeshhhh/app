package com.routeflow.app.data.repository

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class WarehouseDataPipelineTest {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var tokenStorage: TokenStorage
    private lateinit var fakeApi: FakeRouteFlowApi
    private lateinit var repository: OfflineWarehouseRepository

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tokenStorage = TokenStorage(context)
        fakeApi = FakeRouteFlowApi()

        repository = OfflineWarehouseRepository(
            api = fakeApi,
            productDao = database.productDao(),
            productBatchDao = database.productBatchDao(),
            stockMovementDao = database.stockMovementDao(),
            dispatchBatchDao = database.dispatchBatchDao(),
            warehouseReturnDao = database.warehouseReturnDao(),
            orderDao = database.orderDao(),
            tokenStorage = tokenStorage,
            database = database
        )
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun testGetStock_fetchesFromServerAndCachesInRoom() = runBlocking {
        fakeApi.stockResponse = WarehouseStockResponse(
            products = listOf(
                WarehouseStockItemDto(
                    id = "p1",
                    name = "Fortune Oil 1L",
                    category = "Oils",
                    pricePaise = 13500,
                    stockQuantity = 50,
                    unit = "bottle",
                    barcode = "8901030000001"
                )
            ),
            total = 1
        )

        val result = repository.getStock()
        assertTrue(result.isSuccess)
        val data = result.getOrNull()
        assertNotNull(data)
        assertEquals(1, data?.products?.size)
        assertEquals("Fortune Oil 1L", data?.products?.first()?.name)

        // Verify cached in Room productDao
        val cached = database.productDao().getAllProducts().first()
        assertEquals(1, cached.size)
        assertEquals("p1", cached.first().id)
        assertEquals("Fortune Oil 1L", cached.first().name)
        assertEquals("8901030000001", cached.first().barcode)
    }

    @Test
    fun testFindProductByBarcode_returnsMatchingProduct() = runBlocking {
        fakeApi.barcodeMap["8901030000001"] = ProductDto(
            id = "p1",
            name = "Fortune Oil 1L",
            category = "Oils",
            pricePaise = 13500,
            stockQuantity = 50,
            unit = "bottle",
            barcode = "8901030000001"
        )

        val result = repository.findProductByBarcode("8901030000001")
        assertTrue(result.isSuccess)
        assertEquals("p1", result.getOrNull()?.id)
        assertEquals("8901030000001", result.getOrNull()?.barcode)
    }

    @Test
    fun testAdjustStock_updatesLocalCacheAndLogsMovement() = runBlocking {
        database.productDao().insertProducts(
            listOf(
                ProductEntity(
                    id = "p1",
                    name = "Fortune Oil 1L",
                    category = "Oils",
                    pricePaise = 13500,
                    stockQuantity = 50,
                    unit = "bottle",
                    barcode = "8901030000001"
                )
            )
        )

        fakeApi.stockAdjustResponse = WarehouseStockAdjustResponse(
            success = true,
            movementId = "mov_1",
            productId = "p1",
            productName = "Fortune Oil 1L",
            stockBefore = 50,
            newStockQuantity = 45
        )

        val result = repository.adjustStock(
            productId = "p1",
            changeQuantity = -5,
            reason = "DAMAGED",
            notes = "Leaking carton"
        )
        assertTrue(result.isSuccess)
        assertEquals(45, result.getOrNull()?.newStockQuantity)

        val updatedProduct = database.productDao().getProductById("p1")
        assertEquals(45, updatedProduct?.stockQuantity)
    }

    @Test
    fun testPickingQueue_andCartonPackingWorkflow() = runBlocking {
        fakeApi.pickingQueueResponse = PickingQueueResponse(
            orders = listOf(
                PickingOrderDto(
                    id = "ord_101",
                    retailerId = "ret_1",
                    retailerName = "Sharma Kirana",
                    status = "PICKING",
                    totalAmountPaise = 45000,
                    createdAt = System.currentTimeMillis(),
                    cartonsCount = 2,
                    items = listOf(
                        PickingOrderItemDto(
                            id = "item_1",
                            orderId = "ord_101",
                            productId = "p1",
                            productName = "Fortune Oil 1L",
                            quantity = 5,
                            isPicked = true,
                            suggestedBatch = SuggestedBatchDto(id = "b1", batchNo = "B-001")
                        )
                    ),
                    allPicked = true
                )
            )
        )

        val queueResult = repository.getPickingQueue()
        assertTrue(queueResult.isSuccess)
        assertEquals(1, queueResult.getOrNull()?.size)

        val packResult = repository.markOrderPacked(
            orderId = "ord_101",
            cartonsCount = 2,
            notes = "Packed in 2 heavy corrugated boxes"
        )
        assertTrue(packResult.isSuccess)
        assertEquals("ord_101", fakeApi.lastPackedOrderId)
        assertEquals(2, fakeApi.lastPackedCartonsCount)
    }

    @Test
    fun testDispatchBatch_andDeliveryHandoverWorkflow() = runBlocking {
        fakeApi.dispatchBatchDto = DispatchBatchDto(
            id = "batch_101",
            batchCode = "DSP-2026-0001",
            status = "CREATED",
            totalOrders = 3,
            totalCartons = 5
        )

        val createResult = repository.createDispatchBatch(
            orderIds = listOf("ord_1", "ord_2", "ord_3"),
            driverId = "driver_1"
        )
        assertTrue(createResult.isSuccess)
        assertEquals("DSP-2026-0001", createResult.getOrNull()?.batchCode)

        val handoverResult = repository.handoverDispatchBatch("batch_101")
        assertTrue(handoverResult.isSuccess)
        assertEquals("batch_101", fakeApi.lastHandedOverBatchId)
    }

    @Test
    fun testReturnInspection_restockSaleable() = runBlocking {
        database.productDao().insertProducts(
            listOf(
                ProductEntity(
                    id = "p1",
                    name = "Fortune Oil 1L",
                    category = "Oils",
                    pricePaise = 13500,
                    stockQuantity = 50,
                    unit = "bottle",
                    barcode = "8901030000001"
                )
            )
        )

        fakeApi.inspectReturnResponse = InspectWarehouseReturnResponse(
            success = true,
            inspectionId = "insp_1",
            actionTaken = "RESTOCKED_TO_ACTIVE_INVENTORY",
            condition = "SALEABLE",
            restocked = true,
            newStockQuantity = 55
        )

        val result = repository.inspectReturn(
            InspectWarehouseReturnRequest(
                productId = "p1",
                quantity = 5,
                condition = "SALEABLE",
                notes = "Unopened cartons returned from cancelled delivery"
            )
        )
        assertTrue(result.isSuccess)
        assertEquals(true, result.getOrNull()?.restocked)
        assertEquals(55, result.getOrNull()?.newStockQuantity)

        val updatedProduct = database.productDao().getProductById("p1")
        assertEquals(55, updatedProduct?.stockQuantity)
    }

    // Concrete fake RouteFlowApi for testing Warehouse operations
    class FakeRouteFlowApi : RouteFlowApi {
        var stockResponse = WarehouseStockResponse()
        val barcodeMap = mutableMapOf<String, ProductDto>()
        var stockAdjustResponse = WarehouseStockAdjustResponse(success = true)
        var pickingQueueResponse = PickingQueueResponse()
        var dispatchBatchDto = DispatchBatchDto(id = "db_1", batchCode = "DSP-TEST")
        var inspectReturnResponse = InspectWarehouseReturnResponse(success = true)

        var lastPackedOrderId: String? = null
        var lastPackedCartonsCount: Int? = null
        var lastHandedOverBatchId: String? = null

        override suspend fun getWarehouseStock(search: String?, filter: String?): WarehouseStockResponse = stockResponse
        override suspend fun getProductByBarcode(barcode: String): ProductDto = barcodeMap[barcode] ?: throw RuntimeException("Not found")
        override suspend fun adjustWarehouseStock(request: WarehouseStockAdjustRequest): WarehouseStockAdjustResponse = stockAdjustResponse
        override suspend fun auditWarehouseStock(request: WarehouseStockAuditRequest): WarehouseStockAuditResponse = WarehouseStockAuditResponse(success = true)
        override suspend fun getWarehouseMovements(productId: String?, limit: Int?): List<StockMovementDto> = emptyList()
        override suspend fun getWarehouseBatches(productId: String?): List<WarehouseBatchDto> = emptyList()
        override suspend fun createWarehouseBatch(request: CreateWarehouseBatchRequest): WarehouseBatchDto = WarehouseBatchDto(id = "wb_1", productId = request.productId, batchNo = request.batchNo)
        override suspend fun getWarehouseNearExpiryBatches(): List<WarehouseBatchDto> = emptyList()
        override suspend fun getWarehousePickingQueue(): PickingQueueResponse = pickingQueueResponse
        override suspend fun startWarehousePicking(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun scanPickItem(id: String, request: ScanPickRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun markOrderPackedWarehouse(id: String, request: MarkPackedRequest): StatusResponse {
            lastPackedOrderId = id
            lastPackedCartonsCount = request.cartonsCount
            return StatusResponse(success = true)
        }
        override suspend fun createDispatchBatch(request: CreateDispatchBatchRequest): DispatchBatchDto = dispatchBatchDto
        override suspend fun getDispatchBatches(): List<DispatchBatchDto> = listOf(dispatchBatchDto)
        override suspend fun assignDispatchDriver(id: String, request: AssignDispatchDriverRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun handoverDispatchBatch(id: String): StatusResponse {
            lastHandedOverBatchId = id
            return StatusResponse(success = true)
        }
        override suspend fun getWarehouseReturns(): WarehouseReturnsResponse = WarehouseReturnsResponse()
        override suspend fun inspectWarehouseReturn(request: InspectWarehouseReturnRequest): InspectWarehouseReturnResponse = inspectReturnResponse
        override suspend fun updateProductImage(id: String, request: UploadProductImageRequest): StatusResponse = StatusResponse(success = true)

        // General RouteFlowApi stubs
        override suspend fun login(request: LoginRequest): AuthResponse = throw NotImplementedError()
        override suspend fun refreshToken(request: RefreshRequest): AuthResponse = throw NotImplementedError()
        override suspend fun logout(): StatusResponse = StatusResponse(success = true)
        override suspend fun getRetailers(): List<RetailerDto> = emptyList()
        override suspend fun getProducts(): List<ProductDto> = emptyList()
        override suspend fun getOrders(): List<OrderDto> = emptyList()
        override suspend fun getPendingOrders(): List<OrderDto> = emptyList()
        override suspend fun getOrderDetails(orderId: String): OrderDetailsResponse = throw NotImplementedError()
        override suspend fun approveOrder(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun rejectOrder(orderId: String, request: OrderRejectionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun submitOrder(request: OrderSubmitRequest, account: String?): OrderSubmitResponse = OrderSubmitResponse(success = true, orderId = request.order.id)
        override suspend fun pickItem(orderId: String, request: ItemPickRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startPicking(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun packOrder(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun dispatchOrder(orderId: String, request: DispatchOrderRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getDeliveryExecutives(): List<DeliveryExecutiveDto> = emptyList()
        override suspend fun completeDelivery(orderId: String, request: DeliveryCompletionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun requestDeliveryOtp(orderId: String): OtpResponse = OtpResponse(success = true)
        override suspend fun createProduct(request: CreateProductRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateProduct(id: String, request: UpdateProductRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun adjustInventory(request: StockAdjustmentRequest): StockAdjustmentResponse = StockAdjustmentResponse(success = true)
        override suspend fun createRetailer(request: CreateRetailerRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateRetailer(id: String, request: UpdateRetailerRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getEmployees(): List<EmployeeDto> = emptyList()
        override suspend fun createEmployee(request: CreateEmployeeRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun deactivateEmployee(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun resetEmployeePassword(id: String, request: com.routeflow.app.core.network.dto.ResetEmployeePasswordRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getVisits(): List<VisitDto> = emptyList()

        override suspend fun submitVisit(request: VisitDto, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun checkoutVisit(visitId: String, request: CheckoutVisitRequest, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun submitStockCheck(request: StockCheckDto, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun getStockChecks(retailerId: String, account: String?): List<RetailerStockCheckItemDto> = emptyList()
        override suspend fun uploadShiftLocations(request: ShiftLocationsRequest, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun startShift(request: StartShiftRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun endShift(request: EndShiftRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun getBeats(): List<BeatDto> = emptyList()
        override suspend fun createBeat(request: CreateBeatRequest): CreateBeatResponse = CreateBeatResponse(success = true)
        override suspend fun assignBeat(beatId: String, request: AssignBeatRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getTeamStatus(): List<TeamMemberStatusDto> = emptyList()
        override suspend fun getDailyVisits(date: String?): List<DailyVisitDto> = emptyList()
        override suspend fun getCollections(retailerId: String?): CollectionsListResponse = CollectionsListResponse(collections = emptyList())
        override suspend fun recordCollection(request: RecordCollectionRequest, account: String?): RecordCollectionResponse = RecordCollectionResponse(success = true, collectionId = "col_1", receiptId = request.receiptId, status = "SETTLED", balanceAfterPaise = 0)
        override suspend fun getHandoverSummary(): CashHandoverSummaryResponse = CashHandoverSummaryResponse(cashHeldPaise = 0, totalCollectedPaise = 0, totalSettledPaise = 0)
        override suspend fun submitHandoverRequest(request: SubmitHandoverRequest, account: String?): SubmitHandoverResponse = SubmitHandoverResponse(success = true, handoverId = "hnd_1", status = "PENDING")
        override suspend fun getOwnerHandovers(): OwnerHandoversResponse = OwnerHandoversResponse(handovers = emptyList())
        override suspend fun acknowledgeHandover(id: String, request: AcknowledgeHandoverRequest): AcknowledgeHandoverResponse = AcknowledgeHandoverResponse(success = true, status = "ACCEPTED", receivedAmountPaise = 0, discrepancyPaise = 0)
        override suspend fun createReturn(request: CreateReturnRequest): CreateReturnResponse = CreateReturnResponse(success = true, returnId = "ret_1")
        override suspend fun getPendingReturns(): PendingReturnsResponse = PendingReturnsResponse(returns = emptyList())
        override suspend fun inspectReturn(id: String, request: InspectReturnRequest): InspectReturnResponse = InspectReturnResponse(success = true, status = "APPROVED", totalCreditNotePaise = 0)
        override suspend fun getClosing(): ClosingResponse = ClosingResponse()
        override suspend fun closeDay(request: ClosingRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun reviewCollection(id: String, request: CollectionReviewRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun returnAction(id: String, step: String, request: ReturnActionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun pauseShift(action: String, request: ShiftPauseRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun currentShift(): ShiftResponse = ShiftResponse(success = true)
        override suspend fun failDelivery(orderId: String, request: DeliveryFailureRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getUndeliveredGoods(status: String?): List<UndeliveredGoodsDto> = emptyList()
        override suspend fun acknowledgeUndeliveredGoods(id: String, request: AcknowledgeUndeliveredRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getDeliveryExceptions(): List<DeliveryExceptionDto> = emptyList()
        override suspend fun getDriverHeldStock(): List<DriverHeldStockDto> = emptyList()
        override suspend fun retryDelivery(id: String, request: RetryDeliveryRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getOrderItemsBulk(request: BulkOrderItemsRequest): BulkOrderItemsResponse = BulkOrderItemsResponse()
        override suspend fun registerOwner(request: RegisterOwnerRequest): AuthResponse = throw NotImplementedError()
        override suspend fun acceptInvite(request: AcceptInviteRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun createBatch(request: CreateBatchRequest): BatchDto = BatchDto(id = "batch_1", batchNo = request.batchNo, receivedQuantity = request.receivedQuantity)
        override suspend fun getBatchesForProduct(productId: String): BatchListResponse = BatchListResponse()
        override suspend fun getExpiryAlerts(): ExpiryAlertsResponse = ExpiryAlertsResponse()
        override suspend fun updateBatch(id: String, request: UpdateBatchRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateAlertConfig(request: AlertConfigRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun createTrip(request: CreateTripRequest): TripDetailDto = TripDetailDto(id = "trip_1", tripNumber = "TRIP-1001", driverId = request.driverId, vehicleNumber = request.vehicleNumber, routeArea = request.routeArea, status = "PLANNED", startTime = System.currentTimeMillis())
        override suspend fun getActiveTrip(driverId: String?): TripDetailDto? = null
        override suspend fun getAllTrips(status: String?): List<TripDetailDto> = emptyList()
        override suspend fun reorderTripStops(id: String, request: ReorderStopsRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startTrip(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun completeTrip(id: String): StatusResponse = StatusResponse(success = true)
    }
}
