package com.routeflow.app.core.design

import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import com.routeflow.app.R
import com.routeflow.app.domain.model.EmployeeRole

@Composable
fun RoleIcon(role: EmployeeRole, modifier: Modifier = Modifier) {
    val resource = when (role) {
        EmployeeRole.OWNER -> R.drawable.ic_owner
        EmployeeRole.SALESPERSON -> R.drawable.ic_sales
        EmployeeRole.WAREHOUSE_MANAGER -> R.drawable.ic_warehouse
        EmployeeRole.DELIVERY_EXECUTIVE -> R.drawable.ic_delivery
    }
    Icon(painterResource(resource), contentDescription = null, modifier = modifier)
}
