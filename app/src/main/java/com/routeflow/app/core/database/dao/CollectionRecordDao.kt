package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CollectionRecordDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCollection(collection: CollectionRecordEntity)

    @Query("SELECT * FROM collection_records WHERE companyId = :companyId ORDER BY timestamp DESC")
    fun observeCollections(companyId: String): Flow<List<CollectionRecordEntity>>

    @Query("SELECT * FROM collection_records WHERE isSynced = 0 AND companyId = :companyId ORDER BY timestamp ASC")
    suspend fun getPendingCollections(companyId: String): List<CollectionRecordEntity>

    @Query("UPDATE collection_records SET isSynced = 1 WHERE id = :id")
    suspend fun markSynced(id: String)
}
