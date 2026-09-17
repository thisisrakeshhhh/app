package com.routeflow.app.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.PaymentDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.core.database.entity.DeliveryRecordEntity
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.PaymentEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
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
        TargetEntity::class
    ],
    version = 2,
    exportSchema = true
)
abstract class RouteFlowDatabase : RoomDatabase() {
    abstract fun retailerDao(): RetailerDao
    abstract fun productDao(): ProductDao
    abstract fun orderDao(): OrderDao
    abstract fun visitDao(): VisitDao
    abstract fun paymentDao(): PaymentDao

    companion object {
        const val DATABASE_NAME = "routeflow_db"
    }
}
