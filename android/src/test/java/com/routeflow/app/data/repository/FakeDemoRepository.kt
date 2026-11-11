package com.routeflow.app.data.repository

import com.routeflow.app.domain.repository.DemoRepository

class FakeDemoRepository : DemoRepository {
    var seeded = false
    override suspend fun seedDemoData() { seeded = true }
    override suspend fun resetDemoData() { seeded = true }
    override suspend fun isDemoDataSeeded(): Boolean = seeded
}
