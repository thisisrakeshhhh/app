package com.routeflow.app.domain.repository

import com.routeflow.app.core.database.entity.CollectionRecordEntity
import kotlinx.coroutines.flow.Flow

interface CollectionRepository {
    fun observeCollections(): Flow<List<CollectionRecordEntity>>
    suspend fun recordCollection(
        retailerId: String,
        retailerName: String,
        amountPaise: Long,
        paymentMethod: String,
        receiptId: String? = null,
        notes: String? = null
    ): Result<CollectionRecordEntity>
    suspend fun syncPendingCollections(): Result<Int>
    suspend fun getRemoteCollections(retailerId: String? = null): Result<List<com.routeflow.app.core.network.dto.CollectionDto>>
    suspend fun reviewCollection(id: String, action: String, reason: String): Result<com.routeflow.app.core.network.dto.StatusResponse>
}
