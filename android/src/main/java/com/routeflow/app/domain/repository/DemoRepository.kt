package com.routeflow.app.domain.repository

interface DemoRepository {
    suspend fun seedDemoData()
    suspend fun resetDemoData()
    suspend fun isDemoDataSeeded(): Boolean
}
