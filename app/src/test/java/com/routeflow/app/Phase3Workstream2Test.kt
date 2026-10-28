package com.routeflow.app

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.PlannedRouteEntity
import com.routeflow.app.core.database.entity.PlannedRouteStopEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.repository.OfflinePlannedRouteRepository
import com.routeflow.app.data.sync.SyncManager
import com.routeflow.app.domain.model.PlannedRoute
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.model.StopStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File

@RunWith(RobolectricTestRunner::class)
class Phase3Workstream2Test {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var tokenStorage: TokenStorage
    private lateinit var fakeApi: TestRouteFlowApi
    private lateinit var repository: OfflinePlannedRouteRepository
    private val json = Json { ignoreUnknownKeys = true }

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tokenStorage = TokenStorage(context)
        tokenStorage.saveTokens("mock_jwt", "mock_refresh")
        tokenStorage.saveUser("user_owner", "Owner", "OWNER", "comp_1")

        fakeApi = TestRouteFlowApi()
        repository = OfflinePlannedRouteRepository(
            database = database,
            plannedRouteDao = database.plannedRouteDao(),
            retailerDao = database.retailerDao(),
            tokenStorage = tokenStorage,
            syncManager = SyncManager(context, tokenStorage),
            api = fakeApi
        )
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun testMigration13To14_addsSyncStatusAndPreservesExistingData() {
        val dbFile = File(context.cacheDir, "test_migration_13_14.db")
        if (dbFile.exists()) dbFile.delete()

        // 1. Create a version 13 SQLite database with planned_route_stops without syncStatus
        val helperConfig = androidx.sqlite.db.SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(dbFile.name)
            .callback(object : androidx.sqlite.db.SupportSQLiteOpenHelper.Callback(13) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `planned_route_stops` (
                            `id` TEXT NOT NULL PRIMARY KEY,
                            `routeId` TEXT NOT NULL,
                            `companyId` TEXT NOT NULL,
                            `retailerId` TEXT NOT NULL,
                            `retailerName` TEXT NOT NULL,
                            `stopSequence` INTEGER NOT NULL,
                            `address` TEXT NOT NULL DEFAULT '',
                            `contactNumber` TEXT NOT NULL DEFAULT '',
                            `latitude` REAL NOT NULL DEFAULT 0.0,
                            `longitude` REAL NOT NULL DEFAULT 0.0,
                            `status` TEXT NOT NULL DEFAULT 'PENDING',
                            `visitedAt` INTEGER,
                            `notes` TEXT,
                            `createdAt` INTEGER NOT NULL,
                            `updatedAt` INTEGER NOT NULL
                        )
                    """.trimIndent())
                }

                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {}
            })
            .build()

        val v13Db = FrameworkSQLiteOpenHelperFactory().create(helperConfig).writableDatabase

        // Insert stop in v13 schema
        v13Db.execSQL("""
            INSERT INTO planned_route_stops (id, routeId, companyId, retailerId, retailerName, stopSequence, status, visitedAt, notes, createdAt, updatedAt)
            VALUES ('stop_v13', 'route_v13', 'comp_1', 'ret_1', 'Mega Mart', 1, 'VISITED', 1500, 'Existing visit', 1000, 1500)
        """.trimIndent())

        // 2. Execute MIGRATION_13_14
        RouteFlowDatabase.MIGRATION_13_14.migrate(v13Db)

        // 3. Verify data survived and default syncStatus was applied non-destructively
        val cursor = v13Db.query("SELECT id, status, visitedAt, notes, syncStatus FROM planned_route_stops WHERE id='stop_v13'")
        assertTrue(cursor.moveToFirst())
        assertEquals("stop_v13", cursor.getString(0))
        assertEquals("VISITED", cursor.getString(1))
        assertEquals(1500L, cursor.getLong(2))
        assertEquals("Existing visit", cursor.getString(3))
        assertEquals("UNVERIFIED", cursor.getString(4)) // Default value for pre-migration legacy rows
        cursor.close()

        v13Db.close()
        dbFile.delete()
    }

    @Test
    fun testRefreshRouteFromServer_conflictSafeguardsPreservePendingEdits() = runBlocking {
        // Setup local route with Stop 1 (local offline edit in outbox) and Stop 2 (unmodified)
        val routeId = "route_sync_test"
        val route = PlannedRouteEntity(
            id = routeId, companyId = "comp_1", routeDate = "2026-10-27", name = "Sync Route",
            salespersonId = "sales_1", salespersonName = "Sales", status = "PUBLISHED", totalStops = 2,
            createdBy = "user_owner", createdAt = 1000L, updatedAt = 1000L
        )
        val stop1 = PlannedRouteStopEntity(
            id = "stop_1", routeId = routeId, companyId = "comp_1", retailerId = "R1",
            retailerName = "Retailer 1", stopSequence = 1, status = "SKIPPED",
            notes = "Local offline skip", syncStatus = "SAVED_OFFLINE", createdAt = 1000L, updatedAt = 1100L
        )
        val stop2 = PlannedRouteStopEntity(
            id = "stop_2", routeId = routeId, companyId = "comp_1", retailerId = "R2",
            retailerName = "Retailer 2", stopSequence = 2, status = "PENDING",
            syncStatus = "CLOUD_CONFIRMED", createdAt = 1000L, updatedAt = 1000L
        )
        database.plannedRouteDao().insertRoute(route)
        database.plannedRouteDao().insertStops(listOf(stop1, stop2))

        // Enqueue outbox item for stop_1
        val payload = RouteStopStatusSyncPayload(
            routeId = routeId, stopId = "stop_1", status = "SKIPPED",
            visitedAt = null, notes = "Local offline skip", clientTimestamp = 1100L
        )
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 200,
                type = "ROUTE_STOP_STATUS",
                payload = json.encodeToString(payload),
                idempotencyKey = "stop_status_outbox_200",
                createdAt = 1100L,
                userId = "sales_1",
                companyId = "comp_1",
                syncState = "SAVED_OFFLINE"
            )
        )

        // Mock Server response:
        // Server still has stop_1 as PENDING (hasn't received sync yet)
        // Server has stop_2 updated to VISITED by another user / cloud
        fakeApi.routeDetailResponse = PlannedRouteDetailResponse(
            success = true,
            route = PlannedRouteNetworkDto(
                id = routeId, company_id = "comp_1", route_date = "2026-10-27",
                name = "Sync Route", salesperson_id = "sales_1", salesperson_name = "Sales",
                status = "PUBLISHED", total_stops = 2
            ),
            stops = listOf(
                PlannedRouteStopNetworkDto(
                    id = "stop_1", route_id = routeId, retailer_id = "R1", retailer_name = "Retailer 1",
                    stop_sequence = 1, status = "PENDING" // Outdated server state
                ),
                PlannedRouteStopNetworkDto(
                    id = "stop_2", route_id = routeId, retailer_id = "R2", retailer_name = "Retailer 2",
                    stop_sequence = 2, status = "VISITED", visited_at = 1200L, notes = "Cloud visit"
                )
            )
        )

        // Execute refresh
        val refreshResult = repository.refreshRouteFromServer(routeId)
        assertTrue(refreshResult.isSuccess)

        val updatedRoute = repository.getRouteById(routeId)
        assertNotNull(updatedRoute)
        val stops = updatedRoute!!.stops.sortedBy { it.stopSequence }

        // Stop 1: MUST NOT be overwritten by server PENDING state because it has a pending edit!
        assertEquals("stop_1", stops[0].id)
        assertEquals(StopStatus.SKIPPED, stops[0].status)
        assertEquals("Local offline skip", stops[0].notes)
        assertEquals("SAVED_OFFLINE", stops[0].syncStatus)

        // Stop 2: MUST be updated to server VISITED state and marked CLOUD_CONFIRMED
        assertEquals("stop_2", stops[1].id)
        assertEquals(StopStatus.VISITED, stops[1].status)
        assertEquals("Cloud visit", stops[1].notes)
        assertEquals("CLOUD_CONFIRMED", stops[1].syncStatus)
    }

    @Test
    fun testRefreshRouteFromServer_rejectsMismatchedCompany() = runBlocking {
        val routeId = "route_cross_tenant"
        val route = PlannedRouteEntity(
            id = routeId, companyId = "comp_1", routeDate = "2026-10-27", name = "Local Route",
            salespersonId = "sales_1", salespersonName = "Sales", status = "PUBLISHED", totalStops = 1,
            createdBy = "user_owner", createdAt = 1000L, updatedAt = 1000L
        )
        database.plannedRouteDao().insertRoute(route)

        // Server returns route belonging to another tenant
        fakeApi.routeDetailResponse = PlannedRouteDetailResponse(
            success = true,
            route = PlannedRouteNetworkDto(
                id = routeId, company_id = "comp_2", route_date = "2026-10-27",
                name = "Tenant 2 Route", salesperson_id = "sales_2", salesperson_name = "Sales 2",
                status = "PUBLISHED", total_stops = 1
            ),
            stops = emptyList()
        )

        val result = repository.refreshRouteFromServer(routeId)
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is IllegalStateException)
    }

    @Test
    fun testRefreshRouteFromServer_preservesEditMadeDuringInFlightRequest() = runBlocking {
        val routeId = "route_inflight_test"
        val route = PlannedRouteEntity(
            id = routeId, companyId = "comp_1", routeDate = "2026-10-27", name = "Inflight Route",
            salespersonId = "sales_1", salespersonName = "Sales", status = "PUBLISHED", totalStops = 1,
            createdBy = "user_owner", createdAt = 1000L, updatedAt = 1000L
        )
        val stop = PlannedRouteStopEntity(
            id = "stop_inflight", routeId = routeId, companyId = "comp_1", retailerId = "R1",
            retailerName = "Retailer 1", stopSequence = 1, status = "PENDING",
            syncStatus = "LOCAL_ONLY", createdAt = 1000L, updatedAt = 1000L
        )
        database.plannedRouteDao().insertRoute(route)
        database.plannedRouteDao().insertStop(stop)

        // Mock API call to simulate an edit occurring while network is in flight
        fakeApi.getRouteByIdInterceptor = {
            runBlocking {
                // Local edit occurs while network request was in flight!
                database.plannedRouteDao().updateStopStatus(
                    stopId = "stop_inflight",
                    status = "VISITED",
                    visitedAt = 1500L,
                    notes = "Just completed during refresh",
                    updatedAt = System.currentTimeMillis() + 50,
                    syncStatus = "SAVED_OFFLINE"
                )
            }
        }

        fakeApi.routeDetailResponse = PlannedRouteDetailResponse(
            success = true,
            route = PlannedRouteNetworkDto(
                id = routeId, company_id = "comp_1", route_date = "2026-10-27",
                name = "Inflight Route", salesperson_id = "sales_1", salesperson_name = "Sales",
                status = "PUBLISHED", total_stops = 1
            ),
            stops = listOf(
                PlannedRouteStopNetworkDto(
                    id = "stop_inflight", route_id = routeId, retailer_id = "R1", retailer_name = "Retailer 1",
                    stop_sequence = 1, status = "PENDING" // Stale server state from before the in-flight edit
                )
            )
        )

        val result = repository.refreshRouteFromServer(routeId)
        assertTrue(result.isSuccess)

        val updatedStop = database.plannedRouteDao().getStopById("stop_inflight")
        assertNotNull(updatedStop)
        assertEquals("VISITED", updatedStop!!.status)
        assertEquals("Just completed during refresh", updatedStop.notes)
        assertEquals("SAVED_OFFLINE", updatedStop.syncStatus)
    }

    @Test
    fun testProgressMetricsCalculation() {
        val stops = listOf(
            PlannedRouteStop(
                id = "s1", routeId = "r1", companyId = "c1", retailerId = "ret1",
                retailerName = "Shop 1", stopSequence = 1, status = StopStatus.VISITED
            ),
            PlannedRouteStop(
                id = "s2", routeId = "r1", companyId = "c1", retailerId = "ret2",
                retailerName = "Shop 2", stopSequence = 2, status = StopStatus.SKIPPED
            ),
            PlannedRouteStop(
                id = "s3", routeId = "r1", companyId = "c1", retailerId = "ret3",
                retailerName = "Shop 3", stopSequence = 3, status = StopStatus.PENDING
            ),
            PlannedRouteStop(
                id = "s4", routeId = "r1", companyId = "c1", retailerId = "ret4",
                retailerName = "Shop 4", stopSequence = 4, status = StopStatus.PENDING
            )
        )

        val route = PlannedRoute(
            id = "r1", companyId = "c1", routeDate = "2026-10-27", name = "Progress Route",
            salespersonId = "sales1", salespersonName = "Sales", totalStops = 4,
            createdBy = "owner", stops = stops
        )

        val total = if (route.stops.isNotEmpty()) route.stops.size else route.totalStops
        val visited = route.stops.count { it.status == StopStatus.VISITED }
        val skipped = route.stops.count { it.status == StopStatus.SKIPPED }
        val pending = if (route.stops.isNotEmpty()) route.stops.count { it.status == StopStatus.PENDING } else total
        val resolved = visited + skipped

        assertEquals(4, total)
        assertEquals(1, visited)
        assertEquals(1, skipped)
        assertEquals(2, pending)
        assertEquals(2, resolved)
        assertEquals(4, resolved + pending)
    }

    // Concrete fake RouteFlowApi for testing
    class TestRouteFlowApi : RouteFlowApi {
        var routeDetailResponse: PlannedRouteDetailResponse? = null
        var getRouteByIdInterceptor: (() -> Unit)? = null

        override suspend fun getRouteById(routeId: String, account: String?): PlannedRouteDetailResponse {
            getRouteByIdInterceptor?.invoke()
            return routeDetailResponse ?: PlannedRouteDetailResponse(success = true)
        }

        override suspend fun getRoutes(date: String?, salespersonId: String?, status: String?, account: String?): PlannedRoutesListResponse =
            PlannedRoutesListResponse(success = true)

        override suspend fun updateStopStatus(
            routeId: String,
            stopId: String,
            request: UpdateStopStatusRequest,
            account: String?,
            idempotencyKey: String?
        ): UpdateStopStatusResponse = UpdateStopStatusResponse(success = true)

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
        override suspend fun resetEmployeePassword(id: String, request: ResetEmployeePasswordRequest): StatusResponse = StatusResponse(success = true)
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
        override suspend fun recordCollection(request: RecordCollectionRequest, account: String?): RecordCollectionResponse = RecordCollectionResponse(success = true, collectionId = "c1", receiptId = request.receiptId, status = "SETTLED", balanceAfterPaise = 0)
        override suspend fun getHandoverSummary(): CashHandoverSummaryResponse = CashHandoverSummaryResponse(cashHeldPaise = 0, totalCollectedPaise = 0, totalSettledPaise = 0)
        override suspend fun submitHandoverRequest(request: SubmitHandoverRequest, account: String?): SubmitHandoverResponse = SubmitHandoverResponse(success = true, handoverId = "h1", status = "PENDING")
        override suspend fun getOwnerHandovers(): OwnerHandoversResponse = OwnerHandoversResponse(handovers = emptyList())
        override suspend fun acknowledgeHandover(id: String, request: AcknowledgeHandoverRequest): AcknowledgeHandoverResponse = AcknowledgeHandoverResponse(success = true, status = "ACCEPTED", receivedAmountPaise = 0, discrepancyPaise = 0)
        override suspend fun createReturn(request: CreateReturnRequest): CreateReturnResponse = CreateReturnResponse(success = true, returnId = "r1")
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
        override suspend fun createBatch(request: CreateBatchRequest): BatchDto = BatchDto(id = "b1", batchNo = request.batchNo, receivedQuantity = request.receivedQuantity)
        override suspend fun getBatchesForProduct(productId: String): BatchListResponse = BatchListResponse()
        override suspend fun getExpiryAlerts(): ExpiryAlertsResponse = ExpiryAlertsResponse()
        override suspend fun updateBatch(id: String, request: UpdateBatchRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateAlertConfig(request: AlertConfigRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun createTrip(request: CreateTripRequest): TripDetailDto = TripDetailDto(id = "t1", tripNumber = "TRIP-1", driverId = request.driverId, vehicleNumber = request.vehicleNumber, routeArea = request.routeArea, status = "PLANNED", startTime = 1000L)
        override suspend fun getActiveTrip(driverId: String?): TripDetailDto? = null
        override suspend fun getAllTrips(status: String?): List<TripDetailDto> = emptyList()
        override suspend fun reorderTripStops(id: String, request: ReorderStopsRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startTrip(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun completeTrip(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun submitVanSale(request: VanSaleSubmitRequest, idempotencyKey: String?): VanSaleSubmitResponse = throw NotImplementedError()
        override suspend fun confirmVanSale(orderId: String, idempotencyKey: String?): VanSaleSubmitResponse = throw NotImplementedError()
        override suspend fun getProductByBarcode(barcode: String): ProductDto = throw NotImplementedError()
        override suspend fun updateProductImage(id: String, request: UploadProductImageRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getWarehouseStock(search: String?, filter: String?): WarehouseStockResponse = WarehouseStockResponse()
        override suspend fun adjustWarehouseStock(request: WarehouseStockAdjustRequest): WarehouseStockAdjustResponse = WarehouseStockAdjustResponse(success = true)
        override suspend fun auditWarehouseStock(request: WarehouseStockAuditRequest): WarehouseStockAuditResponse = WarehouseStockAuditResponse(success = true)
        override suspend fun getWarehouseMovements(productId: String?, limit: Int?): List<StockMovementDto> = emptyList()
        override suspend fun getWarehouseBatches(productId: String?): List<WarehouseBatchDto> = emptyList()
        override suspend fun createWarehouseBatch(request: CreateWarehouseBatchRequest): WarehouseBatchDto = WarehouseBatchDto(id = "wb_1", productId = request.productId, batchNo = request.batchNo)
        override suspend fun getWarehouseNearExpiryBatches(): List<WarehouseBatchDto> = emptyList()
        override suspend fun getWarehousePickingQueue(): PickingQueueResponse = PickingQueueResponse()
        override suspend fun startWarehousePicking(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun scanPickItem(id: String, request: ScanPickRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun markOrderPackedWarehouse(id: String, request: MarkPackedRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun createDispatchBatch(request: CreateDispatchBatchRequest): DispatchBatchDto = DispatchBatchDto(id = "db_1", batchCode = "DSP-TEST")
        override suspend fun getDispatchBatches(): List<DispatchBatchDto> = emptyList()
        override suspend fun assignDispatchDriver(id: String, request: AssignDispatchDriverRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun handoverDispatchBatch(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun getWarehouseReturns(): WarehouseReturnsResponse = WarehouseReturnsResponse()
        override suspend fun inspectWarehouseReturn(request: InspectWarehouseReturnRequest): InspectWarehouseReturnResponse = InspectWarehouseReturnResponse(success = true)
    }
}
