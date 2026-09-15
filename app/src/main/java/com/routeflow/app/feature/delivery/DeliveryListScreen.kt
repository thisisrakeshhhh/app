package com.routeflow.app.feature.delivery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState

@Composable
fun DeliveryListScreen(
    state: List<DeliveryItemState>,
    onDeliveryClick: (String) -> Unit
) {
    if (state.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text("No deliveries assigned", style = MaterialTheme.typography.titleMedium)
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(state) { item ->
                DeliveryCard(item, onDeliveryClick)
            }
        }
    }
}

@Composable
private fun DeliveryCard(item: DeliveryItemState, onClick: (String) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = { onClick(item.order.id) },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(item.order.id, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                Text("Amount Due", style = MaterialTheme.typography.labelSmall)
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(item.retailerName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(item.retailerAddress, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(CurrencyFormatter.formatPaise(item.order.totalAmountPaise), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black)
            }
            Button(onClick = { onClick(item.order.id) }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("Proceed to Deliver")
                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, Modifier.padding(start = 8.dp))
            }
        }
    }
}
