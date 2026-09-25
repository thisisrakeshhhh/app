package com.routeflow.app.core.network

import com.routeflow.app.core.security.TokenStorage
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenStorage: TokenStorage
) : Interceptor {

    private val refreshLock = Any()

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        val path = originalRequest.url.encodedPath

        // Do not intercept or refresh for auth endpoints
        if (path.contains("/auth/login") || path.contains("/auth/refresh")) {
            return chain.proceed(originalRequest)
        }

        val accessToken = tokenStorage.getAccessToken()
        val authenticatedRequest = if (accessToken != null) {
            originalRequest.newBuilder()
                .header("Authorization", "Bearer $accessToken")
                .build()
        } else {
            originalRequest
        }

        val response = chain.proceed(authenticatedRequest)

        // Handle 401 Unauthorized by attempting a token refresh
        if (response.code == 401) {
            val refreshToken = tokenStorage.getRefreshToken()
            if (!refreshToken.isNullOrBlank()) {
                val newAccessToken = synchronized(refreshLock) {
                    val currentAccessToken = tokenStorage.getAccessToken()
                    // If another thread already refreshed the token, use the updated one
                    if (currentAccessToken != null && currentAccessToken != accessToken) {
                        currentAccessToken
                    } else {
                        try {
                            val refreshClient = OkHttpClient.Builder().build()
                            val refreshUrl = originalRequest.url.newBuilder()
                                .encodedPath("/auth/refresh")
                                .build()
                            val jsonBody = JSONObject().apply {
                                put("refresh_token", refreshToken)
                            }.toString()

                            val refreshRequest = Request.Builder()
                                .url(refreshUrl)
                                .post(jsonBody.toRequestBody("application/json".toMediaType()))
                                .build()

                            refreshClient.newCall(refreshRequest).execute().use { refreshResponse ->
                                if (refreshResponse.isSuccessful) {
                                    val bodyStr = refreshResponse.body?.string() ?: ""
                                    val json = JSONObject(bodyStr)
                                    val refreshedAccess = json.optString("access_token")
                                    val refreshedRefresh = json.optString("refresh_token")
                                    if (refreshedAccess.isNotBlank()) {
                                        tokenStorage.saveTokens(
                                            refreshedAccess,
                                            if (refreshedRefresh.isNotBlank()) refreshedRefresh else refreshToken
                                        )
                                        refreshedAccess
                                    } else {
                                        null
                                    }
                                } else {
                                    null
                                }
                            }
                        } catch (_: Exception) {
                            null
                        }
                    }
                }

                if (newAccessToken != null) {
                    response.close()
                    val retryRequest = originalRequest.newBuilder()
                        .header("Authorization", "Bearer $newAccessToken")
                        .build()
                    return chain.proceed(retryRequest)
                }
            }
        }

        return response
    }
}

