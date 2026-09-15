package com.routeflow.app.core.database

import androidx.room.Database
import androidx.room.RoomDatabase
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity

@Database(
    entities = [
        RetailerEntity::class,
        ProductEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class RouteFlowDatabase : RoomDatabase() {
    abstract fun retailerDao(): RetailerDao
    abstract fun productDao(): ProductDao

    companion object {
        const val DATABASE_NAME = "routeflow_db"
    }
}
