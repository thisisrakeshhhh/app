package com.routeflow.app.feature.delivery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RouteFlowStatus

@Composable
fun DeliveryDetailScreen(
    orderId: String,
    retailerName: String,
    amountPaise: Long,
    onDeliver: (String) -> Unit
) {
    var deliveryCode by remember { mutableStateOf("") }
    var paymentMethod by remember { mutableStateOf("CASH") }
    val isCodeValid = deliveryCode == "4829"

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Column {
            Text(orderId, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            Text(retailerName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
            Text("Total Due: ${CurrencyFormatter.formatPaise(amountPaise)}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text("Verification", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                OutlinedTextField(
                    value = deliveryCode,
                    onValueChange = { deliveryCode = it },
                    label = { Text("Enter Delivery Code (Demo: 4829)") },
                    modifier = Modifier.fillMaxWidth(),
                    isError = deliveryCode.isNotEmpty() && !isCodeValid
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Payment Recording", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = paymentMethod == "CASH", onClick = { paymentMethod = "CASH" })
                    Text("Record Cash Payment", style = MaterialTheme.typography.bodyLarge)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = paymentMethod == "CREDIT", onClick = { paymentMethod = "CREDIT" })
                    Text("Mark as Credit", style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        Spacer(Modifier.weight(1f))

        Button(
            onClick = { onDeliver(paymentMethod) },
            enabled = isCodeValid,
            modifier = Modifier.fillMaxWidth().height(56.dp)
        ) {
            Text("Confirm Delivery")
        }
    }
}
