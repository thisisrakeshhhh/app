package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.CollectionDto
import com.routeflow.app.domain.repository.CollectionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OwnerCollectionsUiState(
    val isLoading: Boolean = true,
    val collections: List<CollectionDto> = emptyList(),
    val error: String? = null,
    val processingId: String? = null
) {
    val pendingReviewCollections: List<CollectionDto>
        get() = collections.filter { it.status == "ENTERED" || it.status == "LEGACY_REVIEW" }

    val settledCollections: List<CollectionDto>
        get() = collections.filter { it.status in listOf("SETTLED", "VERIFIED", "CLEARED") }

    val reversedOrRejectedCollections: List<CollectionDto>
        get() = collections.filter { it.status in listOf("REVERSED", "REJECTED") }

    val pendingReviewAmountPaise: Long
        get() = pendingReviewCollections.sumOf { it.amount_paise }
}

sealed interface CollectionActionEvent {
    data class Success(val message: String) : CollectionActionEvent
    data class Error(val error: String) : CollectionActionEvent
}

@HiltViewModel
class OwnerCollectionsViewModel @Inject constructor(
    private val collectionRepository: CollectionRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(OwnerCollectionsUiState())
    val uiState: StateFlow<OwnerCollectionsUiState> = _uiState.asStateFlow()

    private val _eventFlow = MutableSharedFlow<CollectionActionEvent>()
    val eventFlow: SharedFlow<CollectionActionEvent> = _eventFlow.asSharedFlow()

    init {
        loadCollections()
    }

    fun loadCollections() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            collectionRepository.getRemoteCollections().fold(
                onSuccess = { list ->
                    _uiState.update { it.copy(isLoading = false, collections = list) }
                },
                onFailure = { err ->
                    _uiState.update { it.copy(isLoading = false, error = err.message) }
                }
            )
        }
    }

    fun reviewPayment(
        collectionId: String,
        action: String, // "VERIFY", "CLEAR", "REJECT", "REVERSE"
        reason: String
    ) {
        if (_uiState.value.processingId != null) return
        _uiState.update { it.copy(processingId = collectionId) }
        viewModelScope.launch {
            collectionRepository.reviewCollection(
                id = collectionId,
                action = action,
                reason = reason
            ).fold(
                onSuccess = {
                    _uiState.update { it.copy(processingId = null) }
                    val actionName = when (action) {
                        "VERIFY" -> "verified"
                        "CLEAR" -> "cleared"
                        "REJECT" -> "rejected"
                        "REVERSE" -> "reversed"
                        else -> "updated"
                    }
                    _eventFlow.emit(CollectionActionEvent.Success("Payment $actionName successfully"))
                    loadCollections()
                },
                onFailure = { err ->
                    _uiState.update { it.copy(processingId = null) }
                    _eventFlow.emit(CollectionActionEvent.Error(err.message ?: "Review failed"))
                }
            )
        }
    }
}
