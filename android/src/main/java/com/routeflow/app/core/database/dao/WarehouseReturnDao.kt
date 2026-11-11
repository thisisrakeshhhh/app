package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.WarehouseReturnEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WarehouseReturnDao {
    @Query("SELECT * FROM warehouse_returns ORDER BY createdAt DESC")
    fun getAllInspections(): Flow<List<WarehouseReturnEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReturnInspection(item: WarehouseReturnEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReturnInspections(items: List<WarehouseReturnEntity>)
}
