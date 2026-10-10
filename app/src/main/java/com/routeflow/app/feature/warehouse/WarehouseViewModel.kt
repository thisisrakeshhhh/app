package com.routeflow.app.feature.warehouse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.CreateDispatchBatchRequest
import com.routeflow.app.core.network.dto.CreateWarehouseBatchRequest
import com.routeflow.app.core.network.dto.DispatchBatchDto
import com.routeflow.app.core.network.dto.InspectWarehouseReturnRequest
import com.routeflow.app.core.network.dto.PickingOrderDto
import com.routeflow.app.core.network.dto.ProductDto
import com.routeflow.app.core.network.dto.StockMovementDto
import com.routeflow.app.core.network.dto.WarehouseBatchDto
import com.routeflow.app.core.network.dto.WarehouseReturnItemDto
import com.routeflow.app.core.network.dto.WarehouseStockItemDto
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.WarehouseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class WarehouseDashboardState(
    val readyToPickCount: Int = 0,
    val packedTodayCount: Int = 0,
    val dispatchBatchesCount: Int = 0,
    val lowStockCount: Int = 0,
    val nearExpiryCount: Int = 0,
    val damagedStockCount: Int = 0,
    val pendingReturnsCount: Int = 0,
    val isLoading: Boolean = false
)

data class WarehouseStockUiState(
    val products: List<WarehouseStockItemDto> = emptyList(),
    val searchQuery: String = "",
    val activeFilter: String = "ALL", // ALL, LOW_STOCK, OUT_OF_STOCK, NEAR_EXPIRY, DAMAGED
    val movements: List<StockMovementDto> = emptyList(),
    val scannedProduct: ProductDto? = null,
    val isLoading: Boolean = false,
    val isScanning: Boolean = false
)

data class WarehouseDispatchUiState(
    val dispatchBatches: List<DispatchBatchDto> = emptyList(),
    val packedOrders: List<PickingOrderDto> = emptyList(),
    val deliveryExecutives: List<com.routeflow.app.core.network.dto.DeliveryExecutiveDto> = emptyList(),
    val isLoading: Boolean = false
)

sealed interface WarehouseUiEvent {
    data class Success(val message: String) : WarehouseUiEvent
    data class Error(val message: String) : WarehouseUiEvent
    data class BarcodeFound(val product: ProductDto) : WarehouseUiEvent
}

@HiltViewModel
class WarehouseViewModel @Inject constructor(
    private val warehouseRepository: WarehouseRepository,
    private val orderRepository: OrderRepository
) : ViewModel() {

    private val _dashboardState = MutableStateFlow(WarehouseDashboardState(isLoading = true))
    val dashboardState: StateFlow<WarehouseDashboardState> = _dashboardState

    private val _stockState = MutableStateFlow(WarehouseStockUiState(isLoading = true))
    val stockState: StateFlow<WarehouseStockUiState> = _stockState

    private val _dispatchState = MutableStateFlow(WarehouseDispatchUiState(isLoading = true))
    val dispatchState: StateFlow<WarehouseDispatchUiState> = _dispatchState

    private val _pickingQueue = MutableStateFlow<List<PickingOrderDto>>(emptyList())
    val pickingQueue: StateFlow<List<PickingOrderDto>> = _pickingQueue

    private val _nearExpiryBatches = MutableStateFlow<List<WarehouseBatchDto>>(emptyList())
    val nearExpiryBatches: StateFlow<List<WarehouseBatchDto>> = _nearExpiryBatches

    private val _pendingReturns = MutableStateFlow<List<WarehouseReturnItemDto>>(emptyList())
    val pendingReturns: StateFlow<List<WarehouseReturnItemDto>> = _pendingReturns

    private val _eventFlow = MutableSharedFlow<WarehouseUiEvent>()
    val eventFlow: SharedFlow<WarehouseUiEvent> = _eventFlow.asSharedFlow()

    init {
        refreshAll()
    }

    fun refreshAll() {
        loadDashboardMetrics()
        loadStock()
        loadPickingQueue()
        loadDispatchBatches()
        loadReturns()
    }

    fun loadDashboardMetrics() {
        viewModelScope.launch {
            _dashboardState.update { it.copy(isLoading = true) }
            try {
                val stockResult = warehouseRepository.getStock()
                val pickingResult = warehouseRepository.getPickingQueue()
                val dispatchResult = warehouseRepository.getDispatchBatches()
                val nearExpiryResult = warehouseRepository.getNearExpiryBatches()
                val returnsResult = warehouseRepository.getReturns()

                val stock = stockResult.getOrNull()
                val queue = pickingResult.getOrNull().orEmpty()
                val batches = dispatchResult.getOrNull().orEmpty()
                val nearExpiry = nearExpiryResult.getOrNull().orEmpty()
                val returns = returnsResult.getOrNull()?.pendingUndelivered.orEmpty()

                _dashboardState.update {
                    it.copy(
                        readyToPickCount = queue.count { o -> o.status == "APPROVED" || o.status == "PICKING" },
                        packedTodayCount = queue.count { o -> o.status == "PACKED" },
                        dispatchBatchesCount = batches.count { b -> b.status == "CREATED" || b.status == "ASSIGNED" },
                        lowStockCount = stock?.products?.count { p -> p.isLowStock } ?: 0,
                        nearExpiryCount = nearExpiry.size,
                        damagedStockCount = stock?.products?.sumOf { p -> p.damagedQuantity } ?: 0,
                        pendingReturnsCount = returns.size,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _dashboardState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun loadStock(search: String? = null, filter: String? = null) {
        viewModelScope.launch {
            val q = search ?: _stockState.value.searchQuery
            val f = filter ?: _stockState.value.activeFilter
            val effectiveFilter = if (f == "ALL") null else f

            _stockState.update { it.copy(isLoading = true, searchQuery = q, activeFilter = f) }
            val result = warehouseRepository.getStock(search = q.takeIf { it.isNotBlank() }, filter = effectiveFilter)
            if (result.isSuccess) {
                val data = result.getOrNull()
                _stockState.update {
                    it.copy(
                        products = data?.products.orEmpty(),
                        isLoading = false
                    )
                }
            } else {
                _stockState.update { it.copy(isLoading = false) }
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Failed to load stock"))
            }
        }
    }

    fun onScanBarcode(barcode: String) {
        viewModelScope.launch {
            val result = warehouseRepository.findProductByBarcode(barcode.trim())
            if (result.isSuccess) {
                val product = result.getOrNull()
                if (product != null) {
                    _stockState.update { it.copy(scannedProduct = product, isScanning = false) }
                    _eventFlow.emit(WarehouseUiEvent.BarcodeFound(product))
                    _eventFlow.emit(WarehouseUiEvent.Success("Found: ${product.name} (Stock: ${product.stockQuantity})"))
                } else {
                    _eventFlow.emit(WarehouseUiEvent.Error("Product not found with barcode $barcode"))
                }
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Barcode not recognized"))
            }
        }
    }

    fun setScanning(active: Boolean) {
        _stockState.update { it.copy(isScanning = active) }
    }

    fun clearScannedProduct() {
        _stockState.update { it.copy(scannedProduct = null) }
    }

    fun adjustStock(productId: String, changeQuantity: Int, reason: String, notes: String? = null, batchId: String? = null) {
        viewModelScope.launch {
            val result = warehouseRepository.adjustStock(productId, changeQuantity, reason, notes, batchId)
            if (result.isSuccess) {
                val resp = result.getOrNull()
                _eventFlow.emit(WarehouseUiEvent.Success("Stock updated! Current: ${resp?.newStockQuantity ?: "OK"}"))
                loadStock()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Adjustment failed"))
            }
        }
    }

    fun auditStock(productId: String, physicalCount: Int, notes: String? = null) {
        viewModelScope.launch {
            val result = warehouseRepository.auditStock(productId, physicalCount, notes)
            if (result.isSuccess) {
                val resp = result.getOrNull()
                _eventFlow.emit(WarehouseUiEvent.Success("Audit complete. Difference: ${resp?.difference ?: 0}"))
                loadStock()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Audit reconciliation failed"))
            }
        }
    }

    fun createBatch(request: CreateWarehouseBatchRequest) {
        viewModelScope.launch {
            val result = warehouseRepository.createBatch(request)
            if (result.isSuccess) {
                _eventFlow.emit(WarehouseUiEvent.Success("Inward GRN: Batch ${request.batchNo} added!"))
                loadStock()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Failed to add batch"))
            }
        }
    }

    fun loadPickingQueue() {
        viewModelScope.launch {
            val result = warehouseRepository.getPickingQueue()
            if (result.isSuccess) {
                val queue = result.getOrNull().orEmpty()
                _pickingQueue.value = queue
                _dispatchState.update { it.copy(packedOrders = queue.filter { o -> o.status == "PACKED" }) }
            }
        }
    }

    fun startPicking(orderId: String) {
        viewModelScope.launch {
            val result = warehouseRepository.startPicking(orderId)
            if (result.isSuccess) {
                _eventFlow.emit(WarehouseUiEvent.Success("Picking started for order $orderId"))
                loadPickingQueue()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Failed to start picking"))
            }
        }
    }

    fun scanPickItem(orderId: String, barcode: String) {
        viewModelScope.launch {
            val result = warehouseRepository.scanPickItem(orderId = orderId, barcode = barcode)
            if (result.isSuccess) {
                _eventFlow.emit(WarehouseUiEvent.Success("Item scanned & verified!"))
                loadPickingQueue()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Scan pick item failed"))
            }
        }
    }

    fun markOrderPacked(orderId: String, cartonsCount: Int, notes: String? = null, weightGrams: Int? = null) {
        viewModelScope.launch {
            val result = warehouseRepository.markOrderPacked(orderId, cartonsCount, notes, null, weightGrams)
            if (result.isSuccess) {
                _eventFlow.emit(WarehouseUiEvent.Success("Order $orderId packed into $cartonsCount carton(s)!"))
                loadPickingQueue()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Failed to mark packed"))
            }
        }
    }

    fun loadDispatchBatches() {
        viewModelScope.launch {
            _dispatchState.update { it.copy(isLoading = true) }
            val batchResult = warehouseRepository.getDispatchBatches()
            val execResult = orderRepository.getDeliveryExecutives()

            val batches = batchResult.getOrNull().orEmpty()
            val execs = execResult.getOrNull().orEmpty()

            _dispatchState.update {
                it.copy(
                    dispatchBatches = batches,
                    deliveryExecutives = execs,
                    isLoading = false
                )
            }
        }
    }

    fun createDispatchBatch(orderIds: List<String>, driverId: String?, notes: String?) {
        viewModelScope.launch {
            if (orderIds.isEmpty()) {
                _eventFlow.emit(WarehouseUiEvent.Error("Select at least 1 packed order for dispatch"))
                return@launch
            }
            val result = warehouseRepository.createDispatchBatch(orderIds, driverId, null, notes)
            if (result.isSuccess) {
                val batch = result.getOrNull()
                _eventFlow.emit(WarehouseUiEvent.Success("Dispatch Batch ${batch?.batchCode ?: ""} created!"))
                loadDispatchBatches()
                loadPickingQueue()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Failed to create dispatch batch"))
            }
        }
    }

    fun handoverDispatchBatch(batchId: String) {
        viewModelScope.launch {
            val result = warehouseRepository.handoverDispatchBatch(batchId)
            if (result.isSuccess) {
                _eventFlow.emit(WarehouseUiEvent.Success("Handover complete! Orders are Out for Delivery."))
                loadDispatchBatches()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Handover failed"))
            }
        }
    }

    fun loadReturns() {
        viewModelScope.launch {
            val result = warehouseRepository.getReturns()
            if (result.isSuccess) {
                val resp = result.getOrNull()
                _pendingReturns.value = resp?.pendingUndelivered.orEmpty()
            }
        }
    }

    fun inspectReturn(request: InspectWarehouseReturnRequest) {
        viewModelScope.launch {
            val result = warehouseRepository.inspectReturn(request)
            if (result.isSuccess) {
                val resp = result.getOrNull()
                _eventFlow.emit(WarehouseUiEvent.Success("Return inspected! Restocked: ${resp?.restocked == true} (Stock: ${resp?.newStockQuantity ?: "OK"})"))
                loadReturns()
                loadStock()
                loadDashboardMetrics()
            } else {
                _eventFlow.emit(WarehouseUiEvent.Error(result.exceptionOrNull()?.message ?: "Return inspection failed"))
            }
        }
    }
}
