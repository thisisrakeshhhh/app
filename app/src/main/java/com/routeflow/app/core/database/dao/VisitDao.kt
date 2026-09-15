package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.VisitEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface VisitDao {
    @Query("SELECT * FROM visits WHERE employeeId = :employeeId AND status = 'ACTIVE' LIMIT 1")
    fun getActiveVisit(employeeId: String): Flow<VisitEntity?>

    @Query("SELECT * FROM visits WHERE employeeId = :employeeId ORDER BY checkInTime DESC")
    fun getVisitsByEmployee(employeeId: String): Flow<List<VisitEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertVisit(visit: VisitEntity)

    @Query("UPDATE visits SET checkOutTime = :checkOutTime, status = 'COMPLETED' WHERE id = :visitId")
    suspend fun completeVisit(visitId: String, checkOutTime: Long)
}
