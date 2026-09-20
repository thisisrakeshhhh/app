package com.routeflow.app.core.network

import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Redacts sensitive headers and adds Auth tokens.
 * Placeholders for JWT production integration.
 */
@Singleton
class RFSessionInterceptor @Inject constructor() : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        
        // Placeholder for secure token retrieval from Keystore
        val token = "demo-token" 
        
        val request = original.newBuilder()
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/json")
            .build()
            
        return chain.proceed(request)
    }
}
