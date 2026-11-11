package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.database.entity.CollectionRecordEntity
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.CollectionRepository
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SalesCollectionsUiState(
    val retailers: List<Retailer> = emptyList(),
    val collections: List<CollectionRecordEntity> = emptyList(),
    val isRecording: Boolean = false,
    val isSyncing: Boolean = false,
    val totalOutstandingPaise: Long = 0L,
    val totalCollectedPaise: Long = 0L
)

sealed interface CollectionEvent {
    data class Success(val message: String, val receiptId: String, val isConfirmed: Boolean) : CollectionEvent
    data class Error(val error: String) : CollectionEvent
}

@HiltViewModel
class SalesCollectionsViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository,
    private val collectionRepository: CollectionRepository
) : ViewModel() {

    private val _isRecording = MutableStateFlow(false)
    private val _isSyncing = MutableStateFlow(false)
    private val _eventFlow = MutableSharedFlow<CollectionEvent>()
    val eventFlow: SharedFlow<CollectionEvent> = _eventFlow.asSharedFlow()

    val uiState: StateFlow<SalesCollectionsUiState> = combine(
        retailerRepository.getAllRetailers(),
        collectionRepository.observeCollections(),
        _isRecording,
        _isSyncing
    ) { retailers, collections, recording, syncing ->
        val totalOutstanding = retailers.sumOf { it.outstandingAmountPaise }
        val totalCollected = collections.sumOf { it.amountPaise }
        SalesCollectionsUiState(
            retailers = retailers,
            collections = collections,
            isRecording = recording,
            isSyncing = syncing,
            totalOutstandingPaise = totalOutstanding,
            totalCollectedPaise = totalCollected
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = SalesCollectionsUiState()
    )

    fun recordCollection(
        retailerId: String,
        retailerName: String,
        amountPaise: Long,
        paymentMethod: String,
        receiptId: String?,
        notes: String?
    ) {
        if (_isRecording.value) return
        _isRecording.value = true
        viewModelScope.launch {
            try {
                val result = collectionRepository.recordCollection(
                    retailerId = retailerId,
                    retailerName = retailerName,
                    amountPaise = amountPaise,
                    paymentMethod = paymentMethod,
                    receiptId = receiptId,
                    notes = notes
                )
                result.fold(
                    onSuccess = { entity ->
                        val status = if (entity.isSynced) "Payment confirmed" else "Saved locally (Pending sync)"
                        _eventFlow.emit(
                            CollectionEvent.Success(
                                message = "$status: ₹${"%,d".format(entity.amountPaise / 100)}",
                                receiptId = entity.receiptId,
                                isConfirmed = entity.isSynced
                            )
                        )
                    },
                    onFailure = { err ->
                        _eventFlow.emit(CollectionEvent.Error(err.message ?: "Failed to record collection"))
                    }
                )
            } finally {
                _isRecording.value = false
            }
        }
    }

    fun syncPending() {
        if (_isSyncing.value) return
        _isSyncing.value = true
        viewModelScope.launch {
            try {
                val res = collectionRepository.syncPendingCollections()
                res.fold(
                    onSuccess = { count ->
                        _eventFlow.emit(CollectionEvent.Success("Synced $count collections", "", true))
                    },
                    onFailure = { err ->
                        _eventFlow.emit(CollectionEvent.Error(err.message ?: "Sync failed"))
                    }
                )
            } finally {
                _isSyncing.value = false
            }
        }
    }
}
