package com.routeflow.app.app

import com.routeflow.app.core.network.RFSessionInterceptor
import com.routeflow.app.core.network.api.RouteFlowApi
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(
        sessionInterceptor: RFSessionInterceptor
    ): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        return OkHttpClient.Builder()
            .addInterceptor(sessionInterceptor)
            .addInterceptor(logging)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl("http://10.0.2.2:8787/") 
            .client(okHttpClient)
            .build()
    }

    @Provides
    @Singleton
    fun provideRouteFlowApi(retrofit: Retrofit): RouteFlowApi {
        return retrofit.create(RouteFlowApi::class.java)
    }
}
