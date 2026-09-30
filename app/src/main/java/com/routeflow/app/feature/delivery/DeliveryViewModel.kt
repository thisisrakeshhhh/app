package com.routeflow.app.feature.delivery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.network.dto.DeliveryItemCompletionRequest
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DeliveryHomeState(
    val assignedCount: Int = 0,
    val completedCount: Int = 0,
    val paymentsCollectedPaise: Long = 0,
    val isLoading: Boolean = false
)

data class DeliveryItemState(
    val order: OrderEntity,
    val retailerName: String,
    val retailerAddress: String
)

data class DeliveryDetailState(
    val isLoading: Boolean = false,
    val isOtpLoading: Boolean = false,
    val otpSentMessage: String? = null,
    val serverDebugOtp: String? = null,
    val error: String? = null,
    val success: Boolean = false,
    /** null = not yet determined, true = loading from server, false = done (success or failure) */
    val isItemsFetching: Boolean = false,
    /** Set when item fetch fails (e.g. offline). Shown instead of empty item list. */
    val itemsFetchError: String? = null
)

data class DeliveryOrderItemUiModel(
    val productId: String,
    val productName: String,
    val orderedQuantity: Int,
    val freeQuantity: Int,
    val pricePaise: Long
)

@HiltViewModel
class DeliveryViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val retailerRepository: RetailerRepository,
    private val productRepository: ProductRepository
) : ViewModel() {

    private val _detailState = MutableStateFlow(DeliveryDetailState())
    val detailState = _detailState.asStateFlow()

    val state: StateFlow<DeliveryHomeState> = orderRepository.getAllOrders().map { orders ->
        DeliveryHomeState(
            assignedCount = orders.count { it.status == "OUT_FOR_DELIVERY" },
            completedCount = orders.count { it.status == "DELIVERED" || it.status == "PARTIALLY_DELIVERED" },
            paymentsCollectedPaise = 0
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = DeliveryHomeState(isLoading = true)
    )

    val deliveryList: StateFlow<List<DeliveryItemState>> = combine(
        orderRepository.getAllOrders(),
        retailerRepository.getAllRetailers()
    ) { orders, retailers ->
        orders.filter { it.status == "OUT_FOR_DELIVERY" }.map { order ->
            val retailer = retailers.find { it.id == order.retailerId }
            DeliveryItemState(
                order = order,
                retailerName = retailer?.name ?: "Retailer ${order.retailerId}",
                retailerAddress = retailer?.address ?: "Address not available"
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )

    fun getOrderItems(orderId: String): Flow<List<DeliveryOrderItemUiModel>> = combine(
        orderRepository.getItemsForOrder(orderId),
        productRepository.getAllProducts()
    ) { items, products ->
        items.map { item ->
            val product = products.find { it.id == item.productId }
            DeliveryOrderItemUiModel(
                productId = item.productId,
                productName = product?.name ?: "Product ${item.productId}",
                orderedQuantity = item.quantity,
                freeQuantity = item.freeQuantity,
                pricePaise = item.pricePaiseAtTime
            )
        }
    }

    /**
     * Call this when the detail screen opens.
     * If Room has no cached items for [orderId] (order was outside the bounded login
     * pre-fetch), fetches from the server and caches them. The Room Flow in
     * [getOrderItems] then delivers the result. If offline, sets [itemsFetchError]
     * so the UI can show "Details not downloaded — connect to sync."
     */
    fun loadOrderItems(orderId: String) {
        if (_detailState.value.isItemsFetching) return
        viewModelScope.launch {
            // First check Room — if items already cached, nothing to do
            val cached = orderRepository.getItemsForOrder(orderId)
                .stateIn(this, SharingStarted.Eagerly, emptyList()).value
            if (cached.isNotEmpty()) return@launch

            _detailState.update { it.copy(isItemsFetching = true, itemsFetchError = null) }
            val result = orderRepository.fetchAndCacheOrderItems(orderId)
            _detailState.update {
                if (result.isSuccess) {
                    it.copy(isItemsFetching = false)
                } else {
                    it.copy(
                        isItemsFetching = false,
                        itemsFetchError = "Details not downloaded — connect to sync item breakdown."
                    )
                }
            }
        }
    }

    fun requestOtp(orderId: String) {
        if (_detailState.value.isOtpLoading) return
        _detailState.update { it.copy(isOtpLoading = true, error = null, otpSentMessage = null) }
        viewModelScope.launch {
            val result = orderRepository.requestDeliveryOtp(orderId)
            _detailState.update {
                if (result.isSuccess) {
                    val resp = result.getOrNull()
                    it.copy(
                        isOtpLoading = false,
                        otpSentMessage = resp?.message ?: "OTP sent to retailer",
                        serverDebugOtp = resp?.debugOtp
                    )
                } else {
                    it.copy(
                        isOtpLoading = false,
                        error = result.exceptionOrNull()?.message ?: "Failed to request OTP"
                    )
                }
            }
        }
    }

    fun markDelivered(
        orderId: String,
        method: String,
        otp: String,
        recipientName: String,
        items: List<DeliveryItemCompletionRequest>? = null
    ) {
        if (_detailState.value.isLoading) return
        
        _detailState.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            val result = orderRepository.completeDelivery(
                orderId = orderId,
                paymentMethod = method,
                otp = otp,
                recipientName = recipientName,
                items = items
            )
            _detailState.update {
                if (result.isSuccess) {
                    it.copy(isLoading = false, success = true)
                } else {
                    it.copy(isLoading = false, error = result.exceptionOrNull()?.message ?: "Delivery failed")
                }
            }
        }
    }

    fun markDeliveryFailed(
        orderId: String,
        reason: String,
        rescheduledDate: String? = null,
        notes: String? = null
    ) {
        if (_detailState.value.isLoading) return

        _detailState.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            val result = orderRepository.failDelivery(
                orderId = orderId,
                reason = reason,
                rescheduledDate = rescheduledDate,
                notes = notes
            )
            _detailState.update {
                if (result.isSuccess) {
                    it.copy(isLoading = false, success = true)
                } else {
                    it.copy(isLoading = false, error = result.exceptionOrNull()?.message ?: "Failed to record delivery failure")
                }
            }
        }
    }

    fun clearError() {
        _detailState.update { it.copy(error = null) }
    }

    fun resetDetailState() {
        _detailState.value = DeliveryDetailState()
    }
}
