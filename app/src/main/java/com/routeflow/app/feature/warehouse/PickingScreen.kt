package com.routeflow.app.feature.warehouse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RouteFlowStatus

@Composable
fun PickingScreen(
    state: PickingState,
    onTogglePicked: (String, String) -> Unit,
    onStartPicking: (String) -> Unit,
    onPacked: (String) -> Unit,
    onDispatch: (String) -> Unit,
    onErrorShown: () -> Unit
) {
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.error) {
        state.error?.let {
            snackbarHostState.showSnackbar(it)
            onErrorShown()
        }
    }

    Column {
        if (state.isLoading) {
            LoadingState(Modifier.fillMaxSize())
        } else if (state.orders.isEmpty()) {
            Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text("No orders to pick or pack", style = MaterialTheme.typography.titleMedium)
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(state.orders) { detail ->
                    PickingOrderCard(detail, onTogglePicked, onStartPicking, onPacked, onDispatch)
                }
            }
        }
        SnackbarHost(hostState = snackbarHostState)
    }
}

@Composable
private fun PickingOrderCard(
    detail: PickingOrderDetailState,
    onTogglePicked: (String, String) -> Unit,
    onStartPicking: (String) -> Unit,
    onPacked: (String) -> Unit,
    onDispatch: (String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text(detail.order.id, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    Text(detail.retailerName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
                Text(detail.order.status, style = MaterialTheme.typography.labelSmall, color = RouteFlowStatus.Pending)
            }
            
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            
            detail.items.forEach { itemDetail ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${itemDetail.product?.name ?: "Unknown"} x ${itemDetail.item.quantity}", style = MaterialTheme.typography.bodyMedium)
                        if (itemDetail.item.freeQuantity > 0) {
                            Text("+ ${itemDetail.item.freeQuantity} free", style = MaterialTheme.typography.bodySmall, color = RouteFlowStatus.Completed)
                        }
                    }
                    
                    if (detail.order.status == "PICKING") {
                        Checkbox(
                            checked = itemDetail.isPicked,
                            onCheckedChange = { onTogglePicked(detail.order.id, itemDetail.item.productId) }
                        )
                    } else if (detail.order.status != "APPROVED") {
                        Icon(Icons.Default.Check, contentDescription = "Picked", tint = RouteFlowStatus.Completed)
                    }
                }
            }
            
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            
            when (detail.order.status) {
                "APPROVED" -> {
                    Button(onClick = { onStartPicking(detail.order.id) }, modifier = Modifier.fillMaxWidth()) {
                        Text("Start Picking")
                    }
                }
                "PICKING" -> {
                    Button(
                        onClick = { onPacked(detail.order.id) }, 
                        modifier = Modifier.fillMaxWidth(),
                        enabled = detail.allPicked
                    ) {
                        Text("Mark Packed")
                    }
                }
                "PACKED" -> {
                    Button(onClick = { onDispatch(detail.order.id) }, modifier = Modifier.fillMaxWidth()) {
                        Text("Dispatch (Assign Suresh)")
                    }
                }
            }
        }
    }
}
