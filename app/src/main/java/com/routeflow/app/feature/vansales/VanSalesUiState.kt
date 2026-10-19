package com.routeflow.app.feature.vansales

import com.routeflow.app.core.network.dto.TripDetailDto
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.model.EmployeeRole
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.model.Retailer

/**
 * UI State for Android Van-Sales Foundation.
 * Marked: Source corrected — not runtime-verified.
 */
data class VehicleStockItem(
    val product: Product,
    val vanStockQuantity: Int,
    val selectedQuantity: Int = 0
)

data class VanSalesUiState(
    val isLoading: Boolean = false,
    val activeEmployee: Employee? = null,
    val hasRolePermission: Boolean = false,
    val activeTrip: TripDetailDto? = null,
    val availableTrips: List<TripDetailDto> = emptyList(),
    val isTripMissing: Boolean = false,
    val assignedRetailers: List<Retailer> = emptyList(),
    val selectedRetailer: Retailer? = null,
    val searchQuery: String = "",
    val selectedCategory: String? = null,
    val products: List<VehicleStockItem> = emptyList(),
    val allProductsForCart: List<Product> = emptyList(),
    val cart: Map<String, Int> = emptyMap(),
    val paymentMethod: String = "CASH", // CASH, UPI, CREDIT
    val isProvisional: Boolean = false,
    val notes: String = "",
    val creditOverrideReason: String = "",
    val creditOverridePaise: Long? = null,
    val isSubmitting: Boolean = false,
    val submissionOrderId: String? = null,
    val submissionStatus: String? = null, // DELIVERED, SAVED_OFFLINE, SUBMITTED, NEEDS_ATTENTION, FAILED
    val submissionMessage: String? = null,
    val errorMessage: String? = null
) {
    val cartSubtotalPaise: Long
        get() = allProductsForCart.sumOf { product ->
            val qty = cart[product.id] ?: 0
            qty * product.pricePaise
        }

    /**
     * Estimated GST calculation (18% FMCG baseline rate).
     * Explicitly marked as a provisional non-authoritative client estimate.
     */
    val cartGstEstimatePaise: Long
        get() = (cartSubtotalPaise * 18L) / 100L

    val cartTotalEstimatePaise: Long
        get() = cartSubtotalPaise + cartGstEstimatePaise

    val cartTotalUnits: Int
        get() = cart.values.sum()

    val isCartEmpty: Boolean
        get() = cart.isEmpty() || cartTotalUnits == 0

    val categories: List<String>
        get() = allProductsForCart.map { it.category }.distinct()

    val isCreditLimitExceeded: Boolean
        get() {
            val retailer = selectedRetailer ?: return false
            if (paymentMethod != "CREDIT") return false
            return (retailer.outstandingAmountPaise + cartTotalEstimatePaise) > retailer.creditLimitPaise
        }

    val isCreditNearLimit: Boolean
        get() {
            val retailer = selectedRetailer ?: return false
            if (paymentMethod != "CREDIT" || isCreditLimitExceeded) return false
            val remaining = retailer.creditLimitPaise - retailer.outstandingAmountPaise
            return remaining > 0 && cartTotalEstimatePaise >= (remaining * 80L) / 100L
        }

    val canSubmit: Boolean
        get() = hasRolePermission && !isTripMissing && selectedRetailer != null && !isCartEmpty && !isSubmitting
}
