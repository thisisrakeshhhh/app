package com.routeflow.app.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.routeflow.app.domain.model.Employee
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
)

@HiltViewModel
class DemoLoginViewModel @Inject constructor(
    private val repository: EmployeeRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow(DemoLoginState())
    val state = mutableState.asStateFlow()
    private var loadJob: Job? = null

    init {
        loadEmployees()
    }

    fun loadEmployees() {
        loadJob?.cancel()
        mutableState.value = DemoLoginState()
        loadJob = viewModelScope.launch {
            try {
                mutableState.value = DemoLoginState(
                    isLoading = false,
                    employees = repository.getDemoEmployees(),
                )
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                // Do not expose repository exceptions or potentially sensitive details to users.
                mutableState.value = DemoLoginState(
                    isLoading = false,
                    errorMessage = "We couldn't load the demo team. Please try again.",
                )
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
}
