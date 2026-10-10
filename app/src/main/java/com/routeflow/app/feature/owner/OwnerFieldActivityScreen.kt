package com.routeflow.app.feature.owner

import android.content.Intent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.DailyVisitDto
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
fun OwnerFieldActivityScreen(
    state: OwnerFieldActivityState,
    onRefresh: () -> Unit,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Field Visits", "Sales", "Collections", "Godown Stock")

    val todayStart = remember {
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    val todayOrders = remember(state.orders) {
        state.orders.filter { it.createdAt >= todayStart }
    }
    val todaySalesPaise = remember(todayOrders) {
        todayOrders.filter { it.status == "DELIVERED" }.sumOf { it.totalAmountPaise }
    }
    val todayCollections = remember(state.collections) {
        state.collections.filter { it.timestamp >= todayStart }
    }
    val todayCollectionPaise = remember(todayCollections) {
        todayCollections.sumOf { it.amountPaise }
    }
    val lowStockProducts = remember(state.products) {
        state.products.filter { it.stockQuantity < 10 }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Reports & Operations",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Black,
                    color = Color(0xFF0F172A)
                )
                Text(
                    text = "Daily performance, field audits & ledger summary",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF64748B)
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(
                    onClick = {
                        val summaryText = buildString {
                            appendLine("RouteFlow Daily Business Summary")
                            appendLine("Date: ${SimpleDateFormat("dd MMMM yyyy", Locale.getDefault()).format(Date())}")
                            appendLine("----------------------------------")
                            appendLine("• Today Delivered Sales: ${CurrencyFormatter.formatPaise(todaySalesPaise)}")
                            appendLine("• Total Collections: ${CurrencyFormatter.formatPaise(todayCollectionPaise)}")
                            appendLine("• Field Visits Recorded: ${state.visits.size}")
                            appendLine("• Orders Placed Today: ${todayOrders.size}")
                            appendLine("• Low Stock Alerts: ${lowStockProducts.size}")
                            appendLine("----------------------------------")
                            appendLine("Generated via RouteFlow Control Room")
                        }
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            putExtra(Intent.EXTRA_TEXT, summaryText)
                            type = "text/plain"
                        }
                        context.startActivity(Intent.createChooser(sendIntent, "Share Daily Summary"))
                    }
                ) {
                    Icon(Icons.Default.Share, contentDescription = "Share", tint = MaterialTheme.colorScheme.primary)
                }
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = MaterialTheme.colorScheme.primary)
                }
            }
        }

        // Tabs
        ScrollableTabRow(
            selectedTabIndex = selectedTab,
            edgePadding = 0.dp,
            indicator = { tabPositions ->
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                    color = MaterialTheme.colorScheme.primary
                )
            }
        ) {
            tabs.forEachIndexed { index, title ->
                Tab(
                    selected = selectedTab == index,
                    onClick = { selectedTab = index },
                    text = {
                        Text(
                            text = title,
                            fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
        ) {
            if (state.isLoading && state.visits.isEmpty() && state.orders.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else {
                when (selectedTab) {
                    0 -> {
                        // Field Visits Tab
                        if (state.visits.isEmpty()) {
                            Text(
                                text = "No field visits recorded today yet.",
                                modifier = Modifier.align(Alignment.Center).padding(24.dp),
                                style = MaterialTheme.typography.bodyLarge,
                                color = RFColors.TextSecondary
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                verticalArrangement = Arrangement.spacedBy(12.dp),
                                contentPadding = PaddingValues(bottom = 120.dp)
                            ) {
                                items(state.visits, key = { it.id }) { visit ->
                                    VisitAuditCard(visit = visit)
                                }
                            }
                        }
                    }

                    1 -> {
                        // Sales Tab
                        if (state.orders.isEmpty()) {
                            Text(
                                text = "No orders recorded yet.",
                                modifier = Modifier.align(Alignment.Center).padding(24.dp),
                                style = MaterialTheme.typography.bodyLarge,
                                color = RFColors.TextSecondary
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                                contentPadding = PaddingValues(bottom = 120.dp)
                            ) {
                                items(state.orders, key = { it.id }) { order ->
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
                                            Column {
                                                Text(order.id, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                                Text("Status: ${order.status}", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                                                val orderTime = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault()).format(Date(order.createdAt))
                                                Text(orderTime, style = MaterialTheme.typography.labelSmall, color = Color(0xFF94A3B8))
                                            }
                                            Text(
                                                CurrencyFormatter.formatPaise(order.totalAmountPaise),
                                                style = MaterialTheme.typography.titleMedium,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    2 -> {
                        // Collections Tab
                        if (state.collections.isEmpty()) {
                            Text(
                                text = "No payment collections recorded yet.",
                                modifier = Modifier.align(Alignment.Center).padding(24.dp),
                                style = MaterialTheme.typography.bodyLarge,
                                color = RFColors.TextSecondary
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                                contentPadding = PaddingValues(bottom = 120.dp)
                            ) {
                                items(state.collections, key = { it.id }) { col ->
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
                                            Column {
                                                Text(col.retailerName, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                                                Text("Mode: ${col.paymentMethod} · Receipt: ${col.receiptId}", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                                                val colTime = SimpleDateFormat("dd MMM, hh:mm a", Locale.getDefault()).format(Date(col.timestamp))
                                                Text("Collected by ${col.collectedBy} · $colTime", style = MaterialTheme.typography.labelSmall, color = Color(0xFF94A3B8))
                                            }
                                            Text(
                                                CurrencyFormatter.formatPaise(col.amountPaise),
                                                style = MaterialTheme.typography.titleMedium,
                                                fontWeight = FontWeight.Bold,
                                                color = Color(0xFF16A34A)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    3 -> {
                        // Godown Stock Tab
                        if (state.products.isEmpty()) {
                            Text(
                                text = "No products loaded.",
                                modifier = Modifier.align(Alignment.Center).padding(24.dp),
                                style = MaterialTheme.typography.bodyLarge,
                                color = RFColors.TextSecondary
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                                contentPadding = PaddingValues(bottom = 120.dp)
                            ) {
                                items(state.products, key = { it.id }) { prod ->
                                    val isLow = prod.stockQuantity < 10
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
                                            Column {
                                                Text(prod.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                                                Text("Category: ${prod.category} · Price: ${CurrencyFormatter.formatPaise(prod.pricePaise)}", style = MaterialTheme.typography.bodySmall, color = Color(0xFF64748B))
                                            }
                                            Surface(
                                                color = if (isLow) Color(0xFFFEF2F2) else Color(0xFFECFDF5),
                                                shape = RoundedCornerShape(6.dp),
                                                border = BorderStroke(1.dp, if (isLow) Color(0xFFFECACA) else Color(0xFFA7F3D0))
                                            ) {
                                                Text(
                                                    text = "${prod.stockQuantity} ${prod.unit}",
                                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                                    style = MaterialTheme.typography.labelSmall,
                                                    fontWeight = FontWeight.Bold,
                                                    color = if (isLow) Color(0xFFDC2626) else Color(0xFF065F46)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun VisitAuditCard(visit: DailyVisitDto) {
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
                    text = visit.retailerName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = visit.status,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = if (visit.status == "COMPLETED") RFColors.Success else RFColors.Accent
                )
            }

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Salesperson: ${visit.employeeName} · Beat: ${visit.beatId}",
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            val checkInStr = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date(visit.checkInTime))
            val checkOutStr = visit.checkOutTime?.let { SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date(it)) } ?: "In Progress"
            val durationMin = visit.durationSeconds / 60

            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "Time: $checkInStr - $checkOutStr (${durationMin}m duration)",
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Orders Booked: ${visit.ordersCount}",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (visit.ordersCount > 0) RFColors.Success else RFColors.TextPrimary
                )
                Text(
                    text = "Stock Checks: ${visit.stockChecksCount}",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = RFColors.Accent
                )
            }

            if (!visit.noOrderReason.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "No Order Reason: ${visit.noOrderReason}",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.Warning
                )
            }

            if (visit.locationDiscrepancy) {
                Spacer(modifier = Modifier.height(10.dp))
                Surface(
                    color = Color(0xFFFEF2F2),
                    shape = RoundedCornerShape(6.dp),
                    border = BorderStroke(1.dp, Color(0xFFFECACA))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFDC2626), modifier = Modifier.size(16.dp))
                        Text(
                            text = "Geo Warning: Check-in was far from registered shop pin",
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFFB91C1C),
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

        }
    }
}
