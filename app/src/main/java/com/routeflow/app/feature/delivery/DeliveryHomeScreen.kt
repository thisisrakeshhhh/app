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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FormatListBulleted
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Route
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.design.map.LogisticsMarker
import com.routeflow.app.core.design.map.LogisticsMarkerStatus
import com.routeflow.app.core.design.map.LogisticsMarkerType
import com.routeflow.app.core.design.map.MapContextualSheet
import com.routeflow.app.core.design.map.RouteFlowMap
import com.routeflow.app.domain.model.Employee

/**
 * Map-First Delivery Logistics Dashboard.
 * 75% interactive route map plotting numbered delivery stops connected by route polylines.
 * Selecting a stop reveals order payment details, address, navigation, and one-tap delivery completion.
 */
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
    var isMapView by remember { mutableStateOf(true) }
    var selectedStopOrderId by remember { mutableStateOf<String?>(null) }

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        // Map delivery stops into unified LogisticsMarkers
        val markers = remember(deliveryList) {
            deliveryList.mapIndexed { index, stop ->
                LogisticsMarker(
                    id = stop.order.id,
                    title = stop.retailerName,
                    subtitle = "Stop #${stop.stopSequence} • ${stop.order.id.takeLast(6).uppercase()}",
                    latitude = stop.latitude,
                    longitude = stop.longitude,
                    type = LogisticsMarkerType.DELIVERY_STOP,
                    status = if (index == 0) LogisticsMarkerStatus.IN_PROGRESS else LogisticsMarkerStatus.PENDING,
                    sequenceNumber = stop.stopSequence,
                    balancePaise = stop.order.totalAmountPaise,
                    address = stop.retailerAddress,
                    contactPhone = stop.contactNumber,
                    orderId = stop.order.id,
                    retailerId = stop.order.retailerId
                )
            }
        }

        val selectedMarker = remember(selectedStopOrderId, markers) {
            markers.find { it.id == selectedStopOrderId }
        }

        val nextStop = deliveryList.firstOrNull()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background)
        ) {
            // 1. Compact Delivery Top Bar (Driver, Status, Stops & Cash Held)
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, RFColors.Border),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 10.dp),
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
                            text = if (isHindi) "सक्रिय वितरण रूट • ${state.assignedCount} स्टॉप्स" else "Active Route • ${state.assignedCount} Stops",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        // Cash Held Pill
                        Surface(
                            color = Color(0xFFF0FDF4),
                            shape = RoundedCornerShape(8.dp),
                            border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                        ) {
                            Text(
                                text = CurrencyFormatter.formatPaise(state.paymentsCollectedPaise),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF16A34A),
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }

                        // Duty status badge
                        Surface(
                            color = RFColors.SuccessLight,
                            shape = RoundedCornerShape(16.dp),
                            border = BorderStroke(1.dp, RFColors.Success.copy(alpha = 0.3f))
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
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

            if (isMapView) {
                // ==========================================
                // MAP-FIRST MODE (~75% SCREEN SPACE)
                // ==========================================
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {
                    RouteFlowMap(
                        markers = markers,
                        selectedMarkerId = selectedStopOrderId,
                        onMarkerSelected = { marker ->
                            selectedStopOrderId = marker.id
                        },
                        onDismissSelection = {
                            selectedStopOrderId = null
                        },
                        isMapView = true,
                        onToggleView = { isMapView = it },
                        enablePolylines = true,
                        modifier = Modifier.fillMaxSize()
                    )

                    // Docked Bottom Card / Contextual Information Sheet
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .align(Alignment.BottomCenter)
                    ) {
                        if (selectedMarker != null) {
                            // Marker Selected: Show order COD amount, address, and Deliver action
                            MapContextualSheet(
                                marker = selectedMarker,
                                onDismiss = { selectedStopOrderId = null },
                                primaryActionLabel = stringResource(R.string.deliver_order_action),
                                primaryActionIcon = Icons.Default.LocalShipping,
                                onPrimaryAction = {
                                    onDeliveryClick(selectedMarker.orderId ?: selectedMarker.id)
                                },
                                secondaryActionLabel = if (isHindi) "नेविगेट" else "Navigate",
                                secondaryActionIcon = Icons.Default.Navigation,
                                onSecondaryAction = {
                                    val lat = selectedMarker.latitude
                                    val lng = selectedMarker.longitude
                                    val uri = if (lat != 0.0 && lng != 0.0) {
                                        Uri.parse("geo:$lat,$lng?q=$lat,$lng(${Uri.encode(selectedMarker.title)})")
                                    } else {
                                        Uri.parse("geo:0,0?q=${Uri.encode(selectedMarker.address ?: selectedMarker.title)}")
                                    }
                                    try {
                                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                                    } catch (_: Exception) {}
                                }
                            )
                        } else if (nextStop != null) {
                            // No Marker Selected: Docked Next Stop Decision Card
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                shape = RoundedCornerShape(20.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White),
                                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                                elevation = CardDefaults.cardElevation(defaultElevation = 5.dp)
                            ) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(14.dp),
                                    verticalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                                        ) {
                                            Surface(
                                                shape = RoundedCornerShape(6.dp),
                                                color = RFColors.InfoLight
                                            ) {
                                                Text(
                                                    text = if (isHindi) "अगला स्टॉप #1" else "NEXT STOP #1",
                                                    style = MaterialTheme.typography.labelSmall,
                                                    fontWeight = FontWeight.Bold,
                                                    color = RFColors.Primary,
                                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                    fontSize = 11.sp
                                                )
                                            }
                                            Text(
                                                text = nextStop.retailerName,
                                                style = MaterialTheme.typography.titleMedium,
                                                fontWeight = FontWeight.Bold,
                                                color = RFColors.TextPrimary,
                                                maxLines = 1
                                            )
                                        }

                                        Text(
                                            text = "COD: ${CurrencyFormatter.formatPaise(nextStop.order.totalAmountPaise)}",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 13.sp,
                                            color = Color(0xFF16A34A)
                                        )
                                    }

                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
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
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(44.dp),
                                            shape = RoundedCornerShape(12.dp),
                                            border = BorderStroke(1.5.dp, RFColors.Primary),
                                            colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Primary),
                                            contentPadding = PaddingValues(horizontal = 8.dp)
                                        ) {
                                            Icon(Icons.Default.Navigation, contentDescription = null, modifier = Modifier.size(16.dp))
                                            Spacer(Modifier.width(6.dp))
                                            Text(if (isHindi) "नेविगेट" else "Navigate", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        }

                                        Button(
                                            onClick = { onDeliveryClick(nextStop.order.id) },
                                            modifier = Modifier
                                                .weight(1.3f)
                                                .height(44.dp),
                                            shape = RoundedCornerShape(12.dp),
                                            colors = ButtonDefaults.buttonColors(containerColor = RFColors.Primary)
                                        ) {
                                            Icon(Icons.Default.LocalShipping, contentDescription = null, modifier = Modifier.size(18.dp))
                                            Spacer(Modifier.width(6.dp))
                                            Text(if (isHindi) "डिलीवर करें (OTP)" else "Deliver Order", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                        }
                                    }
                                }
                            }
                        } else {
                            // All deliveries done
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White),
                                border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.CheckCircle,
                                        contentDescription = null,
                                        tint = Color(0xFF16A34A),
                                        modifier = Modifier.size(32.dp)
                                    )
                                    Column {
                                        Text(
                                            text = if (isHindi) "आज की सभी डिलीवरी पूर्ण!" else "All deliveries completed today!",
                                            style = MaterialTheme.typography.titleSmall,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFF15803D)
                                        )
                                        Text(
                                            text = if (isHindi) "कैश जमा करने हेतु हैंडओवर टैब पर जाएं।" else "Proceed to Handover tab to submit cash.",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = Color(0xFF64748B)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // ==========================================
                // LIST VIEW MODE (Full Scrollable Delivery List)
                // ==========================================
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(bottom = 24.dp)
                ) {
                    // Switcher back to map
                    item {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = Color.White,
                            border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = if (isHindi) "डिलीवरी सूची सक्रिय" else "Delivery List View Active",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp,
                                    color = RFColors.TextPrimary
                                )
                                TextButton(onClick = { isMapView = true }) {
                                    Icon(Icons.Default.Route, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text(if (isHindi) "नक्शा खोलें" else "Switch to Map", fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }

                    // Remaining Route Stops List
                    if (deliveryList.isNotEmpty()) {
                        item {
                            Text(
                                text = if (isHindi) "मार्ग के सभी स्टॉप्स (${deliveryList.size})" else "All Route Stops (${deliveryList.size})",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                        }

                        items(deliveryList, key = { it.order.id }) { stop ->
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
    }
}
