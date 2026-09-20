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
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val demoViewModel: DemoLoginViewModel by viewModels()

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
}
