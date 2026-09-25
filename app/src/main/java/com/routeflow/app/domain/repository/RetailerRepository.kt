package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.core.network.dto.UpdateRetailerRequest
import com.routeflow.app.domain.model.Retailer
import kotlinx.coroutines.flow.Flow

interface RetailerRepository {
    fun getAllRetailers(): Flow<List<Retailer>>
    fun getRetailersByBeat(beatId: String): Flow<List<Retailer>>
    fun getRetailerById(id: String): Flow<Retailer?>
    suspend fun saveRetailers(retailers: List<Retailer>)
    suspend fun createRetailer(request: CreateRetailerRequest): Result<Unit>
    suspend fun updateRetailer(id: String, request: UpdateRetailerRequest): Result<Unit>
    suspend fun syncRetailersFromServer(): Result<Unit>
}
