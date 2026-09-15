package com.routeflow.app.feature.sales

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.RetailerRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SalesHomeState(
    val beatName: String = "Mansarovar West — BEAT-04",
    val shopsVisited: Int = 0,
    val totalShops: Int = 6,
    val todayOrderValuePaise: Long = 0,
    val monthlyTargetPaise: Long = 50000000, // ₹5,00,000
    val currentAchievedPaise: Long = 12500000, // ₹1,25,000
    val isLoading: Boolean = false
)

@HiltViewModel
class SalesViewModel @Inject constructor(
    private val retailerRepository: RetailerRepository,
    // TODO: Add OrderRepository and TargetRepository
) : ViewModel() {

    private val _state = MutableStateFlow(SalesHomeState())
    val state: StateFlow<SalesHomeState> = _state.asStateFlow()

    init {
        loadData()
    }

    fun loadData() {
        // TODO: Real data loading from Room
    }
}
