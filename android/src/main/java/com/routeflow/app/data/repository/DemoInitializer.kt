package com.routeflow.app.data.repository

import com.routeflow.app.domain.repository.DemoRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DemoInitializer @Inject constructor(
    private val demoRepository: DemoRepository
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun initialize() {
        scope.launch {
            if (!demoRepository.isDemoDataSeeded()) {
                demoRepository.seedDemoData()
            }
        }
    }
}
