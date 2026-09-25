package com.routeflow.app.feature.owner

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.OrderSyncBadge
import com.routeflow.app.core.design.RouteFlowStatus

@Composable
fun OrderApprovalScreen(
    state: OrderApprovalState,
    onApprove: (String) -> Unit,
    onReject: (String, String) -> Unit
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else if (state.orders.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text("No orders pending approval", style = MaterialTheme.typography.titleMedium)
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(state.orders) { detail ->
                OrderApprovalCard(detail, onApprove, onReject)
            }
        }
    }
}

@Composable
private fun OrderApprovalCard(
    detail: OrderDetailState,
    onApprove: (String) -> Unit,
    onReject: (String, String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(detail.order.id, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                        OrderSyncBadge(state = detail.syncState, errorMessage = detail.syncError)
                    }
                    Text(detail.retailerName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                }
                Text(CurrencyFormatter.formatPaise(detail.order.totalAmountPaise), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Black)
            }
            
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            
            detail.items.forEach { itemDetail ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("${itemDetail.product?.name ?: "Unknown"} x ${itemDetail.item.quantity}", style = MaterialTheme.typography.bodyMedium)
                    if (itemDetail.item.freeQuantity > 0) {
                        Text("+ ${itemDetail.item.freeQuantity} free", style = MaterialTheme.typography.bodySmall, color = RouteFlowStatus.Completed)
                    }
                }
            }
            
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(
                    onClick = { onReject(detail.order.id, "Demo rejection") },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Reject")
                }
                Button(
                    onClick = { onApprove(detail.order.id) },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Approve")
                }
            }
        }
    }
}
