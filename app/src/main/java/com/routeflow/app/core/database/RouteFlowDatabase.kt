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
import com.routeflow.app.core.database.entity.DeliveryRecordEntity
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.PaymentEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
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
        SyncOutboxEntity::class
    ],
    version = 6,
    exportSchema = true
)
abstract class RouteFlowDatabase : RoomDatabase() {
    abstract fun retailerDao(): RetailerDao
    abstract fun productDao(): ProductDao
    abstract fun orderDao(): OrderDao
    abstract fun visitDao(): VisitDao
    abstract fun paymentDao(): PaymentDao
    abstract fun syncOutboxDao(): SyncOutboxDao

    companion object {
        const val DATABASE_NAME = "routeflow_db"

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
    }
}
