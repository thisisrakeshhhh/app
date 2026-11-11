package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.ShiftLocationEntity

@Dao
interface ShiftLocationDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLocation(point: ShiftLocationEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLocations(points: List<ShiftLocationEntity>)

    @Query("SELECT * FROM shift_locations_outbox WHERE shiftId = :shiftId AND isSynced = 0 ORDER BY timestamp ASC LIMIT :limit")
    suspend fun getPendingLocations(shiftId: String, limit: Int = 50): List<ShiftLocationEntity>

    @Query("SELECT * FROM shift_locations_outbox WHERE userId=:userId AND companyId=:companyId AND isSynced=0 ORDER BY timestamp,id LIMIT :limit")
    suspend fun getPendingForAccount(userId: String, companyId: String, limit: Int = 50): List<ShiftLocationEntity>

    @Query("UPDATE shift_locations_outbox SET isSynced = 1 WHERE id IN (:ids)")
    suspend fun markSynced(ids: List<String>)

    @Query("DELETE FROM shift_locations_outbox WHERE isSynced = 1 AND timestamp < :olderThanTimestamp")
    suspend fun deleteSynced(olderThanTimestamp: Long)

    @Query("DELETE FROM shift_locations_outbox WHERE userId != :currentUserId")
    suspend fun purgeLocationsForOtherUsers(currentUserId: String)
}
