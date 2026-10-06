package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.CreateRetailerRequest
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RetailerListState(
    val beatName: String = "Sector Beat — BEAT-04",
    val retailers: List<RetailerItemState> = emptyList(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val message: String? = null,
    val error: String? = null
)

data class RetailerItemState(
    val retailer: Retailer,
    val visitStatus: String = "NOT_VISITED" // NOT_VISITED, VISITING, VISITED
)

@HiltViewModel
class RetailerListViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    private val _isSaving = MutableStateFlow(false)
    private val _message = MutableStateFlow<String?>(null)
    private val _error = MutableStateFlow<String?>(null)

    val state: StateFlow<RetailerListState> = combine(
        retailerRepository.getRetailersByBeat("BEAT-04"),
        _isSaving,
        _message,
        _error
    ) { retailers, isSaving, message, error ->
        RetailerListState(
            beatName = "Sector Beat — BEAT-04",
            retailers = retailers.map { RetailerItemState(it) },
            isLoading = false,
            isSaving = isSaving,
            message = message,
            error = error
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = RetailerListState(isLoading = true)
    )

    fun createRetailer(
        name: String,
        address: String,
        contactNumber: String,
        latitude: Double?,
        longitude: Double?
    ) {
        viewModelScope.launch {
            _isSaving.value = true
            _message.value = null
            _error.value = null

            val req = CreateRetailerRequest(
                id = "RET-${System.currentTimeMillis().toString().takeLast(6)}",
                name = name.trim(),
                beatId = "BEAT-04",
                address = address.trim(),
                contactNumber = contactNumber.trim(),
                creditLimitPaise = 500000L,
                paymentTermsDays = 7,
                latitude = latitude,
                longitude = longitude
            )
            val result = retailerRepository.createRetailer(req)
            _isSaving.value = false
            if (result.isSuccess) {
                _message.value = "Shop '$name' added successfully!"
                retailerRepository.syncRetailersFromServer()
            } else {
                _error.value = result.exceptionOrNull()?.message ?: "Failed to add shop"
            }
        }
    }

    fun clearMessages() {
        _message.value = null
        _error.value = null
    }
}
