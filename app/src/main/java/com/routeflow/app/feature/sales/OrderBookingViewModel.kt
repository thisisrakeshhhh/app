package com.routeflow.app.feature.sales

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.network.dto.CreateProductRequest
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

data class OrderBookingState(
    val products: List<ProductItemState> = emptyList(),
    val allProductsForCart: List<Product> = emptyList(),
    val searchQuery: String = "",
    val selectedCategory: String? = null,
    val cart: Map<String, Int> = emptyMap(),
    val isSubmitting: Boolean = false,
    val orderSubmittedId: String? = null,
    val isLoading: Boolean = false,
    val assignedRetailers: List<Retailer> = emptyList(),
    val selectedRetailer: Retailer? = null,
    val isRetailerSelectionRequired: Boolean = false
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
    private val orderRepository: OrderRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val rawRetailerId: String = savedStateHandle["retailerId"] ?: "all"

    private val _searchQuery = MutableStateFlow("")
    private val _selectedCategory = MutableStateFlow<String?>(null)
    private val _cart = MutableStateFlow<Map<String, Int>>(emptyMap())
    private val _isSubmitting = MutableStateFlow(false)
    private val _orderSubmittedId = MutableStateFlow<String?>(null)
    private val _selectedRetailerId = MutableStateFlow(if (rawRetailerId != "all") rawRetailerId else null)

    private val allProducts = productRepository.getAllProducts()
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    private val filterState = combine(_searchQuery, _selectedCategory) { s, c -> s to c }
    private val submissionState = combine(_cart, _isSubmitting, _orderSubmittedId) { cart, isSubmitting, submittedId ->
        Triple(cart, isSubmitting, submittedId)
    }
    private val retailerState = combine(retailerRepository.getAllRetailers(), _selectedRetailerId) { retailers, selId ->
        retailers to selId
    }

    val state: StateFlow<OrderBookingState> = combine(
        allProducts,
        retailerState,
        filterState,
        submissionState
    ) { products, (retailers, selectedRetailerId), (search, category), (cart, isSubmitting, submittedId) ->
        // Auto-select first retailer if not specified and coming from general tab
        val activeRetailerId = selectedRetailerId ?: (if (rawRetailerId == "all") retailers.firstOrNull()?.id else null)
        val selectedRetailer = retailers.find { it.id == activeRetailerId }

        val mappedProducts = products.map { product ->
            val qty = cart[product.id] ?: 0
            val freeQty = if (product.name == "Premium Tea") qty / 10 else 0
            ProductItemState(product, freeQty)
        }

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
            orderSubmittedId = submittedId,
            assignedRetailers = retailers,
            selectedRetailer = selectedRetailer,
            isRetailerSelectionRequired = rawRetailerId == "all"
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OrderBookingState(isLoading = true)
    )

    fun selectRetailer(retailerId: String) {
        _selectedRetailerId.value = retailerId
    }

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

        val targetRetailerId = state.value.selectedRetailer?.id
            ?: if (rawRetailerId != "all") rawRetailerId else null

        if (targetRetailerId.isNullOrBlank()) return

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
                retailerId = targetRetailerId,
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

    fun addNewProduct(
        name: String,
        category: String,
        unit: String,
        priceRupees: Double,
        stockQuantity: Int
    ) {
        viewModelScope.launch {
            val req = CreateProductRequest(
                id = "PROD-${System.currentTimeMillis().toString().takeLast(6)}",
                name = name.trim(),
                category = category.trim().ifEmpty { "General" },
                pricePaise = (priceRupees * 100).toLong(),
                stockQuantity = stockQuantity,
                unit = unit.trim().ifEmpty { "Unit" }
            )
            productRepository.createProduct(req)
        }
    }
}
