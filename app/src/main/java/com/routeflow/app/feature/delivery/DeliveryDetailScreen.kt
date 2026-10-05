package com.routeflow.app.feature.delivery

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.routeflow.app.BuildConfig
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.DeliveryItemCompletionRequest
import kotlinx.coroutines.flow.Flow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeliveryDetailScreen(
    orderId: String,
    retailerName: String,
    amountPaise: Long,
    detailState: DeliveryDetailState,
    itemsFlow: Flow<List<DeliveryOrderItemUiModel>>? = null,
    onDeliver: (paymentMethod: String, otp: String, recipientName: String, items: List<DeliveryItemCompletionRequest>?) -> Unit,
    onDeliveryFailed: (reason: String, rescheduledDate: String?, notes: String?) -> Unit = { _, _, _ -> },
    onRequestOtp: () -> Unit = {},
    onClearError: () -> Unit = {}
) {
    var recipientName by remember { mutableStateOf("") }
    var deliveryCode by remember { mutableStateOf("") }
    var paymentMethod by remember { mutableStateOf("CASH") }
    var showFailDialog by remember { mutableStateOf(false) }
    var failReason by remember { mutableStateOf("SHOP_CLOSED") }
    var failRescheduledDate by remember { mutableStateOf("") }
    var failNotes by remember { mutableStateOf("") }

    val focusManager = LocalFocusManager.current
    val scrollState = rememberScrollState()

    val orderItems by itemsFlow?.collectAsState(initial = emptyList()) ?: remember { mutableStateOf(emptyList()) }

    // Map of productId to delivered paid quantity
    val deliveredPaidMap = remember { mutableStateMapOf<String, Int>() }
    // Map of productId to delivered free quantity
    val deliveredFreeMap = remember { mutableStateMapOf<String, Int>() }
    // Map of productId to undelivered reason
    val undeliveredReasonMap = remember { mutableStateMapOf<String, String>() }

    // Initialize item quantities when orderItems load
    LaunchedEffect(orderItems) {
        orderItems.forEach { item ->
            if (!deliveredPaidMap.containsKey(item.productId)) {
                deliveredPaidMap[item.productId] = item.orderedQuantity
            }
            if (!deliveredFreeMap.containsKey(item.productId)) {
                deliveredFreeMap[item.productId] = item.freeQuantity
            }
            if (!undeliveredReasonMap.containsKey(item.productId)) {
                undeliveredReasonMap[item.productId] = "SHORTAGE"
            }
        }
    }

    val deliveredAmountPaise = if (orderItems.isEmpty()) {
        amountPaise
    } else {
        orderItems.sumOf { item ->
            val paidQty = deliveredPaidMap[item.productId] ?: item.orderedQuantity
            paidQty.toLong() * item.pricePaise
        }
    }

    val isPartial = orderItems.isNotEmpty() && orderItems.any { item ->
        val paidDelivered = deliveredPaidMap[item.productId] ?: item.orderedQuantity
        val freeDelivered = deliveredFreeMap[item.productId] ?: item.freeQuantity
        paidDelivered < item.orderedQuantity || freeDelivered < item.freeQuantity
    }

    val totalDeliveredUnits = if (orderItems.isEmpty()) 1 else orderItems.sumOf {
        (deliveredPaidMap[it.productId] ?: it.orderedQuantity) + (deliveredFreeMap[it.productId] ?: it.freeQuantity)
    }

    val isFormValid = recipientName.trim().isNotEmpty() && deliveryCode.trim().length == 6 && totalDeliveredUnits > 0

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(horizontal = 20.dp, vertical = 16.dp)
            .imePadding()
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Column {
            Text(orderId, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            Text(retailerName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "Order Total: ${CurrencyFormatter.formatPaise(amountPaise)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (isPartial) {
                    Text(
                        "Delivered: ${CurrencyFormatter.formatPaise(deliveredAmountPaise)}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.Primary
                    )
                }
            }
        }

        if (detailState.error != null) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("delivery_error_card"),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFEE2E2)),
                border = BorderStroke(1.dp, RFColors.Error)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Default.ErrorOutline, contentDescription = null, tint = RFColors.Error)
                    Text(
                        text = detailState.error,
                        style = MaterialTheme.typography.bodyMedium,
                        color = RFColors.Error,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        if (detailState.otpSentMessage != null) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("otp_sent_card"),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
                border = BorderStroke(1.dp, RFColors.Primary)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = RFColors.Primary)
                    Text(
                        text = detailState.otpSentMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        color = RFColors.Primary,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        // --- Item Breakdown & Quantity Adjustment ---
        if (orderItems.isNotEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        stringResource(R.string.delivery_item_breakdown),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )

                    orderItems.forEach { item ->
                        val currentDeliveredPaid = deliveredPaidMap[item.productId] ?: item.orderedQuantity
                        val undeliveredPaid = item.orderedQuantity - currentDeliveredPaid

                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(item.productName, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        "Ordered: ${item.orderedQuantity} @ ${CurrencyFormatter.formatPaise(item.pricePaise)}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    IconButton(
                                        onClick = {
                                            if (currentDeliveredPaid > 0) {
                                                deliveredPaidMap[item.productId] = currentDeliveredPaid - 1
                                            }
                                        },
                                        enabled = currentDeliveredPaid > 0,
                                        modifier = Modifier.size(32.dp).testTag("item_minus_${item.productId}")
                                    ) {
                                        Icon(Icons.Default.Remove, contentDescription = "Decrease")
                                    }

                                    Text(
                                        text = "$currentDeliveredPaid / ${item.orderedQuantity}",
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.bodyMedium,
                                        modifier = Modifier.testTag("item_delivered_qty_${item.productId}")
                                    )

                                    IconButton(
                                        onClick = {
                                            if (currentDeliveredPaid < item.orderedQuantity) {
                                                deliveredPaidMap[item.productId] = currentDeliveredPaid + 1
                                            }
                                        },
                                        enabled = currentDeliveredPaid < item.orderedQuantity,
                                        modifier = Modifier.size(32.dp).testTag("item_plus_${item.productId}")
                                    ) {
                                        Icon(Icons.Default.Add, contentDescription = "Increase")
                                    }
                                }
                            }

                            if (undeliveredPaid > 0) {
                                val currentReason = undeliveredReasonMap[item.productId] ?: "SHORTAGE"
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        "Undelivered: $undeliveredPaid (${stringResource(R.string.undelivered_reason)}):",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = RFColors.Error
                                    )

                                    var expanded by remember { mutableStateOf(false) }
                                    ExposedDropdownMenuBox(
                                        expanded = expanded,
                                        onExpandedChange = { expanded = !expanded },
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        OutlinedTextField(
                                            value = currentReason,
                                            onValueChange = {},
                                            readOnly = true,
                                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                            modifier = Modifier.menuAnchor().fillMaxWidth().testTag("reason_dropdown_${item.productId}"),
                                            textStyle = MaterialTheme.typography.bodySmall
                                        )
                                        ExposedDropdownMenu(
                                            expanded = expanded,
                                            onDismissRequest = { expanded = false }
                                        ) {
                                            listOf("SHORTAGE", "DAMAGED", "REFUSED", "SHOP_CLOSED", "OTHER").forEach { reasonOption ->
                                                DropdownMenuItem(
                                                    text = { Text(reasonOption, style = MaterialTheme.typography.bodySmall) },
                                                    onClick = {
                                                        undeliveredReasonMap[item.productId] = reasonOption
                                                        expanded = false
                                                    }
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

        // --- Receiver & Delivery Proof Card ---
        Card(
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Receiver & Delivery Proof", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)

                OutlinedTextField(
                    value = recipientName,
                    onValueChange = {
                        recipientName = it
                        if (detailState.error != null) onClearError()
                    },
                    label = { Text("Receiver / Store Person Name *") },
                    placeholder = { Text("e.g. Ramesh Kumar (Store Manager)") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("recipient_name_input"),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Delivery OTP (6 digits)", style = MaterialTheme.typography.labelMedium)
                    OutlinedButton(
                        onClick = onRequestOtp,
                        enabled = !detailState.isOtpLoading,
                        modifier = Modifier.testTag("request_otp_button")
                    ) {
                        if (detailState.isOtpLoading) {
                            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Text("Request / Resend OTP", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }

                if (BuildConfig.DEBUG && detailState.serverDebugOtp != null) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(
                            onClick = {
                                deliveryCode = detailState.serverDebugOtp
                                if (detailState.error != null) onClearError()
                            },
                            modifier = Modifier.testTag("use_received_otp_chip")
                        ) {
                            Text("Use Received OTP: ${detailState.serverDebugOtp}", style = MaterialTheme.typography.labelSmall, color = RFColors.Primary)
                        }
                    }
                }

                OutlinedTextField(
                    value = deliveryCode,
                    onValueChange = {
                        if (it.length <= 6) {
                            deliveryCode = it
                            if (detailState.error != null) onClearError()
                        }
                    },
                    label = { Text("6-digit Server OTP *") },
                    supportingText = {
                        Text("Ask the retailer for the 6-digit code received via SMS/notification")
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("delivery_code_input"),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Done
                    ),
                    keyboardActions = KeyboardActions(
                        onDone = { focusManager.clearFocus() }
                    )
                )
            }
        }

        // --- Payment Method Card ---
        Card(
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Payment Method", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = paymentMethod == "CASH",
                        onClick = { paymentMethod = "CASH" }
                    )
                    Text("Cash Payment (Immediate settlement)", style = MaterialTheme.typography.bodyLarge)
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    RadioButton(
                        selected = paymentMethod == "CREDIT",
                        onClick = { paymentMethod = "CREDIT" }
                    )
                    Text("Mark as Credit (Add to ledger)", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        // Confirm Delivery Button (Full or Partial)
        Button(
            onClick = {
                focusManager.clearFocus()
                val itemsPayload = if (orderItems.isEmpty()) null else orderItems.map { item ->
                    val delPaid = deliveredPaidMap[item.productId] ?: item.orderedQuantity
                    val delFree = deliveredFreeMap[item.productId] ?: item.freeQuantity
                    val undelPaid = item.orderedQuantity - delPaid
                    val undelFree = item.freeQuantity - delFree
                    DeliveryItemCompletionRequest(
                        productId = item.productId,
                        deliveredQuantity = delPaid,
                        deliveredFreeQuantity = delFree,
                        undeliveredQuantity = undelPaid,
                        undeliveredFreeQuantity = undelFree,
                        undeliveredReason = if (undelPaid > 0 || undelFree > 0) (undeliveredReasonMap[item.productId] ?: "SHORTAGE") else null
                    )
                }
                onDeliver(paymentMethod, deliveryCode.trim(), recipientName.trim(), itemsPayload)
            },
            enabled = isFormValid && !detailState.isLoading,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .testTag("confirm_delivery_button"),
            shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF2563EB),
                disabledContainerColor = Color(0xFFCBD5E1)
            )
        ) {
            if (detailState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    if (isPartial) "Confirm Partial Delivery (${CurrencyFormatter.formatPaise(deliveredAmountPaise)})" else "Confirm Delivery",
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // Mark Delivery Failed Button
        OutlinedButton(
            onClick = { showFailDialog = true },
            enabled = !detailState.isLoading,
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .testTag("mark_failed_delivery_button"),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Error),
            border = BorderStroke(1.dp, RFColors.Error)
        ) {
            Text(stringResource(R.string.mark_delivery_failed), fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(32.dp))
    }

    // --- Delivery Failure Dialog ---
    if (showFailDialog) {
        AlertDialog(
            onDismissRequest = { showFailDialog = false },
            title = { Text(stringResource(R.string.mark_delivery_failed), fontWeight = FontWeight.Bold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(R.string.failure_reason), style = MaterialTheme.typography.labelMedium)

                    val reasons = listOf(
                        "SHOP_CLOSED" to stringResource(R.string.reason_shop_closed),
                        "REFUSED" to stringResource(R.string.reason_refused),
                        "DAMAGED" to stringResource(R.string.reason_damaged),
                        "SHORTAGE" to stringResource(R.string.reason_shortage),
                        "OTHER" to stringResource(R.string.reason_other)
                    )

                    reasons.forEach { (code, label) ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            RadioButton(
                                selected = failReason == code,
                                onClick = { failReason = code },
                                modifier = Modifier.testTag("radio_reason_$code")
                            )
                            Text(label, style = MaterialTheme.typography.bodyMedium)
                        }
                    }

                    OutlinedTextField(
                        value = failRescheduledDate,
                        onValueChange = { failRescheduledDate = it },
                        label = { Text(stringResource(R.string.rescheduled_date)) },
                        placeholder = { Text("e.g. 2026-10-01") },
                        modifier = Modifier.fillMaxWidth().testTag("rescheduled_date_input"),
                        singleLine = true
                    )

                    OutlinedTextField(
                        value = failNotes,
                        onValueChange = { failNotes = it },
                        label = { Text(stringResource(R.string.notes)) },
                        placeholder = { Text("e.g. Shop shutters closed") },
                        modifier = Modifier.fillMaxWidth().testTag("failure_notes_input")
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showFailDialog = false
                        onDeliveryFailed(
                            failReason,
                            failRescheduledDate.trim().ifEmpty { null },
                            failNotes.trim().ifEmpty { null }
                        )
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = RFColors.Error),
                    modifier = Modifier.testTag("confirm_failure_button")
                ) {
                    Text(stringResource(R.string.confirm_failed_delivery), color = Color.White)
                }
            },
            dismissButton = {
                TextButton(onClick = { showFailDialog = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }
}
