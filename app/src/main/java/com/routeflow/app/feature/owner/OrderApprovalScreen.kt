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
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.OrderSyncBadge
import com.routeflow.app.core.design.RFColors

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
                .background(RFColors.Background)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = RFColors.SuccessLight,
                    modifier = Modifier.size(64.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = RFColors.Success,
                            modifier = Modifier.size(36.dp)
                        )
                    }
                }
                Text(
                    "All Orders Clear",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Text(
                    "No pending order approval requests in queue.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = RFColors.TextSecondary
                )
            }
        }
    } else {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
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
                            color = RFColors.TextPrimary
                        )
                        Text(
                            text = "${state.orders.size} orders waiting for review",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary
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
        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, RFColors.Border),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
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
                            color = RFColors.Primary,
                            fontWeight = FontWeight.SemiBold
                        )
                        OrderSyncBadge(state = detail.syncState, errorMessage = detail.syncError)
                    }
                    Text(
                        detail.retailerName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                }
                Text(
                    CurrencyFormatter.formatPaise(detail.order.totalAmountPaise),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Primary
                )
            }

            // Financial & Stock Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Surface(
                    color = if (isCreditOver) RFColors.DangerLight else RFColors.SuccessLight,
                    shape = CircleShape,
                    border = BorderStroke(1.dp, if (isCreditOver) RFColors.Danger.copy(alpha = 0.3f) else RFColors.Success.copy(alpha = 0.3f))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .background(if (isCreditOver) RFColors.Danger else RFColors.Success, CircleShape)
                        )
                        Text(
                            text = if (isCreditOver) "Credit Exceeded (Udhaar: ${CurrencyFormatter.formatPaise(detail.outstandingBalancePaise)})"
                            else "Credit OK (Limit: ${CurrencyFormatter.formatPaise(detail.creditLimitPaise)})",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isCreditOver) RFColors.Danger else RFColors.Success
                        )
                    }
                }

                Surface(
                    color = if (detail.hasSufficientStock) RFColors.InfoLight else RFColors.WarningLight,
                    shape = CircleShape,
                    border = BorderStroke(1.dp, if (detail.hasSufficientStock) RFColors.Primary.copy(alpha = 0.3f) else RFColors.Warning.copy(alpha = 0.3f))
                ) {
                    Text(
                        text = if (detail.hasSufficientStock) "Stock Available" else "Low Stock",
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = if (detail.hasSufficientStock) RFColors.Primary else RFColors.Warning
                    )
                }
            }

            HorizontalDivider(color = RFColors.Border)

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
                        color = RFColors.TextPrimary
                    )
                    if (itemDetail.item.freeQuantity > 0) {
                        Text(
                            "+ ${itemDetail.item.freeQuantity} free",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.Success,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            HorizontalDivider(color = RFColors.Border)

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = onRejectClick,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("reject_order_${detail.order.id}"),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, RFColors.Danger.copy(alpha = 0.3f)),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = RFColors.Surface,
                        contentColor = RFColors.Danger
                    )
                ) {
                    Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Reject", fontWeight = FontWeight.SemiBold)
                }
                Button(
                    onClick = onApprove,
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp)
                        .testTag("approve_order_${detail.order.id}"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    ),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp)
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Approve", color = Color.White, fontWeight = FontWeight.SemiBold)
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
        "Out of stock",
        "Retailer requested cancellation",
        "Payment dispute",
        "Other"
    )
    var selectedReason by remember { mutableStateOf(reasons[0]) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                "Reject Order ${orderId.takeLast(6)}?",
                fontWeight = FontWeight.Bold,
                color = RFColors.TextPrimary
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "Select rejection reason for $retailerName:",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
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
                        Spacer(Modifier.width(8.dp))
                        Text(reason, style = MaterialTheme.typography.bodyMedium, color = RFColors.TextPrimary)
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirmReject(selectedReason) },
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.Danger,
                    contentColor = Color.White
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Confirm Reject", fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = RFColors.TextSecondary)
            }
        }
    )
}
