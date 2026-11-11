package com.routeflow.app.core.design.map

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class RouteFlowMapLibreControllerTest {

    @Test
    fun controller_initialStateIsNotReady() {
        val controller = RouteFlowMapLibreController()
        assertFalse(controller.isReady)
        assertNull(controller.mapInstance)
    }

    @Test
    fun controller_methodsAreSafeWhenMapInstanceIsNull() {
        val controller = RouteFlowMapLibreController()
        // Must not throw NullPointerException or crash when map is not yet attached
        controller.zoomIn()
        controller.zoomOut()
    }
}
