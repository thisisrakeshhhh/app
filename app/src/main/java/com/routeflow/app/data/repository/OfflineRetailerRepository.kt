package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class OfflineRetailerRepository @Inject constructor(
    private val retailerDao: RetailerDao
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
