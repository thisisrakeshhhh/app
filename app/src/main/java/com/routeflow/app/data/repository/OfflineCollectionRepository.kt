package com.routeflow.app.data.repository

import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.core.network.dto.RecordCollectionRequest
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.sync.SyncManager
import com.routeflow.app.domain.repository.CollectionRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfflineCollectionRepository @Inject constructor(private val database: RouteFlowDatabase,
    private val tokens: TokenStorage, private val events: DurableFieldRepository, private val sync: SyncManager,
    private val json: Json) : CollectionRepository {
    override fun observeCollections(): Flow<List<CollectionRecordEntity>> =
        database.collectionRecordDao().observeCollections(tokens.getCompanyId().orEmpty(), tokens.getUserId().orEmpty())
    override suspend fun recordCollection(retailerId: String, retailerName: String, amountPaise: Long,
        paymentMethod: String, receiptId: String?, notes: String?): Result<CollectionRecordEntity> = runCatching {
        require(amountPaise in 1..1_000_000_000L)
        require(paymentMethod in listOf("CASH", "UPI", "CHEQUE", "BANK"))
        require(paymentMethod == "CASH" || !receiptId.isNullOrBlank())
        val id = "col_${UUID.randomUUID()}"
        val record = CollectionRecordEntity(id = id, receiptId = "LOCAL-$id", retailerId = retailerId,
            retailerName = retailerName, amountPaise = amountPaise, paymentMethod = paymentMethod, notes = notes,
            collectedBy = requireNotNull(tokens.getUserId()), companyId = requireNotNull(tokens.getCompanyId()), timestamp = System.currentTimeMillis())
        val request = RecordCollectionRequest(retailerId = retailerId, amountPaise = amountPaise,
            paymentMethod = paymentMethod, reference = receiptId, notes = notes, idempotencyKey = "col_idemp_$id")
        events.queue("COLLECTION_RECORD", json.encodeToString(request), "col_idemp_$id") { database.collectionRecordDao().insertCollection(record) }
        record
    }
    override suspend fun syncPendingCollections(): Result<Int> = runCatching { sync.scheduleSync(); 0 }
}
