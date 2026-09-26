package com.routeflow.app.core.database.dao

import androidx.room.*
import com.routeflow.app.core.database.entity.*
import kotlinx.coroutines.flow.Flow

@Dao
interface FieldRecordDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveShift(shift: LocalShiftEntity)
    @Query("SELECT * FROM local_shifts WHERE userId=:userId AND companyId=:companyId AND status != 'OFF_SHIFT' ORDER BY startTime DESC LIMIT 1")
    fun observeShift(userId: String, companyId: String): Flow<LocalShiftEntity?>
    @Query("SELECT * FROM local_shifts WHERE id=:id")
    suspend fun getShift(id: String): LocalShiftEntity?
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun saveRecord(record: FieldRecordEntity)
}
