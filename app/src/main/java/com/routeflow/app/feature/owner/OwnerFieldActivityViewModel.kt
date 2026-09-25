package com.routeflow.app.feature.owner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.core.network.dto.DailyVisitDto
import com.routeflow.app.domain.repository.FieldOperationsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OwnerFieldActivityState(
    val visits: List<DailyVisitDto> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class OwnerFieldActivityViewModel @Inject constructor(
    private val fieldOperationsRepository: FieldOperationsRepository
) : ViewModel() {

    private val _state = MutableStateFlow(OwnerFieldActivityState(isLoading = true))
    val state: StateFlow<OwnerFieldActivityState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val result = fieldOperationsRepository.getDailyVisits()
            if (result.isSuccess) {
                _state.update {
                    it.copy(
                        visits = result.getOrNull() ?: emptyList(),
                        isLoading = false
                    )
                }
            } else {
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = result.exceptionOrNull()?.message ?: "Failed to load field activity"
                    )
                }
            }
        }
    }
}
