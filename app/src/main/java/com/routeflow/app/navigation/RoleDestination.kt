package com.routeflow.app.navigation

import com.routeflow.app.domain.model.EmployeeRole

/** Exhaustive routing; adding a role requires an explicit destination. Not authorization. */
enum class RoleDestination(val route: String) {
    OWNER("home/owner"),
    SALES("home/sales"),
    WAREHOUSE("home/warehouse"),
    DELIVERY("home/delivery");

    companion object {
        fun forRole(role: EmployeeRole): RoleDestination = when (role) {
            EmployeeRole.OWNER -> OWNER
            EmployeeRole.SALESPERSON -> SALES
            EmployeeRole.WAREHOUSE_MANAGER -> WAREHOUSE
            EmployeeRole.DELIVERY_EXECUTIVE -> DELIVERY
        }
    }
}
