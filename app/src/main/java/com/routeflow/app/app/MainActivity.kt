package com.routeflow.app.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Modifier
import com.routeflow.app.core.design.RouteFlowTheme
import com.routeflow.app.feature.auth.DemoLoginViewModel
import com.routeflow.app.navigation.RouteFlowApp
import com.routeflow.app.core.security.TokenStorage
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val demoViewModel: DemoLoginViewModel by viewModels()
    @Inject lateinit var tokenStorage: TokenStorage

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            RouteFlowTheme {
                RouteFlowApp(
                    demoState = demoViewModel.state.collectAsStateWithLifecycle().value,
                    onDemoLogout = demoViewModel::logout,
                    onToggleReset = demoViewModel::toggleResetDialog,
                    onConfirmReset = demoViewModel::resetDemo,
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val userId = tokenStorage.getUserId()
        val companyId = tokenStorage.getCompanyId()
        if (!userId.isNullOrBlank() && !companyId.isNullOrBlank()) {
            val syncRequest = androidx.work.OneTimeWorkRequestBuilder<com.routeflow.app.data.sync.OrderSyncWorker>()
                .setInputData(
                    androidx.work.workDataOf(
                        com.routeflow.app.data.sync.OrderSyncWorker.KEY_USER_ID to userId,
                        com.routeflow.app.data.sync.OrderSyncWorker.KEY_COMPANY_ID to companyId
                    )
                )
                .build()
            androidx.work.WorkManager.getInstance(this).enqueueUniqueWork(
                "order_sync_${userId}_${companyId}",
                androidx.work.ExistingWorkPolicy.REPLACE,
                syncRequest
            )
        }
    }
}
