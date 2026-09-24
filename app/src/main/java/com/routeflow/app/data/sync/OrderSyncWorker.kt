package com.routeflow.app.data.sync

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.OrderSubmitRequest
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

        // 4. Query only this account's operations
        val pendingSyncs = database.syncOutboxDao().getPendingSyncsForUser(targetUserId, targetCompanyId)

        var hasError = false

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
                        } else {
                            hasError = true
                        }
                    }
                }
            } catch (e: Exception) {
                hasError = true
                database.syncOutboxDao().updateSyncItem(
                    syncItem.copy(
                        retryCount = syncItem.retryCount + 1,
                        lastError = e.message
                    )
                )
            }
        }

        return if (hasError) Result.retry() else Result.success()
    }

    companion object {
        const val KEY_USER_ID = "target_user_id"
        const val KEY_COMPANY_ID = "target_company_id"
    }
}
