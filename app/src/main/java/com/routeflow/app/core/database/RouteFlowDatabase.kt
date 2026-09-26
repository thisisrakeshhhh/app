package com.routeflow.app.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.PaymentDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.core.database.dao.SyncOutboxDao
import com.routeflow.app.core.database.dao.CollectionRecordDao
import com.routeflow.app.core.database.dao.ShiftLocationDao
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.core.database.entity.DeliveryRecordEntity
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.PaymentEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.database.entity.ShiftLocationEntity
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.database.entity.TargetEntity
import com.routeflow.app.core.database.entity.VisitEntity

@Database(
    entities = [
        RetailerEntity::class,
        ProductEntity::class,
        VisitEntity::class,
        OrderEntity::class,
        OrderItemEntity::class,
        PaymentEntity::class,
        DeliveryRecordEntity::class,
        TargetEntity::class,
        SyncOutboxEntity::class,
        ShiftLocationEntity::class,
        com.routeflow.app.core.database.entity.LocalShiftEntity::class,
        com.routeflow.app.core.database.entity.FieldRecordEntity::class,
        CollectionRecordEntity::class
    ],
    version = 8,
    exportSchema = true
)
abstract class RouteFlowDatabase : RoomDatabase() {
    abstract fun retailerDao(): RetailerDao
    abstract fun productDao(): ProductDao
    abstract fun orderDao(): OrderDao
    abstract fun visitDao(): VisitDao
    abstract fun paymentDao(): PaymentDao
    abstract fun syncOutboxDao(): SyncOutboxDao
    abstract fun shiftLocationDao(): ShiftLocationDao
    abstract fun collectionRecordDao(): CollectionRecordDao

    abstract fun fieldRecordDao(): com.routeflow.app.core.database.dao.FieldRecordDao

    companion object {
        const val DATABASE_NAME = "routeflow_db"

        val MIGRATION_7_8 = object : Migration(7, 8) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE visits ADD COLUMN companyId TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE visits ADD COLUMN notes TEXT")
                db.execSQL("ALTER TABLE visits ADD COLUMN noOrderReason TEXT")
                db.execSQL("ALTER TABLE sync_outbox ADD COLUMN syncState TEXT NOT NULL DEFAULT 'SAVED_OFFLINE'")
                db.execSQL("ALTER TABLE collection_records ADD COLUMN paymentState TEXT NOT NULL DEFAULT 'ENTERED'")
                db.execSQL("ALTER TABLE collection_records ADD COLUMN serverId TEXT")
                db.execSQL("CREATE TABLE IF NOT EXISTS local_shifts (id TEXT NOT NULL PRIMARY KEY, userId TEXT NOT NULL, companyId TEXT NOT NULL, status TEXT NOT NULL, startTime INTEGER NOT NULL, endTime INTEGER)")
                db.execSQL("CREATE TABLE IF NOT EXISTS field_records (id TEXT NOT NULL PRIMARY KEY, userId TEXT NOT NULL, companyId TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, createdAt INTEGER NOT NULL)")
            }
        }

        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `sync_outbox` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
                        `type` TEXT NOT NULL, 
                        `payload` TEXT NOT NULL, 
                        `idempotencyKey` TEXT NOT NULL, 
                        `createdAt` INTEGER NOT NULL, 
                        `retryCount` INTEGER NOT NULL, 
                        `lastError` TEXT
                    )
                """.trimIndent())
            }
        }

        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `sync_outbox` ADD COLUMN `userId` TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE `sync_outbox` ADD COLUMN `companyId` TEXT NOT NULL DEFAULT ''")
            }
        }

        val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `shift_locations_outbox` (
                        `id` TEXT PRIMARY KEY NOT NULL,
                        `shiftId` TEXT NOT NULL,
                        `userId` TEXT NOT NULL,
                        `companyId` TEXT NOT NULL,
                        `latitude` REAL NOT NULL,
                        `longitude` REAL NOT NULL,
                        `accuracy` REAL NOT NULL,
                        `timestamp` INTEGER NOT NULL,
                        `isSynced` INTEGER NOT NULL DEFAULT 0
                    )
                """.trimIndent())
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `collection_records` (
                        `id` TEXT PRIMARY KEY NOT NULL,
                        `receiptId` TEXT NOT NULL,
                        `retailerId` TEXT NOT NULL,
                        `retailerName` TEXT NOT NULL,
                        `amountPaise` INTEGER NOT NULL,
                        `paymentMethod` TEXT NOT NULL,
                        `notes` TEXT,
                        `collectedBy` TEXT NOT NULL,
                        `companyId` TEXT NOT NULL,
                        `timestamp` INTEGER NOT NULL,
                        `isSynced` INTEGER NOT NULL DEFAULT 0
                    )
                """.trimIndent())
            }
        }
    }
}
