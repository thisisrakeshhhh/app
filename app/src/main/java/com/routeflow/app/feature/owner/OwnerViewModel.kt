package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.dao.RetailerDao
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OwnerHomeState(
    val pendingApprovalsCount: Int = 0,
    val deliveredSalesTodayPaise: Long = 0,
    val totalOutstandingPaise: Long = 0,
    val lowStockCount: Int = 0,
    val isLoading: Boolean = false
)

@HiltViewModel
class OwnerViewModel @Inject constructor(
    private val orderDao: OrderDao,
    private val productDao: ProductDao,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<OwnerHomeState> = combine(
        orderDao.getAllOrders().map { orders -> orders.count { it.status == "SUBMITTED" } },
        productDao.getAllProducts().map { products -> products.count { it.stockQuantity < 10 } },
        retailerRepository.getRetailersByBeat("BEAT-04").map { retailers -> retailers.sumOf { it.outstandingAmountPaise } }
    ) { pendingCount, lowStock, totalOutstanding ->
        OwnerHomeState(
            pendingApprovalsCount = pendingCount,
            lowStockCount = lowStock,
            totalOutstandingPaise = totalOutstanding,
            deliveredSalesTodayPaise = 0 // TODO: Real calculation
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerHomeState(isLoading = true)
    )
}
