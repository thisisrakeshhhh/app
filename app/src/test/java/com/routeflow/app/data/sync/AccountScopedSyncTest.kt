package com.routeflow.app.data.sync

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.work.ListenableWorker
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.workDataOf
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.AuthResponse
import com.routeflow.app.core.network.dto.DeliveryCompletionRequest
import com.routeflow.app.core.network.dto.DispatchOrderRequest
import com.routeflow.app.core.network.dto.ItemPickRequest
import com.routeflow.app.core.network.dto.LoginRequest
import com.routeflow.app.core.network.dto.OrderDetailsResponse
import com.routeflow.app.core.network.dto.OrderDto
import com.routeflow.app.core.network.dto.OrderItemDto
import com.routeflow.app.core.network.dto.OrderRejectionRequest
import com.routeflow.app.core.network.dto.OrderSubmitRequest
import com.routeflow.app.core.network.dto.OrderSubmitResponse
import com.routeflow.app.core.network.dto.ProductDto
import com.routeflow.app.core.network.dto.RefreshRequest
import com.routeflow.app.core.network.dto.RetailerDto
import com.routeflow.app.core.network.dto.StatusResponse
import com.routeflow.app.core.security.TokenStorage
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class AccountScopedSyncTest {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var testTokenStorage: FakeTokenStorage
    private lateinit var fakeApi: FakeRouteFlowApi
    private val json = Json { ignoreUnknownKeys = true }

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        testTokenStorage = FakeTokenStorage(context)
        fakeApi = FakeRouteFlowApi()
    }

    @After
    fun tearDown() {
        database.close()
    }

    private fun createWorker(userId: String, companyId: String): OrderSyncWorker {
        return TestListenableWorkerBuilder<OrderSyncWorker>(context)
            .setInputData(
                workDataOf(
                    OrderSyncWorker.KEY_USER_ID to userId,
                    OrderSyncWorker.KEY_COMPANY_ID to companyId
                )
            )
            .setWorkerFactory(object : WorkerFactory() {
                override fun createWorker(
                    appContext: Context,
                    workerClassName: String,
                    workerParameters: WorkerParameters
                ): ListenableWorker {
                    return OrderSyncWorker(
                        appContext,
                        workerParameters,
                        fakeApi,
                        database,
                        testTokenStorage,
                        json
                    )
                }
            })
            .build()
    }

    @Test
    fun testAccountSwitch_doesNotProcessOtherAccountsOrders_andProcessesOnSwitchBack() = runBlocking {
        // Step 1: User A logs in
        testTokenStorage.saveUser("user_A", "User A", "SALESPERSON", "comp_A")

        // User A queues an offline order
        val orderA = OrderDto(
            id = "order_A_1",
            retailerId = "ret_1",
            employeeId = "user_A",
            status = "SUBMITTED",
            totalAmountPaise = 10000,
            createdAt = 1000L,
            updatedAt = 1000L
        )
        val itemsA = listOf(
            OrderItemDto(
                id = "item_A_1",
                orderId = "order_A_1",
                productId = "prod_1",
                quantity = 10,
                freeQuantity = 1,
                pricePaiseAtTime = 1000
            )
        )
        val submitRequestA = OrderSubmitRequest(
            order = orderA,
            items = itemsA,
            idempotencyKey = "idemp_A_1"
        )
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 1,
                type = "ORDER_SUBMISSION",
                payload = json.encodeToString(submitRequestA),
                idempotencyKey = "idemp_A_1",
                createdAt = 1000L,
                userId = "user_A",
                companyId = "comp_A"
            )
        )

        // Verify outbox has 1 pending item for Account A
        val pendingA = database.syncOutboxDao().getPendingSyncsForUser("user_A", "comp_A")
        assertEquals(1, pendingA.size)

        // Step 2: Switch to Account B
        testTokenStorage.saveUser("user_B", "User B", "SALESPERSON", "comp_B")

        // Run worker for Account B
        val workerB = createWorker("user_B", "comp_B")
        val resultB = workerB.doWork()
        assertEquals(ListenableWorker.Result.success(), resultB)

        // Account B's worker must NOT submit Account A's order
        assertEquals(0, fakeApi.submittedOrders.size)
        // Account A's order must still be in the outbox
        assertEquals(1, database.syncOutboxDao().getPendingSyncsForUser("user_A", "comp_A").size)

        // Attempting to run a stale worker for Account A while Account B is active must abort safely
        val staleWorkerA = createWorker("user_A", "comp_A")
        val staleResult = staleWorkerA.doWork()
        assertEquals(ListenableWorker.Result.success(), staleResult)
        assertEquals(0, fakeApi.submittedOrders.size)

        // Step 3: Switch back to Account A
        testTokenStorage.saveUser("user_A", "User A", "SALESPERSON", "comp_A")

        // Run worker for Account A
        val workerA = createWorker("user_A", "comp_A")
        val resultA = workerA.doWork()
        assertEquals(ListenableWorker.Result.success(), resultA)

        // Account A's order is now submitted exactly once
        assertEquals(1, fakeApi.submittedOrders.size)
        assertEquals("order_A_1", fakeApi.submittedOrders.first().order.id)
        // Account A's outbox item is now removed
        assertEquals(0, database.syncOutboxDao().getPendingSyncsForUser("user_A", "comp_A").size)

        // Re-running worker A does not submit again
        val workerASecond = createWorker("user_A", "comp_A")
        workerASecond.doWork()
        assertEquals(1, fakeApi.submittedOrders.size)
    }

    @Test
    fun testLegacyOutboxRows_areQuarantinedAndNotSubmitted() = runBlocking {
        testTokenStorage.saveUser("user_A", "User A", "SALESPERSON", "comp_A")

        // Insert legacy outbox row without userId and companyId (empty strings)
        val legacyRequest = OrderSubmitRequest(
            order = OrderDto(
                id = "order_legacy",
                retailerId = "ret_1",
                employeeId = "legacy_user",
                status = "SUBMITTED",
                totalAmountPaise = 5000,
                createdAt = 500L,
                updatedAt = 500L
            ),
            items = emptyList(),
            idempotencyKey = "idemp_legacy"
        )
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 99,
                type = "ORDER_SUBMISSION",
                payload = json.encodeToString(legacyRequest),
                idempotencyKey = "idemp_legacy",
                createdAt = 500L,
                userId = "",
                companyId = ""
            )
        )

        // Run worker
        val worker = createWorker("user_A", "comp_A")
        val result = worker.doWork()
        assertEquals(ListenableWorker.Result.success(), result)

        // Verify legacy row was quarantined and NOT submitted
        assertEquals(0, fakeApi.submittedOrders.size)
        val quarantined = database.syncOutboxDao().getQuarantinedSyncs()
        assertEquals(1, quarantined.size)
        assertEquals(99L, quarantined.first().id)
        assertEquals("QUARANTINED", quarantined.first().type)
    }

    // Fake TokenStorage that stores active user in memory without EncryptedSharedPreferences dependency
    class FakeTokenStorage(context: Context) : TokenStorage(context) {
        private var userId: String? = null
        private var userName: String? = null
        private var userRole: String? = null
        private var companyId: String? = null
        private var accessToken: String? = null
        private var refreshToken: String? = null

        override fun saveTokens(accessToken: String, refreshToken: String) {
            this.accessToken = accessToken
            this.refreshToken = refreshToken
        }

        override fun saveUser(id: String, name: String, role: String, companyId: String) {
            this.userId = id
            this.userName = name
            this.userRole = role
            this.companyId = companyId
        }

        override fun getAccessToken(): String? = accessToken
        override fun getRefreshToken(): String? = refreshToken
        override fun getUserId(): String? = userId
        override fun getUserName(): String? = userName
        override fun getUserRole(): String? = userRole
        override fun getCompanyId(): String? = companyId

        override fun clear() {
            userId = null
            userName = null
            userRole = null
            companyId = null
            accessToken = null
            refreshToken = null
        }
    }

    // Fake RouteFlowApi implementation
    class FakeRouteFlowApi : RouteFlowApi {
        val submittedOrders = mutableListOf<OrderSubmitRequest>()

        override suspend fun submitOrder(request: OrderSubmitRequest, account: String?): OrderSubmitResponse {
            submittedOrders.add(request)
            return OrderSubmitResponse(success = true, orderId = request.order.id, idempotent = false)
        }

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
        override suspend fun pickItem(orderId: String, request: ItemPickRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startPicking(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun packOrder(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun dispatchOrder(orderId: String, request: DispatchOrderRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getDeliveryExecutives(): List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto> = emptyList()
        override suspend fun completeDelivery(orderId: String, request: DeliveryCompletionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun requestDeliveryOtp(orderId: String): com.routeflow.app.core.network.dto.OtpResponse =
            com.routeflow.app.core.network.dto.OtpResponse(success = true, debugOtp = "123456")
        override suspend fun createProduct(request: com.routeflow.app.core.network.dto.CreateProductRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateProduct(id: String, request: com.routeflow.app.core.network.dto.UpdateProductRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun adjustInventory(request: com.routeflow.app.core.network.dto.StockAdjustmentRequest): com.routeflow.app.core.network.dto.StockAdjustmentResponse =
            com.routeflow.app.core.network.dto.StockAdjustmentResponse(success = true, newStockQuantity = 100)
        override suspend fun createRetailer(request: com.routeflow.app.core.network.dto.CreateRetailerRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun updateRetailer(id: String, request: com.routeflow.app.core.network.dto.UpdateRetailerRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getEmployees(): List<com.routeflow.app.core.network.dto.EmployeeDto> = emptyList()
        override suspend fun createEmployee(request: com.routeflow.app.core.network.dto.CreateEmployeeRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun deactivateEmployee(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun submitVisit(request: com.routeflow.app.core.network.dto.VisitDto, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun getVisits(): List<com.routeflow.app.core.network.dto.VisitDto> = emptyList()
        override suspend fun checkoutVisit(visitId: String, request: com.routeflow.app.core.network.dto.CheckoutVisitRequest, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun submitStockCheck(request: com.routeflow.app.core.network.dto.StockCheckDto, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun getBeats(): List<com.routeflow.app.core.network.dto.BeatDto> = emptyList()
        override suspend fun createBeat(request: com.routeflow.app.core.network.dto.CreateBeatRequest): com.routeflow.app.core.network.dto.CreateBeatResponse =
            com.routeflow.app.core.network.dto.CreateBeatResponse(success = true)
        override suspend fun assignBeat(beatId: String, request: com.routeflow.app.core.network.dto.AssignBeatRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startShift(request: com.routeflow.app.core.network.dto.StartShiftRequest, account: String?): com.routeflow.app.core.network.dto.ShiftResponse =
            com.routeflow.app.core.network.dto.ShiftResponse(success = true)
        override suspend fun endShift(request: com.routeflow.app.core.network.dto.EndShiftRequest, account: String?): com.routeflow.app.core.network.dto.ShiftResponse =
            com.routeflow.app.core.network.dto.ShiftResponse(success = true)
        override suspend fun uploadShiftLocations(request: com.routeflow.app.core.network.dto.ShiftLocationsRequest, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun getTeamStatus(): List<com.routeflow.app.core.network.dto.TeamMemberStatusDto> = emptyList()
        override suspend fun getDailyVisits(date: String?): List<com.routeflow.app.core.network.dto.DailyVisitDto> = emptyList()
        override suspend fun recordCollection(request: com.routeflow.app.core.network.dto.RecordCollectionRequest, account: String?): com.routeflow.app.core.network.dto.RecordCollectionResponse =
            com.routeflow.app.core.network.dto.RecordCollectionResponse(success = true, collectionId = "col_1", receiptId = request.receiptId, status = "SETTLED", balanceAfterPaise = 0)
        override suspend fun getCollections(retailerId: String?): com.routeflow.app.core.network.dto.CollectionsListResponse =
            com.routeflow.app.core.network.dto.CollectionsListResponse(collections = emptyList())
        override suspend fun getHandoverSummary(): com.routeflow.app.core.network.dto.CashHandoverSummaryResponse =
            com.routeflow.app.core.network.dto.CashHandoverSummaryResponse(cashHeldPaise = 0, totalCollectedPaise = 0, totalSettledPaise = 0)
        override suspend fun submitHandoverRequest(request: com.routeflow.app.core.network.dto.SubmitHandoverRequest, account: String?): com.routeflow.app.core.network.dto.SubmitHandoverResponse =
            com.routeflow.app.core.network.dto.SubmitHandoverResponse(success = true, handoverId = "hnd_1", status = "PENDING")
        override suspend fun getOwnerHandovers(): com.routeflow.app.core.network.dto.OwnerHandoversResponse =
            com.routeflow.app.core.network.dto.OwnerHandoversResponse(handovers = emptyList())
        override suspend fun acknowledgeHandover(id: String, request: com.routeflow.app.core.network.dto.AcknowledgeHandoverRequest): com.routeflow.app.core.network.dto.AcknowledgeHandoverResponse =
            com.routeflow.app.core.network.dto.AcknowledgeHandoverResponse(success = true, status = "ACCEPTED", receivedAmountPaise = 0, discrepancyPaise = 0)
        override suspend fun createReturn(request: com.routeflow.app.core.network.dto.CreateReturnRequest): com.routeflow.app.core.network.dto.CreateReturnResponse =
            com.routeflow.app.core.network.dto.CreateReturnResponse(success = true, returnId = "ret_1")
        override suspend fun getPendingReturns(): com.routeflow.app.core.network.dto.PendingReturnsResponse =
            com.routeflow.app.core.network.dto.PendingReturnsResponse(returns = emptyList())
        override suspend fun inspectReturn(id: String, request: com.routeflow.app.core.network.dto.InspectReturnRequest): com.routeflow.app.core.network.dto.InspectReturnResponse =
            com.routeflow.app.core.network.dto.InspectReturnResponse(success = true, status = "APPROVED", totalCreditNotePaise = 0)
        override suspend fun getClosing(): com.routeflow.app.core.network.dto.ClosingResponse = com.routeflow.app.core.network.dto.ClosingResponse()
        override suspend fun closeDay(request: com.routeflow.app.core.network.dto.ClosingRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun reviewCollection(id: String, request: com.routeflow.app.core.network.dto.CollectionReviewRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun returnAction(id: String, step: String, request: com.routeflow.app.core.network.dto.ReturnActionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun pauseShift(action: String, request: com.routeflow.app.core.network.dto.ShiftPauseRequest, account: String?): com.routeflow.app.core.network.dto.ShiftResponse =
            com.routeflow.app.core.network.dto.ShiftResponse(success = true)
        override suspend fun currentShift(): com.routeflow.app.core.network.dto.ShiftResponse = com.routeflow.app.core.network.dto.ShiftResponse(success = true)
        override suspend fun failDelivery(orderId: String, request: com.routeflow.app.core.network.dto.DeliveryFailureRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getUndeliveredGoods(status: String?): List<com.routeflow.app.core.network.dto.UndeliveredGoodsDto> = emptyList()
        override suspend fun acknowledgeUndeliveredGoods(id: String, request: com.routeflow.app.core.network.dto.AcknowledgeUndeliveredRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getDeliveryExceptions(): List<com.routeflow.app.core.network.dto.DeliveryExceptionDto> = emptyList()
        override suspend fun getDriverHeldStock(): List<com.routeflow.app.core.network.dto.DriverHeldStockDto> = emptyList()
        override suspend fun retryDelivery(id: String, request: com.routeflow.app.core.network.dto.RetryDeliveryRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getOrderItemsBulk(request: com.routeflow.app.core.network.dto.BulkOrderItemsRequest): com.routeflow.app.core.network.dto.BulkOrderItemsResponse =
            com.routeflow.app.core.network.dto.BulkOrderItemsResponse()
        override suspend fun registerOwner(request: com.routeflow.app.core.network.dto.RegisterOwnerRequest): AuthResponse = throw NotImplementedError()
        override suspend fun acceptInvite(request: com.routeflow.app.core.network.dto.AcceptInviteRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun createBatch(request: com.routeflow.app.core.network.dto.CreateBatchRequest): com.routeflow.app.core.network.dto.BatchDto =
            com.routeflow.app.core.network.dto.BatchDto(id = "batch_1", batchNo = request.batchNo, receivedQuantity = request.receivedQuantity)
        override suspend fun getBatchesForProduct(productId: String): com.routeflow.app.core.network.dto.BatchListResponse =
            com.routeflow.app.core.network.dto.BatchListResponse()
        override suspend fun getExpiryAlerts(): com.routeflow.app.core.network.dto.ExpiryAlertsResponse =
            com.routeflow.app.core.network.dto.ExpiryAlertsResponse()
        override suspend fun updateBatch(id: String, request: com.routeflow.app.core.network.dto.UpdateBatchRequest): StatusResponse =
            StatusResponse(success = true)
        override suspend fun updateAlertConfig(request: com.routeflow.app.core.network.dto.AlertConfigRequest): StatusResponse =
            StatusResponse(success = true)
        override suspend fun createTrip(request: com.routeflow.app.core.network.dto.CreateTripRequest): com.routeflow.app.core.network.dto.TripDto =
            com.routeflow.app.core.network.dto.TripDto(id = "trip_1", tripNumber = "TRIP-1001", driverId = request.driverId, vehicleNumber = request.vehicleNumber, routeArea = request.routeArea, status = "CREATED", startTime = System.currentTimeMillis())
        override suspend fun getActiveTrip(): com.routeflow.app.core.network.dto.TripDto? = null
        override suspend fun getAllTrips(): List<com.routeflow.app.core.network.dto.TripDto> = emptyList()
        override suspend fun reorderTripStops(id: String, request: com.routeflow.app.core.network.dto.ReorderStopsRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun startTrip(id: String): StatusResponse = StatusResponse(success = true)
        override suspend fun completeTrip(id: String): StatusResponse = StatusResponse(success = true)
    }
}
