package com.routeflow.app.data.sync

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.work.ListenableWorker
import androidx.work.WorkerParameters
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.workDataOf
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.ShiftLocationEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
class OfflineEventDependenciesTest {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var tokenStorage: TestTokenStorage
    private lateinit var fakeApi: TestRouteFlowApi
    private val json = Json { ignoreUnknownKeys = true }

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tokenStorage = TestTokenStorage(context)
        fakeApi = TestRouteFlowApi()
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
            .setWorkerFactory(object : androidx.work.WorkerFactory() {
                override fun createWorker(
                    appContext: Context,
                    workerClassName: String,
                    workerParameters: WorkerParameters
                ): ListenableWorker {
                    return OrderSyncWorker(appContext, workerParameters, fakeApi, database, tokenStorage, json)
                }
            })
            .build()
    }

    @Test
    fun testCheckoutCannotBeApplied_whenCheckInFails_dependentRemainsPending() = runBlocking {
        tokenStorage.saveUser("user_sales_1", "Sales 1", "SALESPERSON", "comp_1")

        val visitId = "vis_dep_01"
        val startVisit = VisitDto(
            id = visitId,
            retailerId = "R1",
            checkInTime = 1000L,
            latitude = 26.85,
            longitude = 75.76,
            accuracy = 10.0f,
            status = "ACTIVE"
        )
        val endVisit = VisitCheckoutEvent(
            visitId = visitId,
            request = CheckoutVisitRequest(checkOutTime = 2000L, durationSeconds = 1000, notes = "Completed visit")
        )

        // Queue VISIT_START (id=1, createdAt=100) and dependent VISIT_END (id=2, createdAt=200)
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 1,
                type = "VISIT_START",
                payload = json.encodeToString(startVisit),
                idempotencyKey = "vis_start_$visitId",
                userId = "user_sales_1",
                companyId = "comp_1",
                createdAt = 100L
            )
        )
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 2,
                type = "VISIT_END",
                payload = json.encodeToString(endVisit),
                idempotencyKey = "vis_end_$visitId",
                userId = "user_sales_1",
                companyId = "comp_1",
                createdAt = 200L
            )
        )

        // Simulate network failure on VISIT_START
        fakeApi.visitStartHandler = { throw IOException("Connection lost to server") }

        val worker = createWorker("user_sales_1", "comp_1")
        val result = worker.doWork()

        // 1. Worker returns retry
        assertEquals(ListenableWorker.Result.retry(), result)

        // 2. Checkout was NEVER called because check-in failed first
        assertEquals(0, fakeApi.checkoutCalls.size)

        // 3. Both events remain pending in outbox in order
        val pending = database.syncOutboxDao().getPendingSyncsForUser("user_sales_1", "comp_1")
        assertEquals(2, pending.size)
        assertEquals("VISIT_START", pending[0].type)
        assertEquals("SAVED_OFFLINE", pending[0].syncState)
        assertEquals("CONNECTION_RETRY", pending[0].lastError)
        assertEquals(1, pending[0].retryCount)
        assertEquals("VISIT_END", pending[1].type)

        // Now simulate connection restored: VISIT_START succeeds
        fakeApi.visitStartHandler = { StatusResponse(success = true) }

        val workerSuccess = createWorker("user_sales_1", "comp_1")
        val resultSuccess = workerSuccess.doWork()

        // 4. Worker now processes both in sequence
        assertEquals(ListenableWorker.Result.success(), resultSuccess)
        assertEquals(2, fakeApi.visitStartCalls.size) // 1 initial attempt + 1 retry attempt
        assertEquals(1, fakeApi.checkoutCalls.size)
        assertEquals(visitId, fakeApi.checkoutCalls.first().first)

        // 5. Outbox is now empty
        assertEquals(0, database.syncOutboxDao().getPendingSyncsForUser("user_sales_1", "comp_1").size)
    }

    @Test
    fun testPermanentFailure_setsNeedsAttention_andActionableReason() = runBlocking {
        tokenStorage.saveUser("user_sales_1", "Sales 1", "SALESPERSON", "comp_1")

        val visitId = "vis_perm_01"
        val startVisit = VisitDto(id = visitId, retailerId = "R1", checkInTime = 1000L)

        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 1,
                type = "VISIT_START",
                payload = json.encodeToString(startVisit),
                idempotencyKey = "vis_perm_$visitId",
                userId = "user_sales_1",
                companyId = "comp_1",
                createdAt = 100L
            )
        )

        // Simulate 409 Conflict (e.g. active visit constraint or business rule rejection)
        val errorBody = "{\"error\":\"Active visit conflict\"}".toResponseBody("application/json".toMediaType())
        fakeApi.visitStartHandler = { throw HttpException(Response.error<StatusResponse>(409, errorBody)) }

        val worker = createWorker("user_sales_1", "comp_1")
        val result = worker.doWork()

        // Returns failure (not retry)
        assertEquals(ListenableWorker.Result.failure(), result)

        val pending = database.syncOutboxDao().getPendingSyncsForUser("user_sales_1", "comp_1")
        assertEquals(1, pending.size)
        assertEquals("NEEDS_ATTENTION", pending[0].syncState)
        assertEquals("VALIDATION_REVIEW", pending[0].lastError)
    }

    @Test
    fun testLocationUploads_retainUserCompanyShift_andAreScoped() = runBlocking {
        tokenStorage.saveUser("user_del_1", "Delivery 1", "DELIVERY_EXECUTIVE", "comp_1")

        // Add 2 GPS points for user_del_1 in comp_1
        database.shiftLocationDao().insertLocation(
            ShiftLocationEntity(
                id = "loc_01",
                shiftId = "shift_100",
                userId = "user_del_1",
                companyId = "comp_1",
                latitude = 26.85,
                longitude = 75.76,
                accuracy = 5.0f,
                timestamp = 1000L,
                isSynced = false
            )
        )
        database.shiftLocationDao().insertLocation(
            ShiftLocationEntity(
                id = "loc_02",
                shiftId = "shift_100",
                userId = "user_del_1",
                companyId = "comp_1",
                latitude = 26.86,
                longitude = 75.77,
                accuracy = 8.0f,
                timestamp = 1500L,
                isSynced = false
            )
        )

        // Add another point for a different user in comp_2
        database.shiftLocationDao().insertLocation(
            ShiftLocationEntity(
                id = "loc_other",
                shiftId = "shift_999",
                userId = "user_other",
                companyId = "comp_2",
                latitude = 28.50,
                longitude = 77.20,
                accuracy = 10.0f,
                timestamp = 2000L,
                isSynced = false
            )
        )

        val worker = createWorker("user_del_1", "comp_1")
        val result = worker.doWork()
        assertEquals(ListenableWorker.Result.success(), result)

        // Verify API was called with user_del_1's shift points ONLY
        assertEquals(1, fakeApi.locationUploadCalls.size)
        val uploadReq = fakeApi.locationUploadCalls.first()
        assertEquals("shift_100", uploadReq.shiftId)
        assertEquals(2, uploadReq.points.size)
        assertEquals("loc_01", uploadReq.points[0].id)
        assertEquals("loc_02", uploadReq.points[1].id)

        // Verify points marked synced in DB for user_del_1
        val pendingLocs = database.shiftLocationDao().getPendingForAccount("user_del_1", "comp_1")
        assertEquals(0, pendingLocs.size)

        // comp_2 point remains untouched and unsynced
        val comp2Pending = database.shiftLocationDao().getPendingForAccount("user_other", "comp_2")
        assertEquals(1, comp2Pending.size)
    }

    @Test
    fun testAccountSwitching_doesNotSubmitAnotherAccountEvents() = runBlocking {
        // User A logs in and has a pending collection
        tokenStorage.saveUser("user_A", "User A", "SALESPERSON", "comp_A")

        val colReqA = RecordCollectionRequest(
            retailerId = "R_A",
            amountPaise = 50000L,
            paymentMethod = "CASH",
            receiptId = "REC-A-1",
            idempotencyKey = "col_idemp_A"
        )
        database.syncOutboxDao().insertSyncItem(
            SyncOutboxEntity(
                id = 1,
                type = "COLLECTION_RECORD",
                payload = json.encodeToString(colReqA),
                idempotencyKey = "col_idemp_A",
                userId = "user_A",
                companyId = "comp_A"
            )
        )

        // Switch active user in TokenStorage to User B
        tokenStorage.saveUser("user_B", "User B", "SALESPERSON", "comp_B")

        // Run worker targeted for User B
        val workerB = createWorker("user_B", "comp_B")
        val resultB = workerB.doWork()
        assertEquals(ListenableWorker.Result.success(), resultB)

        // User A's collection must NOT have been called
        assertEquals(0, fakeApi.collectionCalls.size)

        // User A's outbox item is still intact
        val pendingA = database.syncOutboxDao().getPendingSyncsForUser("user_A", "comp_A")
        assertEquals(1, pendingA.size)
    }

    // Helper fake API
    class TestRouteFlowApi : RouteFlowApi {
        var visitStartHandler: (suspend () -> StatusResponse)? = null
        val visitStartCalls = mutableListOf<VisitDto>()
        val checkoutCalls = mutableListOf<Pair<String, CheckoutVisitRequest>>()
        val locationUploadCalls = mutableListOf<ShiftLocationsRequest>()
        val collectionCalls = mutableListOf<RecordCollectionRequest>()

        override suspend fun submitVisit(request: VisitDto, account: String?): StatusResponse {
            visitStartCalls.add(request)
            visitStartHandler?.invoke()?.let { return it }
            return StatusResponse(success = true)
        }

        override suspend fun checkoutVisit(visitId: String, request: CheckoutVisitRequest, account: String?): StatusResponse {
            checkoutCalls.add(visitId to request)
            return StatusResponse(success = true)
        }

        override suspend fun uploadShiftLocations(request: ShiftLocationsRequest, account: String?): StatusResponse {
            locationUploadCalls.add(request)
            return StatusResponse(success = true)
        }

        override suspend fun recordCollection(request: RecordCollectionRequest, account: String?): RecordCollectionResponse {
            collectionCalls.add(request)
            return RecordCollectionResponse(success = true, collectionId = "col_1", receiptId = request.receiptId, status = "SETTLED", balanceAfterPaise = 0)
        }

        override suspend fun submitOrder(request: OrderSubmitRequest, account: String?): OrderSubmitResponse = OrderSubmitResponse(success = true, orderId = request.order.id)
        override suspend fun submitStockCheck(request: StockCheckDto, account: String?): StatusResponse = StatusResponse(success = true)
        override suspend fun startShift(request: StartShiftRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun endShift(request: EndShiftRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun pauseShift(action: String, request: ShiftPauseRequest, account: String?): ShiftResponse = ShiftResponse(success = true)
        override suspend fun submitHandoverRequest(request: SubmitHandoverRequest, account: String?): SubmitHandoverResponse = SubmitHandoverResponse(success = true, handoverId = "hnd_1", status = "PENDING")

        // Unused stubs
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
        override suspend fun getVisits(): List<VisitDto> = emptyList()
        override suspend fun getBeats(): List<BeatDto> = emptyList()
        override suspend fun createBeat(request: CreateBeatRequest): CreateBeatResponse = CreateBeatResponse(success = true)
        override suspend fun assignBeat(beatId: String, request: AssignBeatRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getTeamStatus(): List<TeamMemberStatusDto> = emptyList()
        override suspend fun getDailyVisits(date: String?): List<DailyVisitDto> = emptyList()
        override suspend fun getCollections(retailerId: String?): CollectionsListResponse = CollectionsListResponse(collections = emptyList())
        override suspend fun getHandoverSummary(): CashHandoverSummaryResponse = CashHandoverSummaryResponse(cashHeldPaise = 0, totalCollectedPaise = 0, totalSettledPaise = 0)
        override suspend fun getOwnerHandovers(): OwnerHandoversResponse = OwnerHandoversResponse(handovers = emptyList())
        override suspend fun acknowledgeHandover(id: String, request: AcknowledgeHandoverRequest): AcknowledgeHandoverResponse = AcknowledgeHandoverResponse(success = true, status = "ACCEPTED", receivedAmountPaise = 0, discrepancyPaise = 0)
        override suspend fun createReturn(request: CreateReturnRequest): CreateReturnResponse = CreateReturnResponse(success = true, returnId = "ret_1")
        override suspend fun getPendingReturns(): PendingReturnsResponse = PendingReturnsResponse(returns = emptyList())
        override suspend fun inspectReturn(id: String, request: InspectReturnRequest): InspectReturnResponse = InspectReturnResponse(success = true, status = "APPROVED", totalCreditNotePaise = 0)
        override suspend fun getClosing(): com.routeflow.app.core.network.dto.ClosingResponse = com.routeflow.app.core.network.dto.ClosingResponse()
        override suspend fun closeDay(request: com.routeflow.app.core.network.dto.ClosingRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun reviewCollection(id: String, request: com.routeflow.app.core.network.dto.CollectionReviewRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun returnAction(id: String, step: String, request: com.routeflow.app.core.network.dto.ReturnActionRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun currentShift(): com.routeflow.app.core.network.dto.ShiftResponse = com.routeflow.app.core.network.dto.ShiftResponse(success = true)
        override suspend fun failDelivery(orderId: String, request: com.routeflow.app.core.network.dto.DeliveryFailureRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getUndeliveredGoods(status: String?): List<com.routeflow.app.core.network.dto.UndeliveredGoodsDto> = emptyList()
        override suspend fun acknowledgeUndeliveredGoods(id: String, request: com.routeflow.app.core.network.dto.AcknowledgeUndeliveredRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun getDeliveryExceptions(): List<com.routeflow.app.core.network.dto.DeliveryExceptionDto> = emptyList()
        override suspend fun getDriverHeldStock(): List<com.routeflow.app.core.network.dto.DriverHeldStockDto> = emptyList()
    }

    // Helper fake TokenStorage
    class TestTokenStorage(context: Context) : TokenStorage(context) {
        private var userId: String? = null
        private var companyId: String? = null
        private var userRole: String? = null
        private var userName: String? = null

        override fun saveUser(id: String, name: String, role: String, companyId: String) {
            this.userId = id
            this.userName = name
            this.userRole = role
            this.companyId = companyId
        }
        override fun getUserId(): String? = userId
        override fun getCompanyId(): String? = companyId
        override fun getUserRole(): String? = userRole
        override fun getUserName(): String? = userName
    }
}
