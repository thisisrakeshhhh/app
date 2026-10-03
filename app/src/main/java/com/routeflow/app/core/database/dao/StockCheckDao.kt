package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.StockCheckEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface StockCheckDao {
    @Query("SELECT * FROM stock_checks WHERE retailerId = :retailerId ORDER BY timestamp DESC")
    fun getChecksForRetailer(retailerId: String): Flow<List<StockCheckEntity>>

    @Query("SELECT * FROM stock_checks WHERE visitId = :visitId ORDER BY timestamp DESC")
    fun getChecksForVisit(visitId: String): Flow<List<StockCheckEntity>>

    @Query("SELECT * FROM stock_checks ORDER BY timestamp DESC")
    fun getAllChecks(): Flow<List<StockCheckEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStockCheck(stockCheck: StockCheckEntity)

    @Query("UPDATE stock_checks SET syncStatus = :syncStatus WHERE id = :id")
    suspend fun updateSyncStatus(id: String, syncStatus: String)
}
