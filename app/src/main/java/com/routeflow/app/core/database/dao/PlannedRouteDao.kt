package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.routeflow.app.core.database.entity.PlannedRouteEntity
import com.routeflow.app.core.database.entity.PlannedRouteStopEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface PlannedRouteDao {
    @Query("SELECT * FROM planned_routes WHERE companyId = :companyId ORDER BY routeDate DESC, createdAt DESC")
    fun observeAllRoutes(companyId: String): Flow<List<PlannedRouteEntity>>

    @Query("SELECT * FROM planned_routes WHERE companyId = :companyId AND routeDate = :date ORDER BY createdAt DESC")
    fun observeRoutesByDate(companyId: String, date: String): Flow<List<PlannedRouteEntity>>

    @Query("SELECT * FROM planned_routes WHERE companyId = :companyId AND (salespersonId = :salespersonId OR (:salespersonId IN ('user_sales', 'demo-sales', 'sales') AND salespersonId IN ('user_sales', 'demo-sales', 'sales'))) AND status = 'PUBLISHED' ORDER BY routeDate DESC, createdAt DESC")
    fun observePublishedRoutesForSalesperson(companyId: String, salespersonId: String): Flow<List<PlannedRouteEntity>>

    @Query("SELECT * FROM planned_routes WHERE companyId = :companyId AND (salespersonId = :salespersonId OR (:salespersonId IN ('user_sales', 'demo-sales', 'sales') AND salespersonId IN ('user_sales', 'demo-sales', 'sales'))) AND routeDate = :date AND status = 'PUBLISHED' LIMIT 1")
    fun observeTodayPublishedRouteForSalesperson(companyId: String, salespersonId: String, date: String): Flow<PlannedRouteEntity?>

    @Query("SELECT * FROM planned_routes WHERE id = :routeId LIMIT 1")
    suspend fun getRouteById(routeId: String): PlannedRouteEntity?

    @Query("SELECT * FROM planned_route_stops WHERE routeId = :routeId ORDER BY stopSequence ASC")
    fun observeStopsForRoute(routeId: String): Flow<List<PlannedRouteStopEntity>>

    @Query("SELECT * FROM planned_route_stops WHERE routeId = :routeId ORDER BY stopSequence ASC")
    suspend fun getStopsForRoute(routeId: String): List<PlannedRouteStopEntity>

    @Query("SELECT * FROM planned_route_stops WHERE id = :stopId LIMIT 1")
    suspend fun getStopById(stopId: String): PlannedRouteStopEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRoute(route: PlannedRouteEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRoutes(routes: List<PlannedRouteEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStops(stops: List<PlannedRouteStopEntity>)

    @Update
    suspend fun updateRoute(route: PlannedRouteEntity)

    @Update
    suspend fun updateStop(stop: PlannedRouteStopEntity)

    @Query("UPDATE planned_route_stops SET status = :status, visitedAt = :visitedAt, notes = :notes, updatedAt = :updatedAt WHERE id = :stopId")
    suspend fun updateStopStatus(stopId: String, status: String, visitedAt: Long?, notes: String?, updatedAt: Long)

    @Query("DELETE FROM planned_route_stops WHERE routeId = :routeId")
    suspend fun deleteStopsForRoute(routeId: String)

    @Query("DELETE FROM planned_routes WHERE id = :routeId")
    suspend fun deleteRoute(routeId: String)

    @Transaction
    suspend fun replaceRouteWithStops(route: PlannedRouteEntity, stops: List<PlannedRouteStopEntity>) {
        insertRoute(route)
        deleteStopsForRoute(route.id)
        insertStops(stops)
    }
}
