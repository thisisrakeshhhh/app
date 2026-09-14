package com.routeflow.app.navigation

import com.routeflow.app.domain.model.EmployeeRole
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class RoleDestinationTest(
    private val role: EmployeeRole,
    private val expectedRoute: String,
) {
    @Test
    fun employeeRoleOpensItsOwnWorkspace() {
        assertEquals(expectedRoute, RoleDestination.forRole(role).route)
    }

    companion object {
        @JvmStatic
        @Parameterized.Parameters(name = "{0} opens {1}")
        fun cases(): List<Array<Any>> = listOf(
            arrayOf(EmployeeRole.OWNER, "home/owner"),
            arrayOf(EmployeeRole.SALESPERSON, "home/sales"),
            arrayOf(EmployeeRole.WAREHOUSE_MANAGER, "home/warehouse"),
            arrayOf(EmployeeRole.DELIVERY_EXECUTIVE, "home/delivery"),
        )
    }
}
