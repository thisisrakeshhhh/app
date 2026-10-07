package com.routeflow.app.feature.sales

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.database.dao.VisitDao
import com.routeflow.app.core.database.entity.VisitEntity
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.CollectionRepository
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

data class ShopVisitState(
    val retailer: Retailer? = null,
    val activeVisit: VisitEntity? = null,
    val isLoading: Boolean = false,
    val durationSeconds: Long = 0,
    val isVisitForThisRetailer: Boolean = false,
    val lastOrderDate: Long? = null,
    val lastOrderAmountPaise: Long? = null,
    val lastOrderSummary: String? = null,
    val collectionSuccessMessage: String? = null,
    val showCheckoutConfirmation: Boolean = false
)

@HiltViewModel
class ShopVisitViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val sessionRepository: SessionRepository,
    private val retailerRepository: RetailerRepository,
    private val orderRepository: OrderRepository,
    private val collectionRepository: CollectionRepository,
    private val visitDao: VisitDao,
    private val api: com.routeflow.app.core.network.api.RouteFlowApi
) : ViewModel() {

    private val retailerId: String = checkNotNull(savedStateHandle["retailerId"])
    private val _collectionMessage = MutableStateFlow<String?>(null)

    private val _timer = flow {
        while (true) {
            emit(System.currentTimeMillis())
            delay(1000)
        }
    }

    val state: StateFlow<ShopVisitState> = combine(
        retailerRepository.getRetailerById(retailerId),
        sessionRepository.activeEmployee.flatMapLatest { employee ->
            if (employee != null) visitDao.getActiveVisit(employee.id)
            else flow { emit(null) }
        },
        orderRepository.getAllOrders(),
        _collectionMessage,
        _timer
    ) { retailer, activeVisit, orders, collectionMsg, currentTime ->
        val retailerOrders = orders.filter { it.retailerId == retailerId }
        val latestOrder = retailerOrders.maxByOrNull { it.createdAt }

        val orderSummaryText = if (latestOrder != null) {
            val dateStr = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault()).format(Date(latestOrder.createdAt))
            "Last Order: ${CurrencyFormatter.formatPaise(latestOrder.totalAmountPaise)} ($dateStr)"
        } else {
            "No previous orders recorded"
        }

        ShopVisitState(
            retailer = retailer,
            activeVisit = activeVisit,
            durationSeconds = if (activeVisit != null) (currentTime - activeVisit.checkInTime) / 1000 else 0,
            isVisitForThisRetailer = activeVisit?.retailerId == retailerId,
            lastOrderDate = latestOrder?.createdAt,
            lastOrderAmountPaise = latestOrder?.totalAmountPaise,
            lastOrderSummary = orderSummaryText,
            collectionSuccessMessage = collectionMsg,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = ShopVisitState(isLoading = true)
    )

    fun checkIn() {
        viewModelScope.launch {
            val employeeId = sessionRepository.activeEmployee.value?.id ?: return@launch
            if (state.value.activeVisit != null) return@launch

            val visit = VisitEntity(
                id = UUID.randomUUID().toString(),
                retailerId = retailerId,
                employeeId = employeeId,
                checkInTime = System.currentTimeMillis(),
                status = "ACTIVE"
            )
            visitDao.insertVisit(visit)
        }
    }

    fun recordCollection(amountPaise: Long, method: String, reference: String) {
        viewModelScope.launch {
            val retName = state.value.retailer?.name ?: retailerId
            val result = collectionRepository.recordCollection(
                retailerId = retailerId,
                retailerName = retName,
                amountPaise = amountPaise,
                paymentMethod = method,
                receiptId = reference.takeIf { it.isNotBlank() },
                notes = "Collected during visit"
            )
            if (result.isSuccess) {
                _collectionMessage.value = "Receipt recorded: ₹${amountPaise / 100} via $method"
            }
        }
    }

    fun clearCollectionMessage() {
        _collectionMessage.value = null
    }

    fun checkOut(notes: String? = null, noOrderReason: String? = null) {
        viewModelScope.launch {
            val activeVisit = state.value.activeVisit ?: return@launch
            val checkOutTime = System.currentTimeMillis()
            visitDao.completeVisit(activeVisit.id, checkOutTime)

            try {
                val durationSec = (checkOutTime - activeVisit.checkInTime) / 1000
                api.submitVisit(
                    com.routeflow.app.core.network.dto.VisitDto(
                        id = activeVisit.id,
                        retailerId = activeVisit.retailerId,
                        checkInTime = activeVisit.checkInTime,
                        checkOutTime = checkOutTime,
                        latitude = activeVisit.latitude,
                        longitude = activeVisit.longitude,
                        accuracy = activeVisit.accuracy,
                        durationSeconds = durationSec,
                        status = "COMPLETED",
                        noOrderReason = noOrderReason,
                        notes = notes,
                        idempotencyKey = "visit_${activeVisit.id}"
                    )
                )
            } catch (_: Exception) {
                // Preserved safely in Room
            }
        }
    }
}
