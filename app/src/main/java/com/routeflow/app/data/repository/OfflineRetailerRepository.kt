package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.core.network.dto.UpdateRetailerRequest
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class OfflineRetailerRepository @Inject constructor(
    private val retailerDao: RetailerDao,
    private val api: RouteFlowApi
) : RetailerRepository {
    override fun getAllRetailers(): Flow<List<Retailer>> =
        retailerDao.getAllRetailers().map { entities ->
            entities.map { it.asDomainModel() }
        }

    override fun getRetailersByBeat(beatId: String): Flow<List<Retailer>> =
        retailerDao.getRetailersByBeat(beatId).map { entities ->
            entities.map { it.asDomainModel() }
        }

    override fun getRetailerById(id: String): Flow<Retailer?> =
        retailerDao.getRetailerById(id).map { it?.asDomainModel() }

    override suspend fun saveRetailers(retailers: List<Retailer>) {
        retailerDao.insertRetailers(retailers.map { it.asEntity() })
    }

    override suspend fun createRetailer(request: CreateRetailerRequest): Result<Unit> = try {
        val resp = api.createRetailer(request)
        if (resp.success) {
            syncRetailersFromServer()
            Result.success(Unit)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to create retailer"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun updateRetailer(id: String, request: UpdateRetailerRequest): Result<Unit> = try {
        val resp = api.updateRetailer(id, request)
        if (resp.success) {
            syncRetailersFromServer()
            Result.success(Unit)
        } else {
            Result.failure(Exception(resp.message ?: "Failed to update retailer"))
        }
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun syncRetailersFromServer(): Result<Unit> = try {
        val retailersDto = api.getRetailers()
        val entities = retailersDto.map { dto ->
            RetailerEntity(
                id = dto.id,
                name = dto.name,
                beatId = dto.beatId,
                address = dto.address,
                contactNumber = dto.contactNumber,
                latitude = dto.latitude ?: 0.0,
                longitude = dto.longitude ?: 0.0,
                creditLimitPaise = dto.creditLimitPaise,
                outstandingAmountPaise = dto.outstandingAmountPaise
            )
        }
        retailerDao.insertRetailers(entities)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }
}

private fun RetailerEntity.asDomainModel() = Retailer(
    id = id,
    name = name,
    beatId = beatId,
    address = address,
    contactNumber = contactNumber,
    latitude = latitude,
    longitude = longitude,
    creditLimitPaise = creditLimitPaise,
    outstandingAmountPaise = outstandingAmountPaise
)

private fun Retailer.asEntity() = RetailerEntity(
    id = id,
    name = name,
    beatId = beatId,
    address = address,
    contactNumber = contactNumber,
    latitude = latitude,
    longitude = longitude,
    creditLimitPaise = creditLimitPaise,
    outstandingAmountPaise = outstandingAmountPaise
)
