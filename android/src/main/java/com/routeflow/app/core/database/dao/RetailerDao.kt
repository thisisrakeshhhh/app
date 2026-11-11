package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.RetailerEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RetailerDao {
    @Query("SELECT * FROM retailers")
    fun getAllRetailers(): Flow<List<RetailerEntity>>

    @Query("SELECT * FROM retailers WHERE beatId = :beatId")
    fun getRetailersByBeat(beatId: String): Flow<List<RetailerEntity>>

    @Query("SELECT * FROM retailers WHERE id = :id")
    fun getRetailerById(id: String): Flow<RetailerEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRetailers(retailers: List<RetailerEntity>)

    @Query("UPDATE retailers SET outstandingAmountPaise = :newAmount WHERE id = :retailerId")
    suspend fun updateOutstanding(retailerId: String, newAmount: Long)

    @Query("UPDATE retailers SET isActive = :isActive WHERE id = :retailerId")
    suspend fun updateRetailerActiveStatus(retailerId: String, isActive: Boolean)

    @Query("UPDATE retailers SET name = :name, address = :address, contactNumber = :contactNumber, creditLimitPaise = :creditLimitPaise, isActive = :isActive WHERE id = :retailerId")
    suspend fun updateRetailerDetails(retailerId: String, name: String, address: String, contactNumber: String, creditLimitPaise: Long, isActive: Boolean)

    @Query("DELETE FROM retailers WHERE source != 'LOCAL'")
    suspend fun deleteServerRetailers()

    @Query("DELETE FROM retailers")
    suspend fun deleteAllRetailers()
}
