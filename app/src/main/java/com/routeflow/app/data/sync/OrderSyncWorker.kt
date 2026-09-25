package com.routeflow.app.data.sync

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.OrderSubmitRequest
import com.routeflow.app.core.network.dto.toEntity
import com.routeflow.app.core.security.TokenStorage
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

@HiltWorker
class OrderSyncWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val api: RouteFlowApi,
    private val database: RouteFlowDatabase,
    private val tokenStorage: TokenStorage,
    private val json: Json
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        // 1. Quarantine any legacy outbox rows whose ownership is unknown
        database.syncOutboxDao().quarantineLegacySyncs()

        // 2. Bind worker to target account and company context
        val targetUserId = inputData.getString(KEY_USER_ID) ?: tokenStorage.getUserId()
        val targetCompanyId = inputData.getString(KEY_COMPANY_ID) ?: tokenStorage.getCompanyId()

        if (targetUserId.isNullOrBlank() || targetCompanyId.isNullOrBlank()) {
            return Result.failure()
        }

        // 3. Verify session credentials match target account at worker start
        if (tokenStorage.getUserId() != targetUserId || tokenStorage.getCompanyId() != targetCompanyId) {
            // Account switch detected; safely stop previous-account worker without uploading
            return Result.success()
        }

        // 4. Process all pending syncs for this account
        var hasRetryableError = false

        while (true) {
            val pendingSyncs = database.syncOutboxDao().getPendingSyncsForUser(targetUserId, targetCompanyId)
                .filter { it.type != "PERMANENT_FAILURE" && it.type != "QUARANTINED" }

            if (pendingSyncs.isEmpty()) break

            for (syncItem in pendingSyncs) {
                // Guard against mid-request account switch: stop if active credentials changed
                if (tokenStorage.getUserId() != targetUserId || tokenStorage.getCompanyId() != targetCompanyId) {
                    return Result.success()
                }

                try {
                    when (syncItem.type) {
                        "ORDER_SUBMISSION" -> {
                            val request = json.decodeFromString<OrderSubmitRequest>(syncItem.payload)
                            val response = api.submitOrder(request)
                            if (response.success) {
                                database.syncOutboxDao().deleteSyncItem(syncItem)
                                database.orderDao().insertOrder(request.order.toEntity())
                                database.orderDao().insertOrderItems(request.items.map { it.toEntity() })
                            } else {
                                hasRetryableError = true
                                database.syncOutboxDao().updateSyncItem(
                                    syncItem.copy(
                                        retryCount = syncItem.retryCount + 1,
                                        lastError = response.message ?: "Submission unacknowledged"
                                    )
                                )
                            }
                        }
                    }
                } catch (e: Exception) {
                    val isPermanent = if (e is retrofit2.HttpException) {
                        val code = e.code()
                        code in listOf(400, 403, 409, 422)
                    } else false

                    val errorMsg = if (e is retrofit2.HttpException) {
                        try {
                            val errBody = e.response()?.errorBody()?.string()
                            if (!errBody.isNullOrBlank()) {
                                val errJson = org.json.JSONObject(errBody)
                                errJson.optString("error", errBody)
                            } else {
                                "HTTP ${e.code()}: ${e.message()}"
                            }
                        } catch (_: Exception) {
                            "HTTP ${e.code()}: ${e.message()}"
                        }
                    } else {
                        e.message ?: "Sync error"
                    }

                    if (isPermanent) {
                        // Do not retry permanently invalid requests indefinitely
                        database.syncOutboxDao().updateSyncItem(
                            syncItem.copy(
                                type = "PERMANENT_FAILURE",
                                lastError = errorMsg
                            )
                        )
                        try {
                            val request = json.decodeFromString<OrderSubmitRequest>(syncItem.payload)
                            database.orderDao().updateOrderStatus(request.order.id, "NEEDS_ATTENTION", System.currentTimeMillis())
                        } catch (_: Exception) {}
                    } else {
                        hasRetryableError = true
                        database.syncOutboxDao().updateSyncItem(
                            syncItem.copy(
                                retryCount = syncItem.retryCount + 1,
                                lastError = errorMsg
                            )
                        )
                    }
                }
            }

            if (hasRetryableError) break
        }

        return if (hasRetryableError) Result.retry() else Result.success()
    }

    companion object {
        const val KEY_USER_ID = "target_user_id"
        const val KEY_COMPANY_ID = "target_company_id"
    }
}
