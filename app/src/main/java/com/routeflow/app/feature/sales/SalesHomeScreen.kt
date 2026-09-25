package com.routeflow.app.feature.sales

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.domain.model.Employee

import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import com.routeflow.app.core.design.OrderSyncBadge
import com.routeflow.app.core.design.RFColors

@Composable
fun SalesHomeScreen(
    employee: Employee,
    state: SalesHomeState,
    onStartVisits: () -> Unit,
    onSyncNow: () -> Unit = {}
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Hello, ${employee.name}",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.secondary
        )

        if (state.pendingSyncCount > 0 || state.isSyncing) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("offline_sync_card"),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFF59E0B))
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = if (state.isSyncing) "Syncing with server..." else "${state.pendingSyncCount} order(s) pending sync",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF92400E)
                        )
                        Text(
                            text = if (state.isSyncing) "Uploading queued orders to warehouse" else "Saved locally. Tap to upload immediately.",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFFB45309)
                        )
                    }
                    Button(
                        onClick = onSyncNow,
                        enabled = !state.isSyncing,
                        modifier = Modifier.testTag("sync_now_button"),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706))
                    ) {
                        if (state.isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                color = Color.White,
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text("Sync Now", color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Column(Modifier.padding(20.dp)) {
                Text("Today's Beat", style = MaterialTheme.typography.labelMedium)
                Text(state.beatName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(16.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text("Visited", style = MaterialTheme.typography.labelSmall)
                        Text("${state.shopsVisited} / ${state.totalShops} shops", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("Orders", style = MaterialTheme.typography.labelSmall)
                        Text(CurrencyFormatter.formatPaise(state.todayOrderValuePaise), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Monthly Target Progress", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                val progress = (state.currentAchievedPaise.toFloat() / state.monthlyTargetPaise.toFloat()).coerceIn(0f, 1f)
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxWidth().height(8.dp),
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        text = "${(progress * 100).toInt()}% achieved",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "Target: ${CurrencyFormatter.formatPaise(state.monthlyTargetPaise)}",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        if (state.recentOrders.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Recent Orders & Sync Status", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                state.recentOrders.forEach { order ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(order.id, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                    OrderSyncBadge(state = order.syncState, errorMessage = order.syncError)
                                }
                                Text(order.retailerName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                            }
                            Text(CurrencyFormatter.formatPaise(order.totalAmountPaise), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        Button(
            onClick = onStartVisits,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = MaterialTheme.shapes.medium
        ) {
            Text("Start shop visits", style = MaterialTheme.typography.titleMedium)
        }
    }
}
