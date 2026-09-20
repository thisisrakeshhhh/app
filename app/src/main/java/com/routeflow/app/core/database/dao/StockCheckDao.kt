package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.StockCheckEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface StockCheckDao {
    @Query("SELECT * FROM stock_checks WHERE visitId = :visitId")
    fun getChecksForVisit(visitId: String): Flow<List<StockCheckEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStockCheck(stockCheck: StockCheckEntity)
}
