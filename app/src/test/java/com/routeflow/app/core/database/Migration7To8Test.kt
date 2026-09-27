package com.routeflow.app.core.database

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.routeflow.app.core.database.dao.FieldRecordDao
import com.routeflow.app.core.database.entity.FieldRecordEntity
import com.routeflow.app.core.database.entity.LocalShiftEntity
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlinx.coroutines.flow.first
import java.io.File

@RunWith(RobolectricTestRunner::class)
class Migration7To8Test {

    private lateinit var context: Context
    private lateinit var dbFile: File

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        dbFile = context.getDatabasePath("test_migration_7_8.db")
        if (dbFile.exists()) dbFile.delete()
    }

    @After
    fun tearDown() {
        if (dbFile.exists()) dbFile.delete()
    }

    @Test
    fun testMigration7To8_preservesExistingData_andAppliesSchemaChanges() = kotlinx.coroutines.runBlocking {
        // Step 1: Create a representative Version 7 Database
        val helperConfig = androidx.sqlite.db.SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(dbFile.name)
            .callback(object : androidx.sqlite.db.SupportSQLiteOpenHelper.Callback(7) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    // Create tables as they existed in version 7 (exact createSql from 7.json)
                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `retailers` (
                            `id` TEXT NOT NULL,
                            `name` TEXT NOT NULL,
                            `beatId` TEXT NOT NULL,
                            `address` TEXT NOT NULL,
                            `contactNumber` TEXT NOT NULL,
                            `latitude` REAL NOT NULL,
                            `longitude` REAL NOT NULL,
                            `creditLimitPaise` INTEGER NOT NULL,
                            `outstandingAmountPaise` INTEGER NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `products` (
                            `id` TEXT NOT NULL,
                            `name` TEXT NOT NULL,
                            `category` TEXT NOT NULL,
                            `pricePaise` INTEGER NOT NULL,
                            `stockQuantity` INTEGER NOT NULL,
                            `reservedQuantity` INTEGER NOT NULL,
                            `unit` TEXT NOT NULL,
                            `imageUrl` TEXT,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `visits` (
                            `id` TEXT NOT NULL,
                            `retailerId` TEXT NOT NULL,
                            `employeeId` TEXT NOT NULL,
                            `checkInTime` INTEGER NOT NULL,
                            `checkOutTime` INTEGER,
                            `latitude` REAL,
                            `longitude` REAL,
                            `accuracy` REAL,
                            `status` TEXT NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `orders` (
                            `id` TEXT NOT NULL,
                            `retailerId` TEXT NOT NULL,
                            `employeeId` TEXT NOT NULL,
                            `status` TEXT NOT NULL,
                            `totalAmountPaise` INTEGER NOT NULL,
                            `createdAt` INTEGER NOT NULL,
                            `updatedAt` INTEGER NOT NULL,
                            `rejectionReason` TEXT,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `order_items` (
                            `id` TEXT NOT NULL,
                            `orderId` TEXT NOT NULL,
                            `productId` TEXT NOT NULL,
                            `quantity` INTEGER NOT NULL,
                            `freeQuantity` INTEGER NOT NULL,
                            `pricePaiseAtTime` INTEGER NOT NULL,
                            `isPicked` INTEGER NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `payments` (
                            `id` TEXT NOT NULL,
                            `orderId` TEXT NOT NULL,
                            `retailerId` TEXT NOT NULL,
                            `amountPaise` INTEGER NOT NULL,
                            `method` TEXT NOT NULL,
                            `timestamp` INTEGER NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `delivery_records` (
                            `id` TEXT NOT NULL,
                            `orderId` TEXT NOT NULL,
                            `deliveryCode` TEXT NOT NULL,
                            `deliveredAt` INTEGER,
                            `recipientName` TEXT,
                            `status` TEXT NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `targets` (
                            `employeeId` TEXT NOT NULL,
                            `monthlyTargetPaise` INTEGER NOT NULL,
                            `currentAchievedPaise` INTEGER NOT NULL,
                            `incentiveRule` TEXT NOT NULL,
                            PRIMARY KEY(`employeeId`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `sync_outbox` (
                            `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                            `type` TEXT NOT NULL,
                            `payload` TEXT NOT NULL,
                            `idempotencyKey` TEXT NOT NULL,
                            `userId` TEXT NOT NULL,
                            `companyId` TEXT NOT NULL,
                            `createdAt` INTEGER NOT NULL,
                            `retryCount` INTEGER NOT NULL,
                            `lastError` TEXT
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `shift_locations_outbox` (
                            `id` TEXT NOT NULL,
                            `shiftId` TEXT NOT NULL,
                            `userId` TEXT NOT NULL,
                            `companyId` TEXT NOT NULL,
                            `latitude` REAL NOT NULL,
                            `longitude` REAL NOT NULL,
                            `accuracy` REAL NOT NULL,
                            `timestamp` INTEGER NOT NULL,
                            `isSynced` INTEGER NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())

                    db.execSQL("""
                        CREATE TABLE IF NOT EXISTS `collection_records` (
                            `id` TEXT NOT NULL,
                            `receiptId` TEXT NOT NULL,
                            `retailerId` TEXT NOT NULL,
                            `retailerName` TEXT NOT NULL,
                            `amountPaise` INTEGER NOT NULL,
                            `paymentMethod` TEXT NOT NULL,
                            `notes` TEXT,
                            `collectedBy` TEXT NOT NULL,
                            `companyId` TEXT NOT NULL,
                            `timestamp` INTEGER NOT NULL,
                            `isSynced` INTEGER NOT NULL,
                            PRIMARY KEY(`id`)
                        )
                    """.trimIndent())
                }

                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {}
            })
            .build()

        val openHelper = FrameworkSQLiteOpenHelperFactory().create(helperConfig)
        val v7Db = openHelper.writableDatabase

        // Insert representative version 7 rows
        v7Db.execSQL("INSERT INTO orders (id, retailerId, employeeId, status, totalAmountPaise, createdAt, updatedAt) VALUES ('ord_101', 'ret_1', 'user_sales', 'SUBMITTED', 45000, 1000, 1000)")
        v7Db.execSQL("INSERT INTO order_items (id, orderId, productId, quantity, freeQuantity, pricePaiseAtTime, isPicked) VALUES ('item_101', 'ord_101', 'prod_1', 2, 0, 22500, 0)")
        v7Db.execSQL("INSERT INTO visits (id, retailerId, employeeId, checkInTime, checkOutTime, latitude, longitude, accuracy, status) VALUES ('vis_101', 'ret_1', 'user_sales', 2000, 2900, 26.85, 75.76, 10.0, 'COMPLETED')")
        v7Db.execSQL("INSERT INTO sync_outbox (id, type, payload, idempotencyKey, createdAt, retryCount, lastError, userId, companyId) VALUES (1, 'ORDER_SUBMISSION', '{\"orderId\":\"ord_101\"}', 'idemp_ord_101', 3000, 0, NULL, 'user_sales', 'comp_1')")
        v7Db.execSQL("INSERT INTO collection_records (id, receiptId, retailerId, retailerName, amountPaise, paymentMethod, notes, collectedBy, companyId, timestamp, isSynced) VALUES ('col_101', 'REC-001', 'ret_1', 'Retailer One', 50000, 'CASH', 'Morning payment', 'user_sales', 'comp_1', 4000, 0)")

        v7Db.close()

        // Step 2: Open with Room using RouteFlowDatabase and MIGRATION_7_8
        val roomDb = Room.databaseBuilder(context, RouteFlowDatabase::class.java, dbFile.name)
            .addMigrations(
                RouteFlowDatabase.MIGRATION_4_5,
                RouteFlowDatabase.MIGRATION_5_6,
                RouteFlowDatabase.MIGRATION_6_7,
                RouteFlowDatabase.MIGRATION_7_8
            )
            .allowMainThreadQueries()
            .build()

        // Room will validate schema at version 8
        val openDb = roomDb.openHelper.writableDatabase
        assertEquals(8, openDb.version)

        // Step 3: Verify existing data survived and migrated columns have expected defaults
        // A. Orders & Order Items
        val order = roomDb.orderDao().getOrderById("ord_101").first()
        assertNotNull(order)
        assertEquals("ret_1", order?.retailerId)
        assertEquals(45000L, order?.totalAmountPaise)

        // B. Visits: check existing row has default companyId='' and nullable notes/noOrderReason
        val visitCursor = openDb.query("SELECT id, companyId, notes, noOrderReason FROM visits WHERE id='vis_101'")
        assertTrue(visitCursor.moveToFirst())
        assertEquals("vis_101", visitCursor.getString(0))
        assertEquals("", visitCursor.getString(1)) // default ''
        assertNull(visitCursor.getString(2)) // null
        assertNull(visitCursor.getString(3)) // null
        visitCursor.close()

        // C. Sync Outbox: check syncState defaulted to 'SAVED_OFFLINE'
        val outboxCursor = openDb.query("SELECT id, syncState, idempotencyKey FROM sync_outbox WHERE id=1")
        assertTrue(outboxCursor.moveToFirst())
        assertEquals("SAVED_OFFLINE", outboxCursor.getString(1))
        assertEquals("idemp_ord_101", outboxCursor.getString(2))
        outboxCursor.close()

        // D. Collection Records: check paymentState defaulted to 'ENTERED' and serverId is null
        val colCursor = openDb.query("SELECT id, paymentState, serverId, receiptId FROM collection_records WHERE id='col_101'")
        assertTrue(colCursor.moveToFirst())
        assertEquals("col_101", colCursor.getString(0))
        assertEquals("ENTERED", colCursor.getString(1))
        assertNull(colCursor.getString(2))
        assertEquals("REC-001", colCursor.getString(3))
        colCursor.close()

        // E. New tables: local_shifts and field_records exist and functional
        val fieldDao: FieldRecordDao = roomDb.fieldRecordDao()
        val shift = LocalShiftEntity(
            id = "shift_mig_1",
            userId = "user_sales",
            companyId = "comp_1",
            status = "ON_SHIFT",
            startTime = 5000L,
            endTime = null
        )
        fieldDao.saveShift(shift)
        val loadedShift = fieldDao.getShift("shift_mig_1")
        assertNotNull(loadedShift)
        assertEquals("ON_SHIFT", loadedShift?.status)

        val record = FieldRecordEntity(
            id = "rec_1",
            userId = "user_sales",
            companyId = "comp_1",
            kind = "CHECK_IN",
            payload = "{\"retailerId\":\"ret_1\"}",
            createdAt = 6000L
        )
        fieldDao.saveRecord(record)

        roomDb.close()
    }
}
