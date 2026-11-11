package com.routeflow.app.domain.model

import com.routeflow.app.R

enum class EmployeeRole(val label: String, val labelRes: Int) {
    OWNER("Business Owner", R.string.role_owner),
    ADMIN("Admin / Team Leader", R.string.role_admin),
    SALESPERSON("Salesperson", R.string.role_salesperson),
    WAREHOUSE_MANAGER("Warehouse Manager", R.string.role_warehouse),
    DELIVERY_EXECUTIVE("Delivery Executive", R.string.role_delivery),
}

