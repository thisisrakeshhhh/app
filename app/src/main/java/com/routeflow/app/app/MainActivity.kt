package com.routeflow.app.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
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
    @Inject lateinit var sessionRepository: com.routeflow.app.domain.repository.SessionRepository
    @Inject lateinit var syncManager: com.routeflow.app.data.sync.SyncManager
    @Inject lateinit var languageManager: com.routeflow.app.core.i18n.LanguageManager

    override fun attachBaseContext(newBase: android.content.Context) {
        val prefs = newBase.getSharedPreferences("rf_language_prefs", android.content.Context.MODE_PRIVATE)
        val lang = prefs.getString("selected_language", "en") ?: "en"
        val locale = java.util.Locale(lang)
        java.util.Locale.setDefault(locale)
        val config = android.content.res.Configuration(newBase.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        val localized = newBase.createConfigurationContext(config)
        super.attachBaseContext(localized)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val currentLang by languageManager.currentLanguage.collectAsStateWithLifecycle()
            val activityContext = androidx.compose.ui.platform.LocalContext.current
            val localizedWrapper = androidx.compose.runtime.remember(currentLang, activityContext) {
                val locale = java.util.Locale(currentLang)
                java.util.Locale.setDefault(locale)
                val config = android.content.res.Configuration(activityContext.resources.configuration).apply {
                    setLocale(locale)
                    setLayoutDirection(locale)
                }
                val confContext = activityContext.createConfigurationContext(config)
                object : android.content.ContextWrapper(activityContext) {
                    override fun getResources(): android.content.res.Resources = confContext.resources
                }
            }
            val realEmployee by sessionRepository.activeEmployee.collectAsStateWithLifecycle()
            val demoState by demoViewModel.state.collectAsStateWithLifecycle()
            val activeEmployee = realEmployee ?: demoState.activeEmployee

            androidx.compose.runtime.CompositionLocalProvider(
                androidx.compose.ui.platform.LocalConfiguration provides localizedWrapper.resources.configuration,
                androidx.compose.ui.platform.LocalContext provides localizedWrapper
            ) {
                RouteFlowTheme {
                    RouteFlowApp(
                        activeEmployee = activeEmployee,
                        demoState = demoState,
                        onDemoLogout = {
                            sessionRepository.logout()
                            demoViewModel.logout()
                        },
                        onToggleReset = demoViewModel::toggleResetDialog,
                        onConfirmReset = demoViewModel::resetDemo,
                        currentLanguage = currentLang,
                        onLanguageChange = { newLang ->
                            languageManager.setLanguage(newLang)
                            recreate()
                        }
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        syncManager.scheduleSync()
    }
}
