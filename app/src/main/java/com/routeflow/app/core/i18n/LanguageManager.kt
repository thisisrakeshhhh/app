package com.routeflow.app.core.i18n

import android.app.LocaleManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LanguageManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("rf_language_prefs", Context.MODE_PRIVATE)
    private val _currentLanguage = MutableStateFlow(prefs.getString(KEY_LANGUAGE, LANG_EN) ?: LANG_EN)
    val currentLanguage: StateFlow<String> = _currentLanguage.asStateFlow()

    fun setLanguage(langCode: String) {
        val normalized = if (langCode == LANG_HI) LANG_HI else LANG_EN
        prefs.edit().putString(KEY_LANGUAGE, normalized).apply()
        _currentLanguage.value = normalized

        // Update system/app locale if supported
        applySystemLocale(context, normalized)
    }

    fun getConfiguration(): Configuration {
        val locale = Locale(_currentLanguage.value)
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return config
    }

    companion object {
        const val LANG_EN = "en"
        const val LANG_HI = "hi"
        private const val KEY_LANGUAGE = "selected_language"

        fun applySystemLocale(context: Context, langCode: String) {
            try {
                val locale = Locale(langCode)
                Locale.setDefault(locale)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val localeManager = context.getSystemService(LocaleManager::class.java)
                    localeManager?.applicationLocales = LocaleList(locale)
                } else {
                    val config = Configuration(context.resources.configuration)
                    config.setLocale(locale)
                    @Suppress("DEPRECATION")
                    context.resources.updateConfiguration(config, context.resources.displayMetrics)
                }
            } catch (_: Exception) {
                // Ignore if framework locale manager is restricted in environment
            }
        }
    }
}
