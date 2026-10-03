package com.routeflow.app.feature.sales

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.dao.StockCheckDao
import com.routeflow.app.core.database.entity.StockCheckEntity
import com.routeflow.app.core.network.dto.StockCheckDto
import com.routeflow.app.data.repository.DurableFieldRepository
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
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

data class ProductStockAuditInput(
    val observedQuantity: Int = 0,
    val suggestedQuantity: Int = 0,
    val notes: String = ""
)

data class StockCheckUiState(
    val retailer: Retailer? = null,
    val products: List<Product> = emptyList(),
    val auditInputs: Map<String, ProductStockAuditInput> = emptyMap(),
    val recentChecks: List<StockCheckEntity> = emptyList(),
    val isSaving: Boolean = false,
    val saveSuccess: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class StockCheckViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val retailerRepository: RetailerRepository,
    private val productRepository: ProductRepository,
    private val durableFieldRepository: DurableFieldRepository,
    private val stockCheckDao: StockCheckDao
) : ViewModel() {

    private val retailerId: String = checkNotNull(savedStateHandle["retailerId"])
    private val _inputs = MutableStateFlow<Map<String, ProductStockAuditInput>>(emptyMap())
    private val _status = MutableStateFlow<Pair<Boolean, String?>>(false to null)
    private val _saveSuccess = MutableStateFlow(false)

    val state: StateFlow<StockCheckUiState> = combine(
        retailerRepository.getRetailerById(retailerId),
        productRepository.getAllProducts(),
        stockCheckDao.getChecksForRetailer(retailerId),
        _inputs,
        _status
    ) { retailer, products, checks, inputs, statusPair ->
        StockCheckUiState(
            retailer = retailer,
            products = products,
            auditInputs = inputs,
            recentChecks = checks,
            isSaving = statusPair.first,
            saveSuccess = _saveSuccess.value,
            errorMessage = statusPair.second
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = StockCheckUiState()
    )

    fun onQuantityChanged(productId: String, quantity: Int) {
        val current = _inputs.value[productId] ?: ProductStockAuditInput()
        val safeQty = quantity.coerceAtLeast(0)
        _inputs.update {
            it + (productId to current.copy(
                observedQuantity = safeQty,
                suggestedQuantity = if (current.suggestedQuantity == 0) (safeQty * 2).coerceAtLeast(6) else current.suggestedQuantity
            ))
        }
    }

    fun onSuggestedQuantityChanged(productId: String, quantity: Int) {
        val current = _inputs.value[productId] ?: ProductStockAuditInput()
        _inputs.update {
            it + (productId to current.copy(suggestedQuantity = quantity.coerceAtLeast(0)))
        }
    }

    fun onNotesChanged(productId: String, notes: String) {
        val current = _inputs.value[productId] ?: ProductStockAuditInput()
        _inputs.update {
            it + (productId to current.copy(notes = notes))
        }
    }

    fun saveStockCheck(productId: String, productName: String) {
        val input = _inputs.value[productId] ?: ProductStockAuditInput()
        viewModelScope.launch {
            _status.update { true to null }
            try {
                val checkId = UUID.randomUUID().toString()
                val dto = StockCheckDto(
                    idempotencyKey = "sc_${checkId}",
                    id = checkId,
                    retailerId = retailerId,
                    productId = productId,
                    quantity = input.observedQuantity
                )
                durableFieldRepository.stockCheck(
                    request = dto,
                    productName = productName,
                    suggestedQty = input.suggestedQuantity,
                    notes = input.notes
                )
                _saveSuccess.update { true }
                _status.update { false to null }
            } catch (e: Exception) {
                _status.update { false to (e.message ?: "Failed to record stock audit") }
            }
        }
    }

    fun dismissSuccess() {
        _saveSuccess.update { false }
    }

    fun clearError() {
        _status.update { false to null }
    }
}
