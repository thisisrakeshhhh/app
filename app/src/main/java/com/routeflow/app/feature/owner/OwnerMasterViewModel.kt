package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.BeatDto
import com.routeflow.app.core.network.dto.CreateBeatRequest
import com.routeflow.app.core.network.dto.CreateEmployeeRequest
import com.routeflow.app.core.network.dto.CreateProductRequest
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.core.network.dto.EmployeeDto
import com.routeflow.app.core.network.dto.StockAdjustmentRequest
import com.routeflow.app.core.network.dto.UpdateProductRequest
import com.routeflow.app.core.network.dto.UpdateRetailerRequest
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.BeatRepository
import com.routeflow.app.domain.repository.EmployeeRepository
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
import javax.inject.Inject

data class OwnerMasterState(
    val products: List<Product> = emptyList(),
    val retailers: List<Retailer> = emptyList(),
    val employees: List<EmployeeDto> = emptyList(),
    val beats: List<BeatDto> = emptyList(),
    val isLoading: Boolean = false,
    val successMessage: String? = null,
    val errorMessage: String? = null
)

@HiltViewModel
class OwnerMasterViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val retailerRepository: RetailerRepository,
    private val employeeRepository: EmployeeRepository,
    private val beatRepository: BeatRepository
) : ViewModel() {

    private val _state = MutableStateFlow(OwnerMasterState())
    private val _employees = MutableStateFlow<List<EmployeeDto>>(emptyList())
    private val _beats = MutableStateFlow<List<BeatDto>>(emptyList())

    val state: StateFlow<OwnerMasterState> = combine(
        _state,
        productRepository.getAllProducts(),
        retailerRepository.getAllRetailers(),
        _employees,
        _beats
    ) { baseState, products, retailers, employees, beats ->
        baseState.copy(
            products = products,
            retailers = retailers,
            employees = employees,
            beats = beats
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = OwnerMasterState(isLoading = true)
    )

    init {
        refreshAll()
    }

    fun refreshAll() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val empResult = employeeRepository.getCompanyEmployees()
            if (empResult.isSuccess) {
                _employees.value = empResult.getOrNull() ?: emptyList()
            }
            val beatResult = beatRepository.getBeats()
            if (beatResult.isSuccess) {
                _beats.value = beatResult.getOrNull() ?: emptyList()
            }
            productRepository.syncProductsFromServer()
            retailerRepository.syncRetailersFromServer()
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun createProduct(
        name: String,
        category: String,
        pricePaise: Long,
        mrpPaise: Long,
        stockQuantity: Int,
        unit: String,
        sku: String?
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = productRepository.createProduct(
                CreateProductRequest(
                    name = name,
                    category = category,
                    pricePaise = pricePaise,
                    mrpPaise = mrpPaise,
                    stockQuantity = stockQuantity,
                    unit = unit,
                    sku = sku
                )
            )
            if (result.isSuccess) {
                _state.update { it.copy(isLoading = false, successMessage = "Product '$name' created successfully") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to create product") }
            }
        }
    }

    fun updateProduct(
        id: String,
        name: String,
        category: String,
        pricePaise: Long,
        mrpPaise: Long,
        unit: String,
        isActive: Boolean
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = productRepository.updateProduct(
                id = id,
                request = UpdateProductRequest(
                    name = name,
                    category = category,
                    pricePaise = pricePaise,
                    mrpPaise = mrpPaise,
                    unit = unit,
                    isActive = isActive
                )
            )
            if (result.isSuccess) {
                _state.update { it.copy(isLoading = false, successMessage = "Product updated successfully") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to update product") }
            }
        }
    }

    fun adjustStock(
        productId: String,
        adjustmentType: String,
        quantity: Int,
        reason: String,
        notes: String
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val changeQuantity = if (adjustmentType == "CORRECTION") quantity else kotlin.math.abs(quantity)
            val result = productRepository.adjustStock(
                StockAdjustmentRequest(
                    productId = productId,
                    changeQuantity = changeQuantity,
                    reason = reason,
                    notes = notes
                )
            )
            if (result.isSuccess) {
                _state.update { it.copy(isLoading = false, successMessage = "Stock updated. New stock: ${result.getOrNull()}") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to adjust stock") }
            }
        }
    }

    fun createRetailer(
        name: String,
        beatId: String,
        address: String,
        contactNumber: String,
        creditLimitPaise: Long,
        paymentTermsDays: Int
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = retailerRepository.createRetailer(
                CreateRetailerRequest(
                    name = name,
                    beatId = beatId,
                    address = address,
                    contactNumber = contactNumber,
                    creditLimitPaise = creditLimitPaise,
                    paymentTermsDays = paymentTermsDays
                )
            )
            if (result.isSuccess) {
                _state.update { it.copy(isLoading = false, successMessage = "Retailer '$name' onboarded successfully") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to onboard retailer") }
            }
        }
    }

    fun updateRetailer(
        id: String,
        creditLimitPaise: Long,
        paymentTermsDays: Int,
        isActive: Boolean
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = retailerRepository.updateRetailer(
                id = id,
                request = UpdateRetailerRequest(
                    creditLimitPaise = creditLimitPaise,
                    paymentTermsDays = paymentTermsDays,
                    isActive = isActive
                )
            )
            if (result.isSuccess) {
                _state.update { it.copy(isLoading = false, successMessage = "Retailer updated successfully") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to update retailer") }
            }
        }
    }

    fun createEmployee(
        username: String,
        name: String,
        role: String,
        passwordHash: String
    ) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = employeeRepository.createEmployee(
                CreateEmployeeRequest(
                    username = username,
                    fullName = name,
                    role = role,
                    password = passwordHash
                )
            )
            if (result.isSuccess) {
                val empResult = employeeRepository.getCompanyEmployees()
                if (empResult.isSuccess) {
                    _employees.value = empResult.getOrNull() ?: emptyList()
                }
                _state.update { it.copy(isLoading = false, successMessage = "Staff member '$name' created") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to onboard staff") }
            }
        }
    }

    fun deactivateEmployee(id: String, name: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = employeeRepository.deactivateEmployee(id)
            if (result.isSuccess) {
                val empResult = employeeRepository.getCompanyEmployees()
                if (empResult.isSuccess) {
                    _employees.value = empResult.getOrNull() ?: emptyList()
                }
                _state.update { it.copy(isLoading = false, successMessage = "Deactivated '$name' - session revoked immediately") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to deactivate staff") }
            }
        }
    }

    fun createBeat(name: String, description: String?, workingDays: List<String>) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = beatRepository.createBeat(
                CreateBeatRequest(name = name, description = description, workingDays = workingDays)
            )
            if (result.isSuccess) {
                val beatResult = beatRepository.getBeats()
                if (beatResult.isSuccess) {
                    _beats.value = beatResult.getOrNull() ?: emptyList()
                }
                _state.update { it.copy(isLoading = false, successMessage = "Beat '$name' created") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to create beat") }
            }
        }
    }

    fun assignBeat(beatId: String, userId: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = beatRepository.assignBeat(beatId, userId)
            if (result.isSuccess) {
                val beatResult = beatRepository.getBeats()
                if (beatResult.isSuccess) {
                    _beats.value = beatResult.getOrNull() ?: emptyList()
                }
                val empResult = employeeRepository.getCompanyEmployees()
                if (empResult.isSuccess) {
                    _employees.value = empResult.getOrNull() ?: emptyList()
                }
                _state.update { it.copy(isLoading = false, successMessage = "Salesperson assigned to beat") }
            } else {
                _state.update { it.copy(isLoading = false, errorMessage = result.exceptionOrNull()?.message ?: "Failed to assign beat") }
            }
        }
    }

    fun clearMessages() {
        _state.update { it.copy(successMessage = null, errorMessage = null) }
    }
}
