package com.routeflow.app.feature.auth

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.design.EmptyState
import com.routeflow.app.core.design.ErrorState
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RoleIcon
import com.routeflow.app.domain.model.Employee

@Composable
fun DemoLoginScreen(
    state: DemoLoginState,
    onSelectEmployee: (String) -> Unit,
    onContinue: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    when {
        state.isLoading -> LoadingState(modifier.fillMaxSize())
        state.errorMessage != null -> ErrorState(state.errorMessage, onRetry, modifier.fillMaxSize())
        state.employees.isEmpty() -> Column(
            modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            EmptyState("No demo employees", "The demo team is unavailable. Try loading it again.")
            OutlinedButton(onRetry, Modifier.heightIn(min = 48.dp)) { Text("Reload demo team") }
        }
        else -> Column(modifier.fillMaxSize().testTag("role_picker")) {
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Spacer(Modifier.height(8.dp))
                Text("JAIPUR · RAJASTHAN", style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary)
                Text("A smoother day,\nfrom warehouse to shop.",
                    style = MaterialTheme.typography.headlineLarge,
                    modifier = Modifier.semantics { heading() })
                Text("Jaipur Wholesale Distributors", style = MaterialTheme.typography.bodyLarge)
                Text("Choose a demo role", style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 12.dp).semantics { heading() })
                Text("Explore a workspace with sample employees. No password needed.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Column(Modifier.selectableGroup(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    state.employees.forEach { employee ->
                        EmployeeCard(employee, state.selectedEmployeeId == employee.id) {
                            onSelectEmployee(employee.id)
                        }
                    }
                }
                Text("Demo access only. These are fictional accounts, not a secure employee sign-in.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(4.dp))
            }
            Surface(shadowElevation = 2.dp) {
                Button(
                    onClick = onContinue,
                    enabled = state.employees.any { it.id == state.selectedEmployeeId },
                    modifier = Modifier.fillMaxWidth().padding(20.dp).heightIn(min = 56.dp)
                        .testTag("open_workspace"),
                    shape = RoundedCornerShape(16.dp),
                ) { Text("Open demo workspace") }
            }
        }
    }
}

@Composable
private fun EmployeeCard(employee: Employee, selected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        border = BorderStroke(if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant),
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 88.dp)
                .testTag("role_${employee.role.name}")
                .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            RoleIcon(employee.role, Modifier.size(28.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(employee.role.label, style = MaterialTheme.typography.titleMedium)
                Text(employee.name, style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            RadioButton(selected = selected, onClick = null)
        }
    }
}
