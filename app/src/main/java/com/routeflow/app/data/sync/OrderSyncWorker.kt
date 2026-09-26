package com.routeflow.app.data.sync

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.room.withTransaction
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.SyncOutboxEntity
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@HiltWorker
class OrderSyncWorker @AssistedInject constructor(
    @Assisted appContext: Context, @Assisted params: WorkerParameters,
    private val api: RouteFlowApi, private val database: RouteFlowDatabase,
    private val tokenStorage: TokenStorage, private val json: Json
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val user = inputData.getString(KEY_USER_ID) ?: tokenStorage.getUserId() ?: return Result.failure()
        val company = inputData.getString(KEY_COMPANY_ID) ?: tokenStorage.getCompanyId() ?: return Result.failure()
        fun sameAccount() = tokenStorage.getUserId() == user && tokenStorage.getCompanyId() == company
        if (!sameAccount()) return Result.success()
        val account = "$user:$company"
        database.syncOutboxDao().quarantineLegacySyncs()
        // FIFO preserves event dependencies. A rejected dependency needs visible review.
        while (sameAccount()) {
            var pending = database.syncOutboxDao().getPendingSyncsForUser(user, company)
            if (pending.isEmpty()) {
                val points = database.shiftLocationDao().getPendingForAccount(user, company)
                if (points.isEmpty()) return Result.success()
                val group = points.filter { it.shiftId == points.first().shiftId }
                val request = ShiftLocationsRequest(group.first().shiftId, group.map { LocationPoint(it.id, it.latitude, it.longitude, it.accuracy, it.timestamp) })
                database.syncOutboxDao().insertSyncItem(SyncOutboxEntity(type = "LOCATIONS", payload = json.encodeToString(request),
                    idempotencyKey = "locations_${group.first().id}", userId = user, companyId = company))
                pending = database.syncOutboxDao().getPendingSyncsForUser(user, company)
            }
            val event = pending.first()
            if (event.syncState == "NEEDS_ATTENTION" || event.type == "PERMANENT_FAILURE") return Result.failure()
            database.syncOutboxDao().updateSyncItem(event.copy(syncState = "SYNCING"))
            try {
                check(sameAccount())
                var localCommit: suspend () -> Unit = {}
                val success = when (event.type) {
                    "ORDER_SUBMISSION" -> {
                        val request = json.decodeFromString<OrderSubmitRequest>(event.payload)
                        val response = api.submitOrder(request, account)
                        localCommit = {
                            database.orderDao().insertOrder(request.order.toEntity())
                            database.orderDao().insertOrderItems(request.items.map { it.toEntity() })
                        }
                        response.success
                    }
                    "VISIT_START" -> api.submitVisit(json.decodeFromString(event.payload), account).success
                    "VISIT_END" -> {
                        val request = json.decodeFromString<VisitCheckoutEvent>(event.payload)
                        api.checkoutVisit(request.visitId, request.request, account).success
                    }
                    "STOCK_CHECK" -> api.submitStockCheck(json.decodeFromString(event.payload), account).success
                    "SHIFT_START" -> api.startShift(json.decodeFromString(event.payload), account).success
                    "SHIFT_END" -> api.endShift(json.decodeFromString(event.payload), account).success
                    "SHIFT_PAUSE", "SHIFT_RESUME" -> api.pauseShift(if (event.type == "SHIFT_PAUSE") "pause" else "resume", json.decodeFromString(event.payload), account).success
                    "LOCATIONS" -> {
                        val request = json.decodeFromString<ShiftLocationsRequest>(event.payload)
                        val response = api.uploadShiftLocations(request, account)
                        localCommit = { database.shiftLocationDao().markSynced(request.points.mapNotNull { it.id }) }
                        response.success
                    }
                    "COLLECTION_RECORD" -> {
                        val request = json.decodeFromString<RecordCollectionRequest>(event.payload)
                        val response = api.recordCollection(request, account)
                        localCommit = { database.collectionRecordDao().confirm(event.idempotencyKey.removePrefix("col_idemp_"), response.status, response.collectionId, response.receiptId.orEmpty()) }
                        response.success
                    }
                    "HANDOVER_REQUEST" -> api.submitHandoverRequest(json.decodeFromString(event.payload), account).success
                    else -> throw IllegalArgumentException("Unsupported saved event; contact owner")
                }
                if (!success) throw java.io.IOException("Server did not acknowledge saved event")
                if (!sameAccount()) return Result.success()
                database.withTransaction { localCommit(); database.syncOutboxDao().deleteSyncItem(event) }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) {
                if (!sameAccount()) return Result.success()
                val code = (e as? retrofit2.HttpException)?.code()
                val permanent = code in listOf(400, 403, 404, 409, 422) || e is IllegalArgumentException
                database.syncOutboxDao().updateSyncItem(event.copy(syncState = if (permanent) "NEEDS_ATTENTION" else "SAVED_OFFLINE",
                    retryCount = event.retryCount + 1, lastError = if (permanent) "VALIDATION_REVIEW" else if (code == 401) "SIGN_IN_AGAIN" else "CONNECTION_RETRY"))
                return if (permanent) Result.failure() else Result.retry()
            }
        }
        return Result.success()
    }
    companion object {
        const val KEY_USER_ID = "target_user_id"
        const val KEY_COMPANY_ID = "target_company_id"
    }
}
