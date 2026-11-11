package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.RetailerPriceOverrideEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RetailerPriceOverrideDao {
    @Query("SELECT * FROM retailer_price_overrides WHERE retailerId = :retailerId AND productId = :productId AND isActive = 1 LIMIT 1")
    suspend fun getActiveOverride(retailerId: String, productId: String): RetailerPriceOverrideEntity?

    @Query("SELECT * FROM retailer_price_overrides WHERE retailerId = :retailerId AND isActive = 1")
    fun getOverridesForRetailer(retailerId: String): Flow<List<RetailerPriceOverrideEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOverride(override: RetailerPriceOverrideEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOverrides(overrides: List<RetailerPriceOverrideEntity>)

    @Query("UPDATE retailer_price_overrides SET isActive = :isActive WHERE id = :id")
    suspend fun updateOverrideStatus(id: String, isActive: Boolean)

    @Query("DELETE FROM retailer_price_overrides WHERE id = :id")
    suspend fun deleteOverride(id: String)

    @Query("DELETE FROM retailer_price_overrides")
    suspend fun deleteAllOverrides()
}
