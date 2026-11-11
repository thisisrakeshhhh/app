package com.routeflow.app.feature.vansales

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.network.dto.TripDetailDto
import com.routeflow.app.domain.model.EmployeeRole
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

/**
 * ViewModel for Android Van-Sales UI Foundation.
 * Enforces role permissions, trip/vehicle context validation,
 * local integer pricing bounds, and stable outbox queuing.
 *
 * Marked: Source corrected — not runtime-verified.
 */
@HiltViewModel
class VanSalesViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val initialRetailerId: String = savedStateHandle["retailerId"] ?: "all"

    private val _searchQuery = MutableStateFlow("")
    private val _selectedCategory = MutableStateFlow<String?>(null)
    private val _cart = MutableStateFlow<Map<String, Int>>(emptyMap())
    private val _paymentMethod = MutableStateFlow("CASH")
    private val _isProvisional = MutableStateFlow(false)
    private val _notes = MutableStateFlow("")
    private val _creditOverrideReason = MutableStateFlow("")
    private val _creditOverridePaise = MutableStateFlow<Long?>(null)

    private val _selectedRetailerId = MutableStateFlow(if (initialRetailerId != "all") initialRetailerId else null)
    private val _activeTrip = MutableStateFlow<TripDetailDto?>(null)
    private val _availableTrips = MutableStateFlow<List<TripDetailDto>>(emptyList())
    private val _isTripLoading = MutableStateFlow(true)

    private val _isSubmitting = MutableStateFlow(false)
    private val _submittedOrderId = MutableStateFlow<String?>(null)
    private val _submissionStatus = MutableStateFlow<String?>(null)
    private val _submissionMessage = MutableStateFlow<String?>(null)
    private val _errorMessage = MutableStateFlow<String?>(null)

    private val allProductsFlow = productRepository.getAllProducts()
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    init {
        loadTripContext()
    }

    fun loadTripContext() {
        viewModelScope.launch {
            _isTripLoading.value = true
            val employee = sessionRepository.activeEmployee.value
            val employeeId = employee?.id

            // Attempt to retrieve active trip for this driver/salesperson
            val activeResult = orderRepository.getActiveTrip(employeeId)
            val currentActiveTrip = activeResult.getOrNull()

            // Also load recent trips to allow selection if needed
            val allTripsResult = orderRepository.getAllTrips("IN_TRANSIT")
            val inTransitTrips = allTripsResult.getOrElse {
                orderRepository.getAllTrips(null).getOrDefault(emptyList())
            }

            _activeTrip.value = currentActiveTrip ?: inTransitTrips.firstOrNull {
                it.status == "IN_TRANSIT" || it.status == "OUT_FOR_DELIVERY" || it.status == "PLANNED"
            }
            _availableTrips.value = inTransitTrips
            _isTripLoading.value = false
        }
    }

    val state: StateFlow<VanSalesUiState> = combine(
        sessionRepository.activeEmployee,
        combine(_activeTrip, _availableTrips, _isTripLoading) { trip, all, loading -> Triple(trip, all, loading) },
        retailerRepository.getAllRetailers(),
        _selectedRetailerId,
        allProductsFlow
    ) { employee, (activeTrip, availableTrips, isTripLoading), retailers, selectedRetailerId, products ->
        // Check fine-grained role capability for van sales
        val hasPermission = when (employee?.role) {
            EmployeeRole.OWNER,
            EmployeeRole.ADMIN,
            EmployeeRole.SALESPERSON,
            EmployeeRole.DELIVERY_EXECUTIVE -> true
            null -> false
            else -> false
        }

        // Auto-select retailer if not specified
        val resolvedRetailerId = selectedRetailerId ?: if (initialRetailerId == "all") retailers.firstOrNull()?.id else null
        val selectedRetailer = retailers.find { it.id == resolvedRetailerId }

        val query = _searchQuery.value
        val category = _selectedCategory.value
        val cart = _cart.value

        // Map stock items: Van stock displays stockQuantity from catalog or allocated load
        val stockItems = products.map { product ->
            val qtyInCart = cart[product.id] ?: 0
            val availableVanStock = (product.stockQuantity - product.reservedQuantity).coerceAtLeast(0)
            VehicleStockItem(
                product = product,
                vanStockQuantity = availableVanStock,
                selectedQuantity = qtyInCart
            )
        }

        val filteredItems = stockItems.filter { item ->
            val matchesQuery = item.product.name.contains(query, ignoreCase = true) ||
                    (item.product.hindiName?.contains(query, ignoreCase = true) == true) ||
                    (item.product.barcode?.contains(query, ignoreCase = true) == true)
            val matchesCategory = category == null || item.product.category == category
            matchesQuery && matchesCategory
        }

        val isTripMissing = !isTripLoading && (activeTrip == null || (activeTrip.status != "IN_TRANSIT" && activeTrip.status != "OUT_FOR_DELIVERY" && activeTrip.status != "PLANNED"))

        VanSalesUiState(
            isLoading = isTripLoading,
            activeEmployee = employee,
            hasRolePermission = hasPermission,
            activeTrip = activeTrip,
            availableTrips = availableTrips,
            isTripMissing = isTripMissing,
            assignedRetailers = retailers,
            selectedRetailer = selectedRetailer,
            searchQuery = query,
            selectedCategory = category,
            products = filteredItems,
            allProductsForCart = products,
            cart = cart,
            paymentMethod = _paymentMethod.value,
            isProvisional = _isProvisional.value,
            notes = _notes.value,
            creditOverrideReason = _creditOverrideReason.value,
            creditOverridePaise = _creditOverridePaise.value,
            isSubmitting = _isSubmitting.value,
            submissionOrderId = _submittedOrderId.value,
            submissionStatus = _submissionStatus.value,
            submissionMessage = _submissionMessage.value,
            errorMessage = _errorMessage.value
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = VanSalesUiState(isLoading = true)
    )

    fun selectRetailer(retailerId: String) {
        _selectedRetailerId.value = retailerId
    }

    fun selectTrip(trip: TripDetailDto) {
        _activeTrip.value = trip
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
            val targetProduct = allProductsFlow.value.find { it.id == productId }
            val availableStock = if (targetProduct != null) {
                (targetProduct.stockQuantity - targetProduct.reservedQuantity).coerceAtLeast(0)
            } else 0

            val newQty = (currentQty + delta).coerceIn(0, availableStock)

            if (newQty <= 0) current - productId
            else current + (productId to newQty)
        }
    }

    fun setQuantity(productId: String, requestedQty: Int) {
        _cart.update { current ->
            val targetProduct = allProductsFlow.value.find { it.id == productId }
            val availableStock = if (targetProduct != null) {
                (targetProduct.stockQuantity - targetProduct.reservedQuantity).coerceAtLeast(0)
            } else 0

            val cleanQty = requestedQty.coerceIn(0, availableStock)

            if (cleanQty <= 0) current - productId
            else current + (productId to cleanQty)
        }
    }

    fun setPaymentMethod(method: String) {
        _paymentMethod.value = method
    }

    fun setProvisional(isProvisional: Boolean) {
        _isProvisional.value = isProvisional
    }

    fun setNotes(notes: String) {
        _notes.value = notes
    }

    fun setCreditOverrideReason(reason: String) {
        _creditOverrideReason.value = reason
    }

    fun clearSubmissionState() {
        _submittedOrderId.value = null
        _submissionStatus.value = null
        _submissionMessage.value = null
        _errorMessage.value = null
    }

    fun resetCart() {
        _cart.value = emptyMap()
        _notes.value = ""
        _creditOverrideReason.value = ""
        _creditOverridePaise.value = null
    }

    fun submitVanSale() {
        val currentState = state.value
        if (!currentState.canSubmit) {
            if (currentState.isTripMissing) {
                _errorMessage.value = "Cannot record van sale: active delivery trip context is required by vehicle stock protocol."
            } else if (currentState.selectedRetailer == null) {
                _errorMessage.value = "Target retailer shop must be selected."
            } else if (currentState.isCartEmpty) {
                _errorMessage.value = "Cart is empty. Add vehicle stock items to proceed."
            }
            return
        }

        val targetRetailer = currentState.selectedRetailer ?: return
        val currentTrip = currentState.activeTrip ?: run {
            _errorMessage.value = "Active delivery trip required."
            return
        }

        val currentCart = _cart.value
        val employee = sessionRepository.activeEmployee.value ?: return

        viewModelScope.launch {
            _isSubmitting.value = true
            _errorMessage.value = null

            val now = System.currentTimeMillis()
            val orderId = "VAN-${now.toString().takeLast(6)}"

            var computedTotalPaise = 0L
            val orderItems = currentCart.mapNotNull { (productId, qty) ->
                val product = allProductsFlow.value.find { it.id == productId } ?: return@mapNotNull null
                computedTotalPaise += (qty * product.pricePaise)
                OrderItemEntity(
                    id = UUID.randomUUID().toString(),
                    orderId = orderId,
                    productId = productId,
                    quantity = qty,
                    freeQuantity = 0,
                    pricePaiseAtTime = product.pricePaise
                )
            }

            if (orderItems.isEmpty()) {
                _isSubmitting.value = false
                _errorMessage.value = "No valid product items in van cart."
                return@launch
            }

            // Estimate GST 18%
            val estimatedTotalWithGst = computedTotalPaise + ((computedTotalPaise * 18L) / 100L)

            val order = OrderEntity(
                id = orderId,
                retailerId = targetRetailer.id,
                employeeId = employee.id,
                status = if (currentState.isProvisional) "SUBMITTED" else "DELIVERED",
                totalAmountPaise = estimatedTotalWithGst,
                createdAt = now,
                updatedAt = now
            )

            val result = orderRepository.submitVanSaleOrder(
                order = order,
                items = orderItems,
                tripId = currentTrip.id,
                paymentMethod = currentState.paymentMethod,
                notes = currentState.notes.ifBlank { null },
                isProvisional = currentState.isProvisional,
                creditOverridePaise = currentState.creditOverridePaise,
                creditOverrideReason = currentState.creditOverrideReason.ifBlank { null }
            )

            result.fold(
                onSuccess = { response ->
                    _submittedOrderId.value = response.orderId
                    _submissionStatus.value = response.status
                    _submissionMessage.value = response.message ?: when (response.status) {
                        "DELIVERED" -> "Van Sale Spot Billed & Stock Deducted! Invoice generated."
                        "SAVED_OFFLINE" -> "Van Sale saved offline in Outbox. Will sync automatically."
                        "SUBMITTED" -> "Provisional van sale order registered."
                        else -> "Sale recorded (${response.status})"
                    }
                    resetCart()
                },
                onFailure = { error ->
                    _errorMessage.value = error.message ?: "Van sale submission failed. Please check stock and credit limits."
                    _submissionStatus.value = "FAILED"
                }
            )

            _isSubmitting.value = false
        }
    }
}
