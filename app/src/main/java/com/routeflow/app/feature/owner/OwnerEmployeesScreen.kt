package com.routeflow.app.feature.owner

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.network.dto.EmployeeDto

@Composable
fun OwnerEmployeesScreen(
    state: OwnerMasterState,
    onCreateEmployee: (username: String, name: String, role: String, passwordHash: String) -> Unit,
    onDeactivateEmployee: (id: String, name: String) -> Unit,
    onClearMessages: () -> Unit,
    onBack: () -> Unit
) {
    var showAddDialog by remember { mutableStateOf(false) }
    var deactivatingEmployee by remember { mutableStateOf<EmployeeDto?>(null) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                modifier = Modifier.testTag("add_employee_fab"),
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Staff", tint = Color.White)
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Staff & Roles", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text("Active team members and field executives", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                }
                OutlinedButton(onClick = onBack) {
                    Text("Back")
                }
            }

            if (state.successMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFECFDF5)),
                    border = BorderStroke(1.dp, Color(0xFF10B981))
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF10B981))
                        Text(state.successMessage, style = MaterialTheme.typography.bodyMedium, color = Color(0xFF065F46), modifier = Modifier.weight(1f))
                        IconButton(onClick = onClearMessages) { Text("×", fontWeight = FontWeight.Bold) }
                    }
                }
            }

            if (state.errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                    border = BorderStroke(1.dp, Color(0xFFEF4444))
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = Color(0xFFEF4444))
                        Text(state.errorMessage, style = MaterialTheme.typography.bodyMedium, color = Color(0xFF991B1B), modifier = Modifier.weight(1f))
                        IconButton(onClick = onClearMessages) { Text("×", fontWeight = FontWeight.Bold) }
                    }
                }
            }

            if (state.isLoading) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                    CircularProgressIndicator(Modifier.size(24.dp))
                }
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(state.employees, key = { it.id }) { employee ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.weight(1f)) {
                                Surface(
                                    color = if (employee.isActive) MaterialTheme.colorScheme.primaryContainer else Color(0xFFF1F5F9),
                                    shape = MaterialTheme.shapes.small
                                ) {
                                    Icon(
                                        Icons.Default.Person,
                                        contentDescription = null,
                                        tint = if (employee.isActive) MaterialTheme.colorScheme.primary else Color.Gray,
                                        modifier = Modifier.padding(8.dp).size(24.dp)
                                    )
                                }
                                Column {
                                    Text(employee.fullName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                                    Text("@${employee.username} · ${employee.role}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                                    if (!employee.isActive) {
                                        Text("Deactivated (Access Revoked)", style = MaterialTheme.typography.labelSmall, color = Color(0xFFDC2626), fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                            if (employee.isActive && employee.role != "OWNER") {
                                OutlinedButton(
                                    onClick = { deactivatingEmployee = employee },
                                    modifier = Modifier.testTag("deactivate_${employee.id}"),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFDC2626))
                                ) {
                                    Icon(Icons.Default.Block, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.size(4.dp))
                                    Text("Revoke")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAddDialog) {
        AddEmployeeDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { username, name, role, password ->
                onCreateEmployee(username, name, role, password)
                showAddDialog = false
            }
        )
    }

    deactivatingEmployee?.let { emp ->
        AlertDialog(
            onDismissRequest = { deactivatingEmployee = null },
            title = { Text("Revoke Access for ${emp.fullName}?", fontWeight = FontWeight.Bold) },
            text = { Text("This will instantly invalidate all active sessions for @${emp.username}. They will not be able to log in or sync any orders.") },
            confirmButton = {
                Button(
                    onClick = {
                        onDeactivateEmployee(emp.id, emp.fullName)
                        deactivatingEmployee = null
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626))
                ) {
                    Text("Deactivate & Revoke")
                }
            },
            dismissButton = {
                TextButton(onClick = { deactivatingEmployee = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun AddEmployeeDialog(
    onDismiss: () -> Unit,
    onConfirm: (username: String, name: String, role: String, passwordHash: String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var selectedRole by remember { mutableStateOf("SALESPERSON") }

    val roles = listOf(
        "SALESPERSON" to "Salesperson",
        "WAREHOUSE_MANAGER" to "Warehouse Manager",
        "DELIVERY_EXECUTIVE" to "Delivery Executive"
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Onboard Team Member", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Full Name *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = username, onValueChange = { username = it }, label = { Text("Username *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Temporary Password *") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Text("Role Assignment:", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp))
                roles.forEach { (roleCode, roleLabel) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(
                            selected = selectedRole == roleCode,
                            onClick = { selectedRole = roleCode }
                        )
                        Text(roleLabel, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (name.isNotBlank() && username.isNotBlank() && password.isNotBlank()) {
                        // Backend expects simple password or hash
                        onConfirm(username.trim().lowercase(), name.trim(), selectedRole, password.trim())
                    }
                }
            ) {
                Text("Onboard Staff")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
