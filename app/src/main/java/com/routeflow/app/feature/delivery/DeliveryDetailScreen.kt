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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors

@Composable
fun DeliveryDetailScreen(
    orderId: String,
    retailerName: String,
    amountPaise: Long,
    detailState: DeliveryDetailState,
    onDeliver: (String) -> Unit,
    onClearError: () -> Unit = {}
) {
    var deliveryCode by remember { mutableStateOf("") }
    var paymentMethod by remember { mutableStateOf("CASH") }
    val focusManager = LocalFocusManager.current
    val scrollState = rememberScrollState()
    val isCodeValid = deliveryCode.trim() == "4829"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(horizontal = 20.dp, vertical = 16.dp)
            .imePadding()
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Column {
            Text(orderId, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            Text(retailerName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
            Text(
                "Total Due: ${CurrencyFormatter.formatPaise(amountPaise)}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
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

        Card(
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Verification Proof", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    androidx.compose.material3.TextButton(
                        onClick = {
                            deliveryCode = "4829"
                            if (detailState.error != null) onClearError()
                        },
                        modifier = Modifier.testTag("fill_demo_otp_button")
                    ) {
                        Text("Fill Demo OTP (4829)", style = MaterialTheme.typography.labelSmall)
                    }
                }
                OutlinedTextField(
                    value = deliveryCode,
                    onValueChange = {
                        deliveryCode = it
                        if (detailState.error != null) onClearError()
                    },
                    label = { Text("Delivery Code") },
                    supportingText = {
                        Text("Demo mock OTP: 4829 (Server-validated proof pending)")
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
                    ),
                    isError = deliveryCode.isNotEmpty() && !isCodeValid
                )
            }
        }

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

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = {
                focusManager.clearFocus()
                onDeliver(paymentMethod)
            },
            enabled = isCodeValid && !detailState.isLoading,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
                .testTag("confirm_delivery_button"),
            colors = ButtonDefaults.buttonColors(
                containerColor = RFColors.Primary,
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
                    "Confirm Delivery",
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        Spacer(Modifier.height(32.dp))
    }
}
