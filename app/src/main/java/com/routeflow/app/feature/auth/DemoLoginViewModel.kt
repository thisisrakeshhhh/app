package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Employee
import com.routeflow.app.domain.repository.DemoRepository
import com.routeflow.app.domain.repository.EmployeeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DemoLoginState(
    val isLoading: Boolean = true,
    val employees: List<Employee> = emptyList(),
    val selectedEmployeeId: String? = null,
    val activeEmployee: Employee? = null,
    val errorMessage: String? = null,
    val showResetDialog: Boolean = false,
)

@HiltViewModel
class DemoLoginViewModel @Inject constructor(
    private val employeeRepository: EmployeeRepository,
    private val demoRepository: DemoRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DemoLoginState())
    val state = mutableState.asStateFlow()
    private var loadJob: Job? = null

    init {
        loadEmployees()
    }

    fun loadEmployees() {
        loadJob?.cancel()
        mutableState.update { it.copy(isLoading = true) }
        loadJob = viewModelScope.launch {
            try {
                if (!demoRepository.isDemoDataSeeded()) {
                    demoRepository.seedDemoData()
                }
                val employees = employeeRepository.getDemoEmployees()
                mutableState.update { it.copy(isLoading = false, employees = employees) }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                mutableState.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = "We couldn't load the demo team. Please try again."
                    )
                }
            }
        }
    }

    fun selectEmployee(employeeId: String) {
        mutableState.update { current ->
            if (current.activeEmployee != null || current.isLoading ||
                current.employees.none { it.id == employeeId }
            ) current else current.copy(selectedEmployeeId = employeeId, errorMessage = null)
        }
    }

    fun openWorkspace() {
        mutableState.update { current ->
            val employee = current.employees.find { it.id == current.selectedEmployeeId }
            if (current.isLoading || employee == null) current
            else current.copy(activeEmployee = employee)
        }
    }

    fun changeRole() {
        mutableState.update { it.copy(activeEmployee = null, selectedEmployeeId = null) }
    }

    fun toggleResetDialog(show: Boolean) {
        mutableState.update { it.copy(showResetDialog = show) }
    }

    fun resetDemo() {
        mutableState.update { it.copy(showResetDialog = false, isLoading = true) }
        viewModelScope.launch {
            try {
                demoRepository.resetDemoData()
                loadEmployees()
                mutableState.update { it.copy(activeEmployee = null, selectedEmployeeId = null) }
            } catch (_: Exception) {
                mutableState.update { it.copy(isLoading = false, errorMessage = "Reset failed. Please try again.") }
            }
        }
    }
}
