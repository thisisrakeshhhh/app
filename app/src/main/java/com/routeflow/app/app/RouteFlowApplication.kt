package com.routeflow.app.app

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.routeflow.app.data.repository.DemoInitializer
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class RouteFlowApplication : Application(), Configuration.Provider {
    @Inject lateinit var demoInitializer: DemoInitializer
    @Inject lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        demoInitializer.initialize()
    }
}
