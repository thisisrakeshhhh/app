package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.ProductBatchEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProductBatchDao {
    @Query("SELECT * FROM product_batches WHERE productId = :productId AND status = 'ACTIVE' ORDER BY expiryDate ASC")
    fun getBatchesForProduct(productId: String): Flow<List<ProductBatchEntity>>

    @Query("SELECT * FROM product_batches WHERE status = 'ACTIVE' ORDER BY expiryDate ASC")
    fun getAllActiveBatches(): Flow<List<ProductBatchEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBatches(batches: List<ProductBatchEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBatch(batch: ProductBatchEntity)

    @Query("DELETE FROM product_batches WHERE companyId = :companyId")
    suspend fun clearCompanyBatches(companyId: String)
}
