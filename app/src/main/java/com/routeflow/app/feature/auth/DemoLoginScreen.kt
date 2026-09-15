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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.text.font.FontWeight
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
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Spacer(Modifier.height(32.dp))
                Text(
                    text = "RouteFlow",
                    style = MaterialTheme.typography.headlineLarge,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Black
                )
                Text(
                    text = "Warehouse to retailer, made simple.",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.secondary
                )
                Spacer(Modifier.height(8.dp))
                Text("JAIPUR · RAJASTHAN", style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary)
                Text("Jaipur Wholesale Distributors", style = MaterialTheme.typography.bodyLarge)
                
                Text("Choose a demo role", style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 12.dp).semantics { heading() })
                
                Column(Modifier.selectableGroup(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    state.employees.forEach { employee ->
                        EmployeeCard(employee, state.selectedEmployeeId == employee.id) {
                            onSelectEmployee(employee.id)
                        }
                    }
                }

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f))
                ) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Demo Workflow Guide", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        DemoStep("1. Salesperson", "Check in at Sharma Store & order 10 Tea (1 free).")
                        DemoStep("2. Owner", "Approve the submitted order.")
                        DemoStep("3. Warehouse", "Pick, pack and dispatch.")
                        DemoStep("4. Delivery", "Enter code 4829 and confirm.")
                    }
                }

                Text("Demo data only. These are fictional accounts for demonstration purposes.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                
                Spacer(Modifier.height(16.dp))
            }
            Surface(
                shadowElevation = 8.dp,
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 2.dp
            ) {
                Button(
                    onClick = onContinue,
                    enabled = state.employees.any { it.id == state.selectedEmployeeId },
                    modifier = Modifier.fillMaxWidth().padding(24.dp).heightIn(min = 56.dp)
                        .testTag("open_workspace"),
                    shape = RoundedCornerShape(12.dp),
                ) { Text("Open demo", style = MaterialTheme.typography.titleMedium) }
            }
        }
    }
}

@Composable
private fun EmployeeCard(employee: Employee, selected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
        border = BorderStroke(
            if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant
        ),
        shadowElevation = if (selected) 4.dp else 0.dp
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 72.dp)
                .testTag("role_${employee.role.name}")
                .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            RoleIcon(employee.role, Modifier.size(32.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(employee.role.label, style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold)
                Text(employee.name, style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            RadioButton(selected = selected, onClick = null)
        }
    }
}

@Composable
private fun DemoStep(label: String, description: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text(description, style = MaterialTheme.typography.bodySmall)
    }
}
