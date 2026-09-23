package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Retailer
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

data class RetailerListState(
    val beatName: String = "Sector Beat — BEAT-04",
    val retailers: List<RetailerItemState> = emptyList(),
    val isLoading: Boolean = false
)

data class RetailerItemState(
    val retailer: Retailer,
    val visitStatus: String = "NOT_VISITED" // NOT_VISITED, VISITING, VISITED
)

@HiltViewModel
class RetailerListViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository
) : ViewModel() {

    val state: StateFlow<RetailerListState> = retailerRepository.getRetailersByBeat("BEAT-04")
        .map { retailers ->
            RetailerListState(
                beatName = "Sector Beat — BEAT-04",
                retailers = retailers.map { RetailerItemState(it) }
            )
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = RetailerListState(isLoading = true)
        )
}
