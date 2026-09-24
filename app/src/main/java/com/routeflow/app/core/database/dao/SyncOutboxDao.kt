package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.routeflow.app.core.database.entity.SyncOutboxEntity

@Dao
interface SyncOutboxDao {
    @Query("SELECT * FROM sync_outbox ORDER BY createdAt ASC")
    suspend fun getAllPendingSyncs(): List<SyncOutboxEntity>

    @Query("SELECT * FROM sync_outbox WHERE userId = :userId AND companyId = :companyId ORDER BY createdAt ASC")
    suspend fun getPendingSyncsForUser(userId: String, companyId: String): List<SyncOutboxEntity>

    @Query("SELECT * FROM sync_outbox WHERE companyId = :companyId ORDER BY createdAt ASC")
    suspend fun getPendingSyncsForCompany(companyId: String): List<SyncOutboxEntity>

    @Insert
    suspend fun insertSyncItem(item: SyncOutboxEntity)

    @Update
    suspend fun updateSyncItem(item: SyncOutboxEntity)

    @Delete
    suspend fun deleteSyncItem(item: SyncOutboxEntity)
}
