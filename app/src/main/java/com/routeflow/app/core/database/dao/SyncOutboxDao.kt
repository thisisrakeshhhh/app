package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SyncOutboxDao {
    @Query("SELECT * FROM sync_outbox WHERE type != 'QUARANTINED' ORDER BY createdAt ASC")
    fun observeAllPendingSyncs(): Flow<List<SyncOutboxEntity>>

    @Query("SELECT * FROM sync_outbox WHERE type != 'QUARANTINED' ORDER BY createdAt ASC")
    suspend fun getAllPendingSyncs(): List<SyncOutboxEntity>

    @Query("SELECT * FROM sync_outbox WHERE userId = :userId AND companyId = :companyId AND type != 'QUARANTINED' ORDER BY createdAt ASC")
    suspend fun getPendingSyncsForUser(userId: String, companyId: String): List<SyncOutboxEntity>

    @Query("SELECT * FROM sync_outbox WHERE companyId = :companyId AND type != 'QUARANTINED' ORDER BY createdAt ASC")
    suspend fun getPendingSyncsForCompany(companyId: String): List<SyncOutboxEntity>

    @Query("UPDATE sync_outbox SET type = 'QUARANTINED', lastError = 'Unknown account ownership (legacy row)' WHERE (userId = '' OR companyId = '') AND type != 'QUARANTINED'")
    suspend fun quarantineLegacySyncs(): Int

    @Query("SELECT * FROM sync_outbox WHERE type = 'QUARANTINED'")
    suspend fun getQuarantinedSyncs(): List<SyncOutboxEntity>

    @Insert
    suspend fun insertSyncItem(item: SyncOutboxEntity)

    @Update
    suspend fun updateSyncItem(item: SyncOutboxEntity)

    @Delete
    suspend fun deleteSyncItem(item: SyncOutboxEntity)
}
