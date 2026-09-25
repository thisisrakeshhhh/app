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
    @Inject lateinit var syncManager: com.routeflow.app.data.sync.SyncManager

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
        syncManager.scheduleSync()
    }
}
