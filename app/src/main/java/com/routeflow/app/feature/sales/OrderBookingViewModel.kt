package com.routeflow.app.feature.sales

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.OrderDao
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

data class OrderBookingState(
    val products: List<ProductItemState> = emptyList(),
    val allProductsForCart: List<Product> = emptyList(), // Added to calculate total correctly
    val searchQuery: String = "",
    val selectedCategory: String? = null,
    val cart: Map<String, Int> = emptyMap(), // ProductId to Quantity
    val isSubmitting: Boolean = false,
    val orderSubmittedId: String? = null,
    val isLoading: Boolean = false
) {
    val cartTotalPaise: Long
        get() = allProductsForCart.sumOf { product ->
            val qty = cart[product.id] ?: 0
            qty * product.pricePaise
        }

    val categories: List<String>
        get() = allProductsForCart.map { it.category }.distinct()
}

data class ProductItemState(
    val product: Product,
    val freeQuantity: Int = 0
)

@HiltViewModel
class OrderBookingViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val productRepository: ProductRepository,
    private val orderRepository: OrderRepository
) : ViewModel() {

    private val retailerId: String = checkNotNull(savedStateHandle["retailerId"])

    private val _searchQuery = MutableStateFlow("")
    private val _selectedCategory = MutableStateFlow<String?>(null)
    private val _cart = MutableStateFlow<Map<String, Int>>(emptyMap())
    private val _isSubmitting = MutableStateFlow(false)
    private val _orderSubmittedId = MutableStateFlow<String?>(null)

    // Source of truth for products to avoid cart calculation bugs when filtering
    private val allProducts = productRepository.getAllProducts()
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val state: StateFlow<OrderBookingState> = combine(
        allProducts,
        _searchQuery,
        _selectedCategory,
        _cart,
        combine(_isSubmitting, _orderSubmittedId) { isSubmitting, submittedId -> isSubmitting to submittedId }
    ) { products, search, category, cart, extra ->
        val (isSubmitting, submittedId) = extra
        
        // Map products to their UI state including promotion logic
        val mappedProducts = products.map { product ->
            val qty = cart[product.id] ?: 0
            val freeQty = if (product.name == "Premium Tea") qty / 10 else 0
            ProductItemState(product, freeQty)
        }

        // Filter only for the list display
        val filtered = mappedProducts.filter {
            it.product.name.contains(search, ignoreCase = true) &&
                    (category == null || it.product.category == category)
        }

        OrderBookingState(
            products = filtered,
            allProductsForCart = products,
            searchQuery = search,
            selectedCategory = category,
            cart = cart,
            isSubmitting = isSubmitting,
            orderSubmittedId = submittedId
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OrderBookingState(isLoading = true)
    )

    fun updateSearch(query: String) {
        _searchQuery.value = query
    }

    fun selectCategory(category: String?) {
        _selectedCategory.value = category
    }

    fun updateQuantity(productId: String, delta: Int) {
        _cart.update { current ->
            val currentQty = current[productId] ?: 0
            val newQty = (currentQty + delta).coerceAtLeast(0)
            
            val product = allProducts.value.find { it.id == productId }
            if (product != null && newQty > product.stockQuantity) {
                return@update current
            }

            if (newQty == 0) current - productId
            else current + (productId to newQty)
        }
    }

    fun submitOrder() {
        val currentCart = _cart.value
        if (currentCart.isEmpty()) return
        
        viewModelScope.launch {
            val employeeId = sessionRepository.activeEmployee.value?.id ?: return@launch
            _isSubmitting.value = true
            
            val orderId = "ORD-${System.currentTimeMillis().toString().takeLast(6)}"
            val now = System.currentTimeMillis()
            
            var totalAmount: Long = 0
            val orderItems = currentCart.map { (productId, quantity) ->
                val product = allProducts.value.find { it.id == productId }!!
                val freeQty = if (product.name == "Premium Tea") quantity / 10 else 0
                totalAmount += quantity * product.pricePaise
                
                OrderItemEntity(
                    id = UUID.randomUUID().toString(),
                    orderId = orderId,
                    productId = productId,
                    quantity = quantity,
                    freeQuantity = freeQty,
                    pricePaiseAtTime = product.pricePaise
                )
            }
            
            val order = OrderEntity(
                id = orderId,
                retailerId = retailerId,
                employeeId = employeeId,
                status = "SUBMITTED",
                totalAmountPaise = totalAmount,
                createdAt = now,
                updatedAt = now
            )
            
            orderRepository.createOrder(order, orderItems)
            _orderSubmittedId.value = orderId
            _isSubmitting.value = false
        }
    }
}
