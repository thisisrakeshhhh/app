package com.routeflow.app.app

import com.routeflow.app.BuildConfig
import com.routeflow.app.core.network.AuthInterceptor
import com.routeflow.app.core.network.api.RouteFlowApi
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor
    ): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BASIC
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }
        val failoverInterceptor = okhttp3.Interceptor { chain ->
            val request = chain.request()
            try {
                chain.proceed(request)
            } catch (e: java.io.IOException) {
                val url = request.url
                // If local dev server (127.0.0.1:8787) is unreachable, seamlessly fall back to deployed Cloudflare staging
                if (url.host == "127.0.0.1" && url.port == 8787) {
                    val fallbackUrl = url.newBuilder()
                        .scheme("https")
                        .host("routeflow-api-staging.thisisrakesh21.workers.dev")
                        .port(443)
                        .build()
                    val fallbackRequest = request.newBuilder()
                        .url(fallbackUrl)
                        .build()
                    chain.proceed(fallbackRequest)
                } else {
                    throw e
                }
            }
        }
        return OkHttpClient.Builder()
            .addInterceptor(failoverInterceptor)
            .addInterceptor(authInterceptor)
            .addInterceptor(logging)
            .connectTimeout(5, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient, json: Json): Retrofit {
        val contentType = "application/json".toMediaType()
        // URL selection:
        //   staging build (DEBUG + STAGING_MODE=true)  → explicit staging HTTPS URL from BuildConfig
        //   normal debug build                         → localhost tunnel (adb reverse tcp:8787)
        //   release build                              → production URL (to be updated when domain is registered)
        val baseUrl = when {
            BuildConfig.DEBUG && BuildConfig.STAGING_MODE ->
                BuildConfig.STAGING_API_BASE_URL
            BuildConfig.DEBUG ->
                "http://127.0.0.1:8787/"
            else ->
                "https://api.routeflow.com/"
        }
        return Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory(contentType))
            .build()
    }

    @Provides
    @Singleton
    fun provideRouteFlowApi(retrofit: Retrofit): RouteFlowApi {
        return retrofit.create(RouteFlowApi::class.java)
    }
}
