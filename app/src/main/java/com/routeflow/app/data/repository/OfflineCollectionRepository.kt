package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.CollectionRecordDao
import com.routeflow.app.core.database.dao.PaymentDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.core.database.entity.PaymentEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.RecordCollectionRequest
import com.routeflow.app.domain.repository.CollectionRepository
import com.routeflow.app.core.security.TokenStorage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.firstOrNull
import com.routeflow.app.core.database.dao.SyncOutboxDao
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.IOException
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OfflineCollectionRepository @Inject constructor(
    private val api: RouteFlowApi,
    private val collectionRecordDao: CollectionRecordDao,
    private val paymentDao: PaymentDao,
    private val retailerDao: RetailerDao,
    private val tokenStorage: TokenStorage,
    private val syncOutboxDao: SyncOutboxDao,
    private val json: Json
) : CollectionRepository {

    override fun observeCollections(): Flow<List<CollectionRecordEntity>> {
        val companyId = tokenStorage.getCompanyId().orEmpty()
        return collectionRecordDao.observeCollections(companyId)
    }

    override suspend fun recordCollection(
        retailerId: String,
        retailerName: String,
        amountPaise: Long,
        paymentMethod: String,
        receiptId: String?,
        notes: String?
    ): Result<CollectionRecordEntity> {
        val userId = tokenStorage.getUserId().orEmpty()
        val companyId = tokenStorage.getCompanyId().orEmpty()

        val finalReceiptId = receiptId?.takeIf { it.isNotBlank() }
            ?: "REC-${System.currentTimeMillis().toString(36).uppercase()}-${(1000..9999).random()}"
        val recordId = "col_${UUID.randomUUID()}"
        val now = System.currentTimeMillis()

        // 1. Save durable local record with isSynced = false
        val localEntity = CollectionRecordEntity(
            id = recordId,
            receiptId = finalReceiptId,
            retailerId = retailerId,
            retailerName = retailerName,
            amountPaise = amountPaise,
            paymentMethod = paymentMethod,
            notes = notes,
            collectedBy = userId,
            companyId = companyId,
            timestamp = now,
            isSynced = false
        )
        collectionRecordDao.insertCollection(localEntity)

        // 2. Insert into local payment ledger so cash calculations update immediately
        paymentDao.insertPayment(
            PaymentEntity(
                id = recordId,
                orderId = "",
                retailerId = retailerId,
                amountPaise = amountPaise,
                method = paymentMethod,
                timestamp = now
            )
        )

        // 3. Atomically adjust local retailer outstanding balance
        val currentRetailer = retailerDao.getRetailerById(retailerId).firstOrNull()
        if (currentRetailer != null) {
            val updatedBal = maxOf(0L, currentRetailer.outstandingAmountPaise - amountPaise)
            retailerDao.updateOutstanding(retailerId, updatedBal)
        }

        val idempotencyKey = "col_idemp_${recordId}"
        val recordReq = RecordCollectionRequest(
            retailerId = retailerId,
            amountPaise = amountPaise,
            paymentMethod = paymentMethod,
            receiptId = finalReceiptId,
            notes = notes,
            idempotencyKey = idempotencyKey
        )

        // 4. Attempt online sync
        return try {
            val response = api.recordCollection(recordReq)
            if (response.success) {
                collectionRecordDao.markSynced(recordId)
                retailerDao.updateOutstanding(retailerId, response.balanceAfterPaise)
                Result.success(localEntity.copy(isSynced = true))
            } else {
                enqueueCollectionSync(recordReq, recordId, userId, companyId)
                Result.success(localEntity)
            }
        } catch (_: IOException) {
            // Durable offline save: enqueue in sync_outbox
            enqueueCollectionSync(recordReq, recordId, userId, companyId)
            Result.success(localEntity)
        } catch (e: Exception) {
            enqueueCollectionSync(recordReq, recordId, userId, companyId)
            Result.success(localEntity)
        }
    }

    private suspend fun enqueueCollectionSync(req: RecordCollectionRequest, recordId: String, userId: String, companyId: String) {
        try {
            syncOutboxDao.insertSyncItem(
                SyncOutboxEntity(
                    type = "COLLECTION_RECORD",
                    payload = json.encodeToString(req),
                    idempotencyKey = "col_idemp_${recordId}",
                    userId = userId,
                    companyId = companyId
                )
            )
        } catch (_: Exception) {}
    }

    override suspend fun syncPendingCollections(): Result<Int> {
        val companyId = tokenStorage.getCompanyId().orEmpty()
        val pending = collectionRecordDao.getPendingCollections(companyId)
        var syncedCount = 0

        for (item in pending) {
            try {
                val response = api.recordCollection(
                    RecordCollectionRequest(
                        retailerId = item.retailerId,
                        amountPaise = item.amountPaise,
                        paymentMethod = item.paymentMethod,
                        receiptId = item.receiptId,
                        notes = item.notes,
                        idempotencyKey = "col_idemp_${item.id}"
                    )
                )
                if (response.success) {
                    collectionRecordDao.markSynced(item.id)
                    retailerDao.updateOutstanding(item.retailerId, response.balanceAfterPaise)
                    syncedCount++
                }
            } catch (_: Exception) {
                // Break or continue next
            }
        }
        return Result.success(syncedCount)
    }
}
