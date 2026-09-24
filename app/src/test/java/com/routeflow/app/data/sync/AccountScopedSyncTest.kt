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

        override suspend fun submitOrder(request: OrderSubmitRequest): OrderSubmitResponse {
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
        override suspend fun packOrder(orderId: String): StatusResponse = StatusResponse(success = true)
        override suspend fun dispatchOrder(orderId: String, request: DispatchOrderRequest): StatusResponse = StatusResponse(success = true)
        override suspend fun completeDelivery(orderId: String, request: DeliveryCompletionRequest): StatusResponse = StatusResponse(success = true)
    }
}
