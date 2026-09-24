package com.routeflow.app.core.security

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
open class TokenStorage @Inject constructor(
    @ApplicationContext context: Context
) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val sharedPreferences = EncryptedSharedPreferences.create(
        context,
        "secure_tokens",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    open fun saveTokens(accessToken: String, refreshToken: String) {
        sharedPreferences.edit()
            .putString("access_token", accessToken)
            .putString("refresh_token", refreshToken)
            .apply()
    }

    open fun saveUser(id: String, name: String, role: String, companyId: String) {
        sharedPreferences.edit()
            .putString("user_id", id)
            .putString("user_name", name)
            .putString("user_role", role)
            .putString("company_id", companyId)
            .apply()
    }

    open fun getAccessToken(): String? = sharedPreferences.getString("access_token", null)
    open fun getRefreshToken(): String? = sharedPreferences.getString("refresh_token", null)
    open fun getUserId(): String? = sharedPreferences.getString("user_id", null)
    open fun getUserName(): String? = sharedPreferences.getString("user_name", null)
    open fun getUserRole(): String? = sharedPreferences.getString("user_role", null)
    open fun getCompanyId(): String? = sharedPreferences.getString("company_id", null)

    open fun clear() {
        sharedPreferences.edit().clear().apply()
    }
}
