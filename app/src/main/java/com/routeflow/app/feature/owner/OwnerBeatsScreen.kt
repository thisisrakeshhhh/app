package com.routeflow.app.feature.owner

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.BeatDto
import com.routeflow.app.core.network.dto.EmployeeDto

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerBeatsScreen(
    state: OwnerMasterState,
    onCreateBeat: (name: String, description: String?, workingDays: List<String>) -> Unit,
    onAssignSalesperson: (beatId: String, userId: String) -> Unit,
    onClearMessages: () -> Unit,
    onBack: () -> Unit
) {
    val snackbarHostState = remember { SnackbarHostStateState() }
    var showAddDialog by remember { mutableStateOf(false) }
    var selectedBeatForAssignment by remember { mutableStateOf<BeatDto?>(null) }

    LaunchedEffect(state.successMessage, state.errorMessage) {
        state.successMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
        state.errorMessage?.let {
            snackbarHostState.showSnackbar(it)
            onClearMessages()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.owner_tab_beats), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                containerColor = RFColors.Primary,
                contentColor = Color.White
            ) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.create_beat))
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (state.isLoading && state.beats.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else if (state.beats.isEmpty()) {
                Text(
                    text = "No beats configured yet. Tap + to create the first beat.",
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(24.dp),
                    style = MaterialTheme.typography.bodyLarge,
                    color = RFColors.TextSecondary
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(state.beats, key = { it.id }) { beat ->
                        BeatCard(
                            beat = beat,
                            onAssignClick = { selectedBeatForAssignment = beat }
                        )
                    }
                }
            }
        }
    }

    if (showAddDialog) {
        AddBeatDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { name, desc, days ->
                onCreateBeat(name, desc, days)
                showAddDialog = false
            }
        )
    }

    selectedBeatForAssignment?.let { beat ->
        AssignSalespersonDialog(
            beat = beat,
            salespeople = state.employees.filter { it.role == "SALESPERSON" && it.isActive },
            onDismiss = { selectedBeatForAssignment = null },
            onConfirm = { userId ->
                onAssignSalesperson(beat.id, userId)
                selectedBeatForAssignment = null
            }
        )
    }
}

@Composable
private fun BeatCard(
    beat: BeatDto,
    onAssignClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = beat.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = "${beat.retailerCount} Shops",
                    style = MaterialTheme.typography.labelMedium,
                    color = RFColors.Accent
                )
            }

            if (!beat.description.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = beat.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Days: ${if (beat.workingDays.isEmpty()) "All Days" else beat.workingDays.joinToString(", ")}",
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Sales reps: ${if (beat.assignedSalespeople.isEmpty()) "Unassigned" else beat.assignedSalespeople.joinToString(", ")}",
                style = MaterialTheme.typography.bodySmall,
                color = if (beat.assignedSalespeople.isEmpty()) RFColors.Warning else RFColors.Success
            )

            Spacer(modifier = Modifier.height(12.dp))
            OutlinedButton(
                onClick = onAssignClick,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.padding(end = 8.dp))
                Text(stringResource(R.string.assign_salesperson))
            }
        }
    }
}

@Composable
private fun AddBeatDialog(
    onDismiss: () -> Unit,
    onConfirm: (name: String, description: String?, workingDays: List<String>) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var workingDaysStr by remember { mutableStateOf("MON,TUE,WED,THU,FRI,SAT") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.create_beat), fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.beat_name) + " *") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description / Area details") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = workingDaysStr,
                    onValueChange = { workingDaysStr = it },
                    label = { Text("Working Days (comma separated)") },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("MON,TUE,WED,THU,FRI,SAT") }
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val days = workingDaysStr.split(",").map { it.trim().uppercase() }.filter { it.isNotBlank() }
                    onConfirm(name.trim(), description.trim().takeIf { it.isNotBlank() }, days)
                },
                enabled = name.isNotBlank(),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
            ) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}

@Composable
private fun AssignSalespersonDialog(
    beat: BeatDto,
    salespeople: List<EmployeeDto>,
    onDismiss: () -> Unit,
    onConfirm: (userId: String) -> Unit
) {
    var selectedUserId by remember { mutableStateOf(salespeople.firstOrNull()?.id ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Assign to ${beat.name}", fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (salespeople.isEmpty()) {
                    Text(
                        text = "No active salespersons found. Please create salespersons first in Staff & Team.",
                        color = RFColors.Error
                    )
                } else {
                    Text("Select a salesperson to cover this beat:")
                    salespeople.forEach { emp ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            androidx.compose.material3.RadioButton(
                                selected = selectedUserId == emp.id,
                                onClick = { selectedUserId = emp.id }
                            )
                            Text(
                                text = "${emp.fullName} (@${emp.username})",
                                modifier = Modifier.padding(start = 8.dp),
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(selectedUserId) },
                enabled = selectedUserId.isNotBlank(),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
            ) {
                Text(stringResource(R.string.confirm))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}

private fun SnackbarHostStateState(): SnackbarHostState = SnackbarHostState()
