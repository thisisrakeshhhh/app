package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.network.dto.DailyVisitDto
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.CollectionRepository
import com.routeflow.app.domain.repository.FieldOperationsRepository
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OwnerFieldActivityState(
    val visits: List<DailyVisitDto> = emptyList(),
    val orders: List<OrderEntity> = emptyList(),
    val collections: List<CollectionRecordEntity> = emptyList(),
    val products: List<Product> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class OwnerFieldActivityViewModel @Inject constructor(
    private val fieldOperationsRepository: FieldOperationsRepository,
    private val orderRepository: OrderRepository,
    private val collectionRepository: CollectionRepository,
    private val productRepository: ProductRepository
) : ViewModel() {

    private val _visits = MutableStateFlow<List<DailyVisitDto>>(emptyList())
    private val _status = MutableStateFlow<Pair<Boolean, String?>>(true to null)

    val state: StateFlow<OwnerFieldActivityState> = combine(
        _visits,
        orderRepository.getAllOrders(),
        collectionRepository.observeCollections(),
        productRepository.getAllProducts(),
        _status
    ) { visits, orders, collections, products, status ->
        OwnerFieldActivityState(
            visits = visits,
            orders = orders,
            collections = collections,
            products = products,
            isLoading = status.first,
            errorMessage = status.second
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerFieldActivityState(isLoading = true)
    )

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _status.value = true to null
            val result = fieldOperationsRepository.getDailyVisits()
            if (result.isSuccess) {
                _visits.value = result.getOrNull() ?: emptyList()
                _status.value = false to null
            } else {
                _status.value = false to (result.exceptionOrNull()?.message ?: "Failed to load field activity")
            }
        }
    }
}
