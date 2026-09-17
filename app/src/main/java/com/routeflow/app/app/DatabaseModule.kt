package com.routeflow.app.app

import android.content.Context
import androidx.room.Room
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.PaymentDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.dao.VisitDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context
    ): RouteFlowDatabase {
        return Room.databaseBuilder(
            context,
            RouteFlowDatabase::class.java,
            RouteFlowDatabase.DATABASE_NAME
        )
        .fallbackToDestructiveMigration() // For demo purposes, we allow destructive migration to version 2
        .build()
    }

    @Provides
    fun provideRetailerDao(database: RouteFlowDatabase): RetailerDao {
        return database.retailerDao()
    }

    @Provides
    fun provideProductDao(database: RouteFlowDatabase): ProductDao {
        return database.productDao()
    }

    @Provides
    fun provideOrderDao(database: RouteFlowDatabase): OrderDao {
        return database.orderDao()
    }

    @Provides
    fun provideVisitDao(database: RouteFlowDatabase): VisitDao {
        return database.visitDao()
    }

    @Provides
    fun providePaymentDao(database: RouteFlowDatabase): PaymentDao {
        return database.paymentDao()
    }
}
