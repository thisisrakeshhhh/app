package com.routeflow.app.feature.warehouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.ProductDao
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class WarehouseHomeState(
    val approvedCount: Int = 0,
    val pickingCount: Int = 0,
    val packedCount: Int = 0,
    val lowStockCount: Int = 0,
    val isLoading: Boolean = false
)

@HiltViewModel
class WarehouseViewModel @Inject constructor(
    private val orderDao: OrderDao,
    private val productDao: ProductDao
) : ViewModel() {

    val state: StateFlow<WarehouseHomeState> = combine(
        orderDao.getAllOrders(),
        productDao.getAllProducts()
    ) { orders, products ->
        WarehouseHomeState(
            approvedCount = orders.count { it.status == "APPROVED" },
            pickingCount = orders.count { it.status == "PICKING" },
            packedCount = orders.count { it.status == "PACKED" },
            lowStockCount = products.count { it.stockQuantity < 10 }
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = WarehouseHomeState(isLoading = true)
    )
}
