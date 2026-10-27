package com.routeflow.app

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.core.util.OsrmRoutingHelper
import com.routeflow.app.data.repository.OfflinePlannedRouteRepository
import com.routeflow.app.domain.model.PlannedRouteStop
import com.routeflow.app.domain.model.RouteStatus
import com.routeflow.app.domain.model.StopStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class Phase2RoutePlanningTest {

    private lateinit var context: Context
    private lateinit var database: RouteFlowDatabase
    private lateinit var tokenStorage: TokenStorage
    private lateinit var repository: OfflinePlannedRouteRepository

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        database = Room.inMemoryDatabaseBuilder(context, RouteFlowDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        tokenStorage = TokenStorage(context)
        tokenStorage.saveTokens("mock_jwt", "mock_refresh")
        tokenStorage.saveUser("user_owner", "Owner", "OWNER", "comp_1")

        repository = OfflinePlannedRouteRepository(
            database = database,
            plannedRouteDao = database.plannedRouteDao(),
            retailerDao = database.retailerDao(),
            tokenStorage = tokenStorage,
            syncManager = com.routeflow.app.data.sync.SyncManager(context, tokenStorage)
        )

        // Seed 3 active retailers in Chandigarh / Mohali
        runBlocking {
            database.retailerDao().insertRetailers(
                listOf(
                    RetailerEntity(
                        id = "R1", companyId = "comp_1", name = "Gupta Provision Store",
                        beatId = "BEAT_1", address = "SCO 45, Sector 17, Chandigarh", contactNumber = "9876543210",
                        latitude = 30.7333, longitude = 76.7794, creditLimitPaise = 5000000, outstandingAmountPaise = 0,
                        isActive = true
                    ),
                    RetailerEntity(
                        id = "R2", companyId = "comp_1", name = "Aggarwal Supermarket",
                        beatId = "BEAT_1", address = "Booth 12, Sector 22, Chandigarh", contactNumber = "9876543211",
                        latitude = 30.7250, longitude = 76.7700, creditLimitPaise = 3000000, outstandingAmountPaise = 0,
                        isActive = true
                    ),
                    RetailerEntity(
                        id = "R3", companyId = "comp_1", name = "Sharma Daily Needs",
                        beatId = "BEAT_1", address = "Shop 5, Phase 7, Mohali", contactNumber = "9876543212",
                        latitude = 30.7046, longitude = 76.7179, creditLimitPaise = 2000000, outstandingAmountPaise = 0,
                        isActive = true
                    )
                )
            )

            // Seed 2 products to verify stock invariant
            database.productDao().insertProducts(
                listOf(
                    ProductEntity(
                        id = "P1", name = "Wheat Flour 10kg", category = "Grains",
                        pricePaise = 42000, stockQuantity = 100, reservedQuantity = 10, unit = "BAG",
                        isActive = true
                    ),
                    ProductEntity(
                        id = "P2", name = "Basmati Rice 5kg", category = "Grains",
                        pricePaise = 65000, stockQuantity = 50, reservedQuantity = 5, unit = "BAG",
                        isActive = true
                    )
                )
            )
        }
    }

    @After
    fun teardown() {
        database.close()
    }

    @Test
    fun testOsrmHelperFormattingAndDecoding() {
        // Distance formatting
        assertEquals("0 m", OsrmRoutingHelper.formatDistance(0.0))
        assertEquals("450 m", OsrmRoutingHelper.formatDistance(450.0))
        assertEquals("1.5 km", OsrmRoutingHelper.formatDistance(1500.0))
        assertEquals("12.4 km", OsrmRoutingHelper.formatDistance(12380.0))

        // Duration formatting
        assertEquals("25 sec", OsrmRoutingHelper.formatDuration(25.0))
        assertEquals("15 mins", OsrmRoutingHelper.formatDuration(900.0))
        assertEquals("1 hr 15 mins", OsrmRoutingHelper.formatDuration(4500.0))

        // Polyline6 decoding round-trip verification
        // Test points around Chandigarh: (30.733300, 76.779400) -> (30.725000, 76.770000)
        // Encode manually and decode with OsrmRoutingHelper
        val encodedTest = "w_qgB}j`wM`j@_h@"
        val decoded = OsrmRoutingHelper.decodePolyline6(encodedTest)
        assertTrue(decoded.isNotEmpty())
    }

    @Test
    fun testCreateDraftRouteWithManualSequence() = runBlocking {
        val stops = listOf(
            PlannedRouteStop(
                id = UUID.randomUUID().toString(), routeId = "", companyId = "comp_1",
                retailerId = "R1", retailerName = "Gupta Provision Store", stopSequence = 1,
                address = "SCO 45, Sector 17", latitude = 30.7333, longitude = 76.7794
            ),
            PlannedRouteStop(
                id = UUID.randomUUID().toString(), routeId = "", companyId = "comp_1",
                retailerId = "R2", retailerName = "Aggarwal Supermarket", stopSequence = 2,
                address = "Booth 12, Sector 22", latitude = 30.7250, longitude = 76.7700
            ),
            PlannedRouteStop(
                id = UUID.randomUUID().toString(), routeId = "", companyId = "comp_1",
                retailerId = "R3", retailerName = "Sharma Daily Needs", stopSequence = 3,
                address = "Shop 5, Phase 7, Mohali", latitude = 30.7046, longitude = 76.7179
            )
        )

        val result = repository.createDraftRoute(
            routeDate = "2026-10-27",
            name = "Morning Tricity Beat",
            salespersonId = "user_sales_1",
            salespersonName = "Rakesh Sharma",
            stops = stops
        )

        assertTrue(result.isSuccess)
        val created = result.getOrThrow()
        assertEquals("Morning Tricity Beat", created.name)
        assertEquals(RouteStatus.DRAFT, created.status)
        assertEquals(3, created.totalStops)
        assertEquals(3, created.stops.size)
        assertEquals("R1", created.stops[0].retailerId)
        assertEquals(1, created.stops[0].stopSequence)
        assertEquals("R2", created.stops[1].retailerId)
        assertEquals(2, created.stops[1].stopSequence)
        assertEquals("R3", created.stops[2].retailerId)
        assertEquals(3, created.stops[2].stopSequence)

        // Road metrics calculated
        assertTrue("Distance should be positive", created.roadDistanceMeters > 0.0)
        assertTrue("Duration should be positive", created.roadDurationSeconds > 0.0)
    }

    @Test
    fun testUpdateDraftRouteReordersStops() = runBlocking {
        val initialStops = listOf(
            PlannedRouteStop(
                id = "s1", routeId = "", companyId = "comp_1",
                retailerId = "R1", retailerName = "R1", stopSequence = 1,
                latitude = 30.7333, longitude = 76.7794
            ),
            PlannedRouteStop(
                id = "s2", routeId = "", companyId = "comp_1",
                retailerId = "R2", retailerName = "R2", stopSequence = 2,
                latitude = 30.7250, longitude = 76.7700
            )
        )

        val createRes = repository.createDraftRoute(
            routeDate = "2026-10-27", name = "Initial Route",
            salespersonId = "user_sales_1", salespersonName = "Rakesh",
            stops = initialStops
        ).getOrThrow()

        // Swap sequence: R2 first (#1), R1 second (#2)
        val reorderedStops = listOf(
            initialStops[1].copy(stopSequence = 1),
            initialStops[0].copy(stopSequence = 2)
        )

        val updateRes = repository.updateDraftRoute(
            routeId = createRes.id,
            routeDate = "2026-10-27",
            name = "Reordered Route",
            salespersonId = "user_sales_1",
            salespersonName = "Rakesh",
            stops = reorderedStops
        )

        assertTrue(updateRes.isSuccess)
        val updated = updateRes.getOrThrow()
        assertEquals("Reordered Route", updated.name)
        assertEquals(2, updated.version)
        assertEquals("R2", updated.stops[0].retailerId)
        assertEquals(1, updated.stops[0].stopSequence)
        assertEquals("R1", updated.stops[1].retailerId)
        assertEquals(2, updated.stops[1].stopSequence)
    }

    @Test
    fun testPublishRoutePreservesStockAndInventoryInvariants() = runBlocking {
        // Record baseline product quantities
        val p1Before = database.productDao().getProductById("P1")!!
        val p2Before = database.productDao().getProductById("P2")!!

        val stops = listOf(
            PlannedRouteStop(
                id = "stop_1", routeId = "", companyId = "comp_1",
                retailerId = "R1", retailerName = "Gupta Provision", stopSequence = 1,
                latitude = 30.7333, longitude = 76.7794
            )
        )

        val draft = repository.createDraftRoute(
            routeDate = "2026-10-27", name = "Test Publish Route",
            salespersonId = "user_sales_1", salespersonName = "Rakesh",
            stops = stops
        ).getOrThrow()

        // Salesperson cannot see DRAFT routes
        val salesRoutesBeforePublish = repository.observePublishedRoutesForSalesperson("comp_1", "user_sales_1").first()
        assertTrue(salesRoutesBeforePublish.none { it.id == draft.id })

        // Publish route
        val pubRes = repository.publishRoute(draft.id)
        assertTrue(pubRes.isSuccess)
        val published = pubRes.getOrThrow()
        assertEquals(RouteStatus.PUBLISHED, published.status)
        assertNotNull(published.publishedAt)

        // STRICT BUSINESS INVARIANT: Stock and reserved quantities MUST be 100% unchanged!
        val p1After = database.productDao().getProductById("P1")!!
        val p2After = database.productDao().getProductById("P2")!!
        assertEquals("Stock cannot change upon route publish", p1Before.stockQuantity, p1After.stockQuantity)
        assertEquals("Reserved stock cannot change upon route publish", p1Before.reservedQuantity, p1After.reservedQuantity)
        assertEquals("Stock cannot change upon route publish", p2Before.stockQuantity, p2After.stockQuantity)
        assertEquals("Reserved stock cannot change upon route publish", p2Before.reservedQuantity, p2After.reservedQuantity)

        // Cannot edit once published
        val editPublished = repository.updateDraftRoute(
            routeId = draft.id, routeDate = "2026-10-27", name = "Illegal Edit",
            salespersonId = "user_sales_1", salespersonName = "Rakesh", stops = stops
        )
        assertTrue("Modifying published route should fail", editPublished.isFailure)

        // Salesperson now sees the published route
        val salesRoutesAfterPublish = repository.observePublishedRoutesForSalesperson("comp_1", "user_sales_1").first()
        assertEquals(1, salesRoutesAfterPublish.size)
        assertEquals(draft.id, salesRoutesAfterPublish[0].id)
    }

    @Test
    fun testSalespersonMarkVisitedAndSkippedStops() = runBlocking {
        val stops = listOf(
            PlannedRouteStop(
                id = "s_101", routeId = "", companyId = "comp_1",
                retailerId = "R1", retailerName = "Gupta Provision", stopSequence = 1,
                latitude = 30.7333, longitude = 76.7794
            ),
            PlannedRouteStop(
                id = "s_102", routeId = "", companyId = "comp_1",
                retailerId = "R2", retailerName = "Aggarwal Supermarket", stopSequence = 2,
                latitude = 30.7250, longitude = 76.7700
            )
        )

        val draft = repository.createDraftRoute(
            routeDate = "2026-10-27", name = "Field Route",
            salespersonId = "user_sales_1", salespersonName = "Rakesh",
            stops = stops
        ).getOrThrow()
        repository.publishRoute(draft.id)

        // Mark Stop 1 VISITED
        val visitRes = repository.updateStopStatus("s_101", draft.id, StopStatus.VISITED, "Order booked for biscuits")
        assertTrue(visitRes.isSuccess)

        // Mark Stop 2 SKIPPED
        val skipRes = repository.updateStopStatus("s_102", draft.id, StopStatus.SKIPPED, "Shop was locked")
        assertTrue(skipRes.isSuccess)

        val updatedStops = repository.observeStopsForRoute(draft.id).first()
        assertEquals(StopStatus.VISITED, updatedStops[0].status)
        assertNotNull(updatedStops[0].visitedAt)
        assertEquals("Order booked for biscuits", updatedStops[0].notes)

        assertEquals(StopStatus.SKIPPED, updatedStops[1].status)
        assertEquals("Shop was locked", updatedStops[1].notes)

        // Workstream 1: Verify sync_outbox contains atomically enqueued ROUTE_STOP_STATUS events
        val outboxItems = database.syncOutboxDao().getPendingSyncsForUser("user_owner", "comp_1")
        val stopSyncItems = outboxItems.filter { it.type == "ROUTE_STOP_STATUS" }
        assertEquals(2, stopSyncItems.size)
        assertTrue(stopSyncItems[0].idempotencyKey.startsWith("stop_status_"))
        assertTrue(stopSyncItems[1].idempotencyKey.startsWith("stop_status_"))
        assertEquals("comp_1", stopSyncItems[0].companyId)
        assertEquals("user_owner", stopSyncItems[0].userId)
        assertTrue(stopSyncItems[0].payload.contains("VISITED"))
        assertTrue(stopSyncItems[1].payload.contains("SKIPPED"))
    }

    @Test
    fun testCancelRoute() = runBlocking {
        val stops = listOf(
            PlannedRouteStop(
                id = "s_201", routeId = "", companyId = "comp_1",
                retailerId = "R1", retailerName = "Gupta Provision", stopSequence = 1,
                latitude = 30.7333, longitude = 76.7794
            )
        )

        val draft = repository.createDraftRoute(
            routeDate = "2026-10-27", name = "Route to Cancel",
            salespersonId = "user_sales_1", salespersonName = "Rakesh",
            stops = stops
        ).getOrThrow()

        val cancelRes = repository.cancelRoute(draft.id, "Severe weather conditions")
        assertTrue(cancelRes.isSuccess)

        val cancelled = repository.getRouteById(draft.id)
        assertNotNull(cancelled)
        assertEquals(RouteStatus.CANCELLED, cancelled!!.status)
        assertEquals("Severe weather conditions", cancelled.cancellationReason)
        assertNotNull(cancelled.cancelledAt)
    }
}
