package com.routeflow.app.feature.owner

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
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
    var rejectingOrder by remember { mutableStateOf<OrderDetailState?>(null) }

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else if (state.orders.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = Color(0xFFECFDF5),
                    modifier = Modifier.size(64.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = Color(0xFF10B981),
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }
                Text(
                    "All Orders Clear",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A)
                )
                Text(
                    "No pending order approval requests in queue.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color(0xFF64748B)
                )
            }
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = "Order Approvals",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF0F172A)
                        )
                        Text(
                            text = "${state.orders.size} orders waiting for owner credit & stock review",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF64748B)
                        )
                    }
                }
            }

            items(state.orders, key = { it.order.id }) { detail ->
                OrderApprovalCard(
                    detail = detail,
                    onApprove = { onApprove(detail.order.id) },
                    onRejectClick = { rejectingOrder = detail }
                )
            }
        }
    }

    rejectingOrder?.let { detail ->
        OrderRejectDialog(
            orderId = detail.order.id,
            retailerName = detail.retailerName,
            onDismiss = { rejectingOrder = null },
            onConfirmReject = { reason ->
                onReject(detail.order.id, reason)
                rejectingOrder = null
            }
        )
    }
}

@Composable
private fun OrderApprovalCard(
    detail: OrderDetailState,
    onApprove: () -> Unit,
    onRejectClick: () -> Unit
) {
    val isCreditOver = (detail.outstandingBalancePaise + detail.order.totalAmountPaise) > detail.creditLimitPaise

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color(0xFFF1F5F9)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            detail.order.id,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFF2563EB),
                            fontWeight = FontWeight.Bold
                        )
                        OrderSyncBadge(state = detail.syncState, errorMessage = detail.syncError)
                    }
                    Text(
                        detail.retailerName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF0F172A)
                    )
                }
                Text(
                    CurrencyFormatter.formatPaise(detail.order.totalAmountPaise),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Black,
                    color = Color(0xFF2563EB)
                )
            }

            // Financial & Stock Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Surface(
                    color = if (isCreditOver) Color(0xFFFEF2F2) else Color(0xFFECFDF5),
                    shape = CircleShape,
                    border = BorderStroke(1.dp, if (isCreditOver) Color(0xFFFECACA) else Color(0xFFA7F3D0))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .background(if (isCreditOver) Color(0xFFDC2626) else Color(0xFF10B981), CircleShape)
                        )
                        Text(
                            text = if (isCreditOver) "Credit Exceeded (Udhaar: ${CurrencyFormatter.formatPaise(detail.outstandingBalancePaise)})"
                            else "Credit OK (Limit: ${CurrencyFormatter.formatPaise(detail.creditLimitPaise)})",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = if (isCreditOver) Color(0xFFB91C1C) else Color(0xFF047857)
                        )
                    }
                }

                Surface(
                    color = if (detail.hasSufficientStock) Color(0xFFEFF6FF) else Color(0xFFFFFBEB),
                    shape = CircleShape,
                    border = BorderStroke(1.dp, if (detail.hasSufficientStock) Color(0xFFBFDBFE) else Color(0xFFFDE68A))
                ) {
                    Text(
                        text = if (detail.hasSufficientStock) "✓ Stock Ready" else "⚠️ Low Stock",
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = if (detail.hasSufficientStock) Color(0xFF1D4ED8) else Color(0xFFB45309)
                    )
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            // Items list
            detail.items.forEach { itemDetail ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "${itemDetail.product?.name ?: "Unknown"} × ${itemDetail.item.quantity}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF334155)
                    )
                    if (itemDetail.item.freeQuantity > 0) {
                        Text(
                            "+ ${itemDetail.item.freeQuantity} free",
                            style = MaterialTheme.typography.bodySmall,
                            color = RouteFlowStatus.Completed,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            HorizontalDivider(color = Color(0xFFF1F5F9))

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = onRejectClick,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("reject_order_${detail.order.id}"),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, Color(0xFFFECACA)),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = Color.White,
                        contentColor = Color(0xFFDC2626)
                    )
                ) {
                    Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Reject", fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = onApprove,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("approve_order_${detail.order.id}"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    ),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 1.dp)
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Approve", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun OrderRejectDialog(
    orderId: String,
    retailerName: String,
    onDismiss: () -> Unit,
    onConfirmReject: (reason: String) -> Unit
) {
    val reasons = listOf(
        "Credit limit exceeded",
        "Overdue pending payment",
        "Stock shortage in godown",
        "Shop unreachable / closed",
        "Price or quantity discrepancy"
    )
    var selectedReason by remember { mutableStateOf(reasons[0]) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Reject Order: $orderId", fontWeight = FontWeight.Bold)
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Select rejection reason for $retailerName:",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary
                )
                reasons.forEach { reason ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedReason == reason,
                            onClick = { selectedReason = reason }
                        )
                        Text(reason, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirmReject(selectedReason) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFFDC2626),
                    contentColor = Color.White
                )
            ) {
                Text("Confirm Rejection", color = Color.White)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
