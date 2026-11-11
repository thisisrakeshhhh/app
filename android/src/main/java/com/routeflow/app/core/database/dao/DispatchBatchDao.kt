package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.DispatchBatchEntity
import com.routeflow.app.core.database.entity.DispatchBatchOrderEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DispatchBatchDao {
    @Query("SELECT * FROM dispatch_batches ORDER BY createdAt DESC")
    fun getAllDispatchBatches(): Flow<List<DispatchBatchEntity>>

    @Query("SELECT * FROM dispatch_batches WHERE id = :id")
    suspend fun getDispatchBatchById(id: String): DispatchBatchEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDispatchBatch(batch: DispatchBatchEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDispatchBatches(batches: List<DispatchBatchEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDispatchBatchOrders(orders: List<DispatchBatchOrderEntity>)

    @Query("SELECT * FROM dispatch_batch_orders WHERE dispatchBatchId = :batchId")
    suspend fun getOrdersForBatch(batchId: String): List<DispatchBatchOrderEntity>

    @Query("UPDATE dispatch_batches SET status = :status, handedOverAt = :handedOverAt WHERE id = :id")
    suspend fun updateHandoverStatus(id: String, status: String, handedOverAt: Long)
}
