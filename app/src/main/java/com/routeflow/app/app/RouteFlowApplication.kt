package com.routeflow.app.app

import android.app.Application
import com.routeflow.app.data.repository.DemoInitializer
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class RouteFlowApplication : Application() {
    @Inject lateinit var demoInitializer: DemoInitializer

    override fun onCreate() {
        super.onCreate()
        demoInitializer.initialize()
    }
}
