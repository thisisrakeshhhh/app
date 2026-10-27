package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.dao.RetailerPriceOverrideDao
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.core.database.entity.RetailerPriceOverrideEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.core.network.dto.UpdateRetailerRequest
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class OfflineRetailerRepository @Inject constructor(
    private val retailerDao: RetailerDao,
    private val api: RouteFlowApi,
    private val tokenStorage: TokenStorage,
    private val database: RouteFlowDatabase,
    private val retailerPriceOverrideDao: RetailerPriceOverrideDao
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
        saveLocalRetailer(request)
        try {
            api.createRetailer(request)
        } catch (_: Exception) {}
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    private suspend fun saveLocalRetailer(request: CreateRetailerRequest) {
        val id = request.id ?: "RET-${System.currentTimeMillis()}"
        val companyId = tokenStorage.getCompanyId() ?: ""
        val entity = RetailerEntity(
            id = id,
            name = request.name,
            beatId = request.beatId,
            address = request.address,
            contactNumber = request.contactNumber,
            latitude = request.latitude ?: 0.0,
            longitude = request.longitude ?: 0.0,
            creditLimitPaise = request.creditLimitPaise,
            outstandingAmountPaise = 0L,
            companyId = companyId,
            lastSyncedAt = System.currentTimeMillis(),
            source = "LOCAL",
            isActive = true
        )
        retailerDao.insertRetailers(listOf(entity))
    }

    override suspend fun updateRetailer(id: String, request: UpdateRetailerRequest): Result<Unit> = try {
        saveLocalRetailerUpdate(id, request)
        try {
            api.updateRetailer(id, request)
        } catch (_: Exception) {}
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    private suspend fun saveLocalRetailerUpdate(id: String, request: UpdateRetailerRequest) {
        val existing = retailerDao.getRetailerById(id).first()
        if (existing != null) {
            val updated = existing.copy(
                name = request.name ?: existing.name,
                address = request.address ?: existing.address,
                contactNumber = request.contactNumber ?: existing.contactNumber,
                creditLimitPaise = request.creditLimitPaise ?: existing.creditLimitPaise,
                isActive = request.isActive ?: existing.isActive
            )
            retailerDao.insertRetailers(listOf(updated))
        }
    }

    override suspend fun syncRetailersFromServer(): Result<Unit> = try {
        val retailersDto = api.getRetailers()
        if (retailersDto.isNotEmpty()) {
            val companyId = tokenStorage.getCompanyId() ?: ""
            val syncTimestamp = System.currentTimeMillis()
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
                    outstandingAmountPaise = dto.outstandingAmountPaise,
                    companyId = companyId,
                    lastSyncedAt = syncTimestamp,
                    source = "SERVER",
                    isActive = true
                )
            }
            database.withTransaction {
                retailerDao.deleteServerRetailers()
                retailerDao.insertRetailers(entities)
            }
        }
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun deactivateRetailer(retailerId: String): Result<Unit> = try {
        retailerDao.updateRetailerActiveStatus(retailerId, false)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun activateRetailer(retailerId: String): Result<Unit> = try {
        retailerDao.updateRetailerActiveStatus(retailerId, true)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    /**
     * Phase 1 Explicit Price-Selection Rule:
     * An applicable active retailer-specific price takes precedence over the default product price.
     * Never chooses randomly.
     */
    override suspend fun getApplicablePrice(retailerId: String, product: Product): Long {
        val override = retailerPriceOverrideDao.getActiveOverride(retailerId, product.id)
        return if (override != null && override.isActive) {
            override.pricePaise
        } else {
            product.pricePaise
        }
    }

    override suspend fun setRetailerPriceOverride(retailerId: String, productId: String, pricePaise: Long): Result<Unit> = try {
        val entity = RetailerPriceOverrideEntity(
            id = "RPO-${retailerId}-${productId}",
            retailerId = retailerId,
            productId = productId,
            pricePaise = pricePaise,
            isActive = true
        )
        retailerPriceOverrideDao.insertOverride(entity)
        Result.success(Unit)
    } catch (e: Exception) {
        Result.failure(e)
    }

    override fun getPriceOverridesForRetailer(retailerId: String): Flow<List<RetailerPriceOverrideEntity>> =
        retailerPriceOverrideDao.getOverridesForRetailer(retailerId)
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
    outstandingAmountPaise = outstandingAmountPaise,
    companyId = companyId,
    lastSyncedAt = lastSyncedAt,
    source = source,
    isActive = isActive
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
    outstandingAmountPaise = outstandingAmountPaise,
    companyId = companyId,
    lastSyncedAt = lastSyncedAt,
    source = source,
    isActive = isActive
)
