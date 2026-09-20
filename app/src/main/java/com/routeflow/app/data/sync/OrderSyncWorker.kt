package com.routeflow.app.data.sync

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.network.api.OrderWithItemsRequest
import com.routeflow.app.core.network.api.RouteFlowApi
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString

@HiltWorker
class OrderSyncWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val api: RouteFlowApi,
    private val database: RouteFlowDatabase,
    private val json: Json
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val pendingSyncs = database.syncOutboxDao().getAllPendingSyncs()
        
        var hasError = false
        
        for (syncItem in pendingSyncs) {
            try {
                when (syncItem.type) {
                    "ORDER_SUBMISSION" -> {
                        val request = json.decodeFromString<OrderWithItemsRequest>(syncItem.payload)
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
}
