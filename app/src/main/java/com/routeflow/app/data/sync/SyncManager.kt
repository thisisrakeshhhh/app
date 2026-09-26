package com.routeflow.app.data.sync

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.routeflow.app.core.security.TokenStorage
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Centralized sync scheduler.
 * Enqueues account-scoped sync workers using ExistingWorkPolicy.KEEP,
 * ensuring that active running workers and exponential retry backoffs
 * are never cancelled or disrupted on new orders or activity resume.
 */
@Singleton
class SyncManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val tokenStorage: TokenStorage
) {
    fun scheduleSync(userId: String? = null, companyId: String? = null) {
        val targetUserId = userId ?: tokenStorage.getUserId()
        val targetCompanyId = companyId ?: tokenStorage.getCompanyId()

        if (targetUserId.isNullOrBlank() || targetCompanyId.isNullOrBlank()) {
            return
        }

        val uniqueWorkName = "order_sync_${targetUserId}_${targetCompanyId}"
        val syncRequest = OneTimeWorkRequestBuilder<OrderSyncWorker>()
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(androidx.work.NetworkType.CONNECTED).build())
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                10,
                TimeUnit.SECONDS
            )
            .setInputData(
                workDataOf(
                    OrderSyncWorker.KEY_USER_ID to targetUserId,
                    OrderSyncWorker.KEY_COMPANY_ID to targetCompanyId
                )
            )
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            uniqueWorkName,
            ExistingWorkPolicy.KEEP,
            syncRequest
        )
        val periodic = androidx.work.PeriodicWorkRequestBuilder<OrderSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(androidx.work.Constraints.Builder().setRequiredNetworkType(androidx.work.NetworkType.CONNECTED).build())
            .setInputData(workDataOf(OrderSyncWorker.KEY_USER_ID to targetUserId, OrderSyncWorker.KEY_COMPANY_ID to targetCompanyId))
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("${uniqueWorkName}_recovery", androidx.work.ExistingPeriodicWorkPolicy.KEEP, periodic)
    }
}
