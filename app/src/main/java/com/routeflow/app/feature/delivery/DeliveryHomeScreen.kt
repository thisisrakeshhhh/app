package com.routeflow.app.feature.delivery

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Employee

@Composable
fun DeliveryHomeScreen(
    employee: Employee,
    state: DeliveryHomeState,
    deliveryList: List<DeliveryItemState> = emptyList(),
    onDeliveryClick: (String) -> Unit = {},
    onViewDeliveries: () -> Unit = {},
    currentLanguage: String = "en"
) {
    val isHindi = currentLanguage == "hi"
    val context = LocalContext.current

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        val nextStop = deliveryList.firstOrNull()

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // 1. Driver Header Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, RFColors.Border),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = if (employee.name.isNotBlank()) employee.name else if (isHindi) "डिलीवरी एक्जीक्यूटिव" else "Delivery Executive",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                            Text(
                                text = if (isHindi) "सक्रिय वितरण रूट" else "Active Delivery Route",
                                style = MaterialTheme.typography.bodySmall,
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                        }

                        // Status Pill
                        Surface(
                            color = RFColors.SuccessLight,
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, RFColors.Success.copy(alpha = 0.3f))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(7.dp)
                                        .clip(CircleShape)
                                        .background(RFColors.Success)
                                )
                                Text(
                                    text = if (isHindi) "ड्यूटी पर" else "On Duty",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = RFColors.Success
                                )
                            }
                        }
                    }
                }
            }

            // 2. Route Metrics Row (Remaining Stops & Cash Held)
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Card(
                        modifier = Modifier.weight(1f),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(
                                text = if (isHindi) "शेष स्टॉप्स" else "Remaining Stops",
                                style = MaterialTheme.typography.labelSmall,
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = "${state.assignedCount}",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Primary
                            )
                        }
                    }

                    Card(
                        modifier = Modifier.weight(1.3f),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(
                                text = if (isHindi) "पास में नकद" else "Cash in Hand",
                                style = MaterialTheme.typography.labelSmall,
                                color = RFColors.TextSecondary,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = CurrencyFormatter.formatPaise(state.paymentsCollectedPaise),
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Success,
                                maxLines = 1
                            )
                        }
                    }
                }
            }

            // 3. Next Stop Card (Primary Decision Focus)
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                    border = BorderStroke(1.5.dp, RFColors.Primary),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = RFColors.InfoLight
                        ) {
                            Text(
                                text = if (isHindi) "अगला डिलीवरी स्टॉप" else "NEXT DELIVERY STOP",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.Primary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                fontSize = 11.sp
                            )
                        }

                        if (nextStop != null) {
                            Text(
                                text = nextStop.retailerName,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )

                            if (nextStop.retailerAddress.isNotBlank()) {
                                Text(
                                    text = nextStop.retailerAddress,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary,
                                    maxLines = 2
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = if (isHindi) "कुल देय राशि" else "Amount Due",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = RFColors.TextSecondary
                                )
                                Text(
                                    text = CurrencyFormatter.formatPaise(nextStop.order.totalAmountPaise),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        val lat = nextStop.latitude
                                        val lng = nextStop.longitude
                                        val uri = if (lat != 0.0 && lng != 0.0) {
                                            Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(nextStop.retailerName)})")
                                        } else {
                                            Uri.parse("geo:0,0?q=${Uri.encode(nextStop.retailerAddress)}")
                                        }
                                        try {
                                            context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                                        } catch (_: Exception) {}
                                    },
                                    modifier = Modifier.weight(1f).height(48.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    border = BorderStroke(1.dp, RFColors.Primary.copy(alpha = 0.3f)),
                                    colors = ButtonDefaults.outlinedButtonColors(
                                        containerColor = RFColors.InfoLight,
                                        contentColor = RFColors.Primary
                                    ),
                                    contentPadding = PaddingValues(horizontal = 8.dp)
                                ) {
                                    Icon(Icons.Default.Navigation, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(if (isHindi) "नेविगेट" else "Navigate", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                }

                                Button(
                                    onClick = { onDeliveryClick(nextStop.order.id) },
                                    modifier = Modifier.weight(1.3f).height(48.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = RFColors.Primary,
                                        contentColor = Color.White
                                    )
                                ) {
                                    Icon(Icons.Default.LocalShipping, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(if (isHindi) "डिलीवर करें (OTP)" else "Deliver (OTP)", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                                }
                            }
                        } else {
                            Text(
                                text = if (state.completedCount > 0) {
                                    if (isHindi) "सभी डिलीवरी पूर्ण हो गई हैं!" else "All deliveries completed for today!"
                                } else {
                                    if (isHindi) "कोई डिलीवरी आवंटित नहीं है" else "No deliveries assigned yet"
                                },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                            Text(
                                text = if (state.completedCount > 0) {
                                    if (isHindi) "रोकड़ सुपुर्दगी टैब में जाकर कैश जमा करें।" else "Go to Cash Handover tab to submit physical collections."
                                } else {
                                    if (isHindi) "वेयरहाउस द्वारा माल डिस्पैच होने पर स्टॉप्स यहाँ दिखेंगे।" else "Orders dispatched by warehouse will appear here."
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = RFColors.TextSecondary
                            )
                        }
                    }
                }
            }

            // 4. Remaining Route Stops List
            if (deliveryList.size > 1) {
                item {
                    Text(
                        text = if (isHindi) "शेष मार्ग स्टॉप्स (${deliveryList.size - 1})" else "Upcoming Stops (${deliveryList.size - 1})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                }

                items(deliveryList.drop(1), key = { it.order.id }) { stop ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onDeliveryClick(stop.order.id) },
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                modifier = Modifier.weight(1f),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Surface(
                                    shape = CircleShape,
                                    color = RFColors.InfoLight,
                                    modifier = Modifier.size(36.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Text(
                                            text = "${stop.stopSequence}",
                                            fontWeight = FontWeight.Bold,
                                            color = RFColors.Primary,
                                            fontSize = 14.sp
                                        )
                                    }
                                }

                                Column {
                                    Text(
                                        text = stop.retailerName,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = FontWeight.SemiBold,
                                        color = RFColors.TextPrimary
                                    )
                                    if (stop.retailerAddress.isNotBlank()) {
                                        Text(
                                            text = stop.retailerAddress,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = RFColors.TextSecondary,
                                            maxLines = 1
                                        )
                                    }
                                }
                            }

                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    text = CurrencyFormatter.formatPaise(stop.order.totalAmountPaise),
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Text(
                                    text = if (isHindi) "डिलीवर करें >" else "Deliver >",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = RFColors.Primary
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
