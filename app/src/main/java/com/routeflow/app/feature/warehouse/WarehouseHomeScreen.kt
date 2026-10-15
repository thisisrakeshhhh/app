package com.routeflow.app.feature.warehouse

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
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.PickingOrderDto
import com.routeflow.app.domain.model.Employee

@Composable
fun WarehouseHomeScreen(
    employee: Employee,
    state: WarehouseDashboardState,
    pickingOrders: List<PickingOrderDto> = emptyList(),
    onNavigateTab: (String) -> Unit,
    onScanBarcode: () -> Unit,
    currentLanguage: String = "en",
    onLanguageChange: (String) -> Unit = {}
) {
    if (state.isLoading) {
        Box(
            modifier = Modifier.fillMaxSize().background(RFColors.Background),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = RFColors.Primary)
        }
    } else {
        val isHindi = currentLanguage == "hi"
        var selectedQueueSection by remember { mutableStateOf("ALL") }

        val readyOrders = remember(pickingOrders) {
            pickingOrders.filter { it.status == "APPROVED" }
        }
        val inProgressOrders = remember(pickingOrders) {
            pickingOrders.filter { it.status == "PICKING" }
        }
        val packedOrders = remember(pickingOrders) {
            pickingOrders.filter { it.status == "PACKED" }
        }

        val displayedOrders = when (selectedQueueSection) {
            "READY" -> readyOrders
            "PICKING" -> inProgressOrders
            "PACKED" -> packedOrders
            else -> pickingOrders.filter { it.status == "APPROVED" || it.status == "PICKING" || it.status == "PACKED" }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 24.dp)
        ) {
            // 1. Warehouse Desk Header Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(1.dp, RFColors.Border),
                    elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = if (isHindi) "गोदाम कतार" else "Warehouse Work Queue",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = RFColors.TextPrimary
                                )
                                Text(
                                    text = employee.name.ifBlank { if (isHindi) "गोदाम स्टाफ" else "Godown Staff" },
                                    style = MaterialTheme.typography.bodySmall,
                                    fontWeight = FontWeight.Medium,
                                    color = RFColors.TextSecondary
                                )
                            }

                            // On Duty Pill
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
                                        text = if (isHindi) "ड्यूटी सक्रिय" else "On Duty",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = RFColors.Success
                                    )
                                }
                            }
                        }

                        // Quick Scan & Stock Action Strip
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedButton(
                                onClick = onScanBarcode,
                                modifier = Modifier.weight(1f).height(46.dp),
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, RFColors.Primary.copy(alpha = 0.3f)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = RFColors.InfoLight,
                                    contentColor = RFColors.Primary
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp)
                            ) {
                                Icon(Icons.Default.QrCodeScanner, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(if (isHindi) "बारकोड स्कैन" else "Scan SKU", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }

                            OutlinedButton(
                                onClick = { onNavigateTab("warehouse/stock") },
                                modifier = Modifier.weight(1f).height(46.dp),
                                shape = RoundedCornerShape(12.dp),
                                border = BorderStroke(1.dp, RFColors.Border),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = RFColors.Surface,
                                    contentColor = RFColors.TextPrimary
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp)
                            ) {
                                Icon(Icons.Default.Inventory2, contentDescription = null, modifier = Modifier.size(16.dp), tint = RFColors.TextSecondary)
                                Spacer(Modifier.width(6.dp))
                                Text(if (isHindi) "स्टॉक जाँच" else "Check Stock", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }

            // 2. Three Clear Queue Section Tabs (Ready to Pick, Picking, Packed)
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    QueueSectionTab(
                        modifier = Modifier.weight(1f),
                        label = if (isHindi) "पिकिंग तैयार" else "To Pick",
                        count = readyOrders.size,
                        isSelected = selectedQueueSection == "READY",
                        activeColor = RFColors.Warning,
                        onClick = {
                            selectedQueueSection = if (selectedQueueSection == "READY") "ALL" else "READY"
                        }
                    )
                    QueueSectionTab(
                        modifier = Modifier.weight(1f),
                        label = if (isHindi) "पिकिंग जारी" else "Picking",
                        count = inProgressOrders.size,
                        isSelected = selectedQueueSection == "PICKING",
                        activeColor = RFColors.Primary,
                        onClick = {
                            selectedQueueSection = if (selectedQueueSection == "PICKING") "ALL" else "PICKING"
                        }
                    )
                    QueueSectionTab(
                        modifier = Modifier.weight(1f),
                        label = if (isHindi) "पैक पूर्ण" else "Packed",
                        count = packedOrders.size,
                        isSelected = selectedQueueSection == "PACKED",
                        activeColor = RFColors.Success,
                        onClick = {
                            selectedQueueSection = if (selectedQueueSection == "PACKED") "ALL" else "PACKED"
                        }
                    )
                }
            }

            // 3. Queue Orders List
            item {
                Text(
                    text = when (selectedQueueSection) {
                        "READY" -> if (isHindi) "पिकिंग हेतु तैयार ऑर्डर (${readyOrders.size})" else "To Pick (${readyOrders.size})"
                        "PICKING" -> if (isHindi) "पिकिंग प्रगति पर (${inProgressOrders.size})" else "In Progress (${inProgressOrders.size})"
                        "PACKED" -> if (isHindi) "पैक किए गए ऑर्डर (${packedOrders.size})" else "Packed (${packedOrders.size})"
                        else -> if (isHindi) "सक्रिय गोदाम कार्य (${displayedOrders.size})" else "Active Orders (${displayedOrders.size})"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
            }

            if (displayedOrders.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(32.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = RFColors.Success,
                                modifier = Modifier.size(36.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = if (isHindi) "कतार खाली है" else "No orders in this queue",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold,
                                color = RFColors.TextPrimary
                            )
                            Text(
                                text = if (isHindi) "नए स्वीकृत ऑर्डर यहाँ दिखाई देंगे।" else "Approved orders from sales will appear here.",
                                style = MaterialTheme.typography.bodySmall,
                                color = RFColors.TextSecondary
                            )
                        }
                    }
                }
            } else {
                items(displayedOrders, key = { it.id }) { order ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = RFColors.Surface),
                        border = BorderStroke(1.dp, RFColors.Border),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
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
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = order.retailerName,
                                        style = MaterialTheme.typography.bodyLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = RFColors.TextPrimary
                                    )
                                    Text(
                                        text = "Order #${order.id.takeLast(6)} • ${order.items.size} items",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = RFColors.TextSecondary
                                    )
                                }

                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = when (order.status) {
                                        "APPROVED" -> RFColors.WarningLight
                                        "PICKING" -> RFColors.InfoLight
                                        "PACKED" -> RFColors.SuccessLight
                                        else -> RFColors.NeutralLight
                                    },
                                    border = BorderStroke(
                                        1.dp,
                                        when (order.status) {
                                            "APPROVED" -> RFColors.Warning.copy(alpha = 0.3f)
                                            "PICKING" -> RFColors.Primary.copy(alpha = 0.3f)
                                            "PACKED" -> RFColors.Success.copy(alpha = 0.3f)
                                            else -> RFColors.Border
                                        }
                                    )
                                ) {
                                    Text(
                                        text = when (order.status) {
                                            "APPROVED" -> if (isHindi) "पिकिंग बाकी" else "To Pick"
                                            "PICKING" -> if (isHindi) "पिकिंग जारी" else "Picking"
                                            "PACKED" -> if (isHindi) "पैक पूर्ण" else "Packed"
                                            else -> order.status
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = when (order.status) {
                                            "APPROVED" -> RFColors.Warning
                                            "PICKING" -> RFColors.Primary
                                            "PACKED" -> RFColors.Success
                                            else -> RFColors.TextSecondary
                                        },
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                        fontSize = 11.sp
                                    )
                                }
                            }

                            // Dynamic Primary Action Button
                            when (order.status) {
                                "APPROVED" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/picking") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = RFColors.Primary,
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "पिकिंग शुरू करें" else "Start Picking", fontWeight = FontWeight.SemiBold)
                                    }
                                }
                                "PICKING" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/picking") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = RFColors.Primary,
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "पिकिंग जारी रखें / पैक करें" else "Continue Picking / Pack", fontWeight = FontWeight.SemiBold)
                                    }
                                }
                                "PACKED" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/dispatch") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = RFColors.Success,
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.Default.LocalShipping, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "डिस्पैच तैयार — ड्राइवर आवंटन" else "Ready for Dispatch", fontWeight = FontWeight.SemiBold)
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
private fun QueueSectionTab(
    modifier: Modifier = Modifier,
    label: String,
    count: Int,
    isSelected: Boolean,
    activeColor: Color,
    onClick: () -> Unit
) {
    Card(
        modifier = modifier
            .height(58.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) RFColors.Surface else RFColors.NeutralLight
        ),
        border = BorderStroke(
            1.5.dp,
            if (isSelected) activeColor else RFColors.Border
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 6.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "$count",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = if (count > 0) activeColor else RFColors.TextSecondary
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = if (isSelected) activeColor else RFColors.TextSecondary,
                fontSize = 11.sp,
                maxLines = 1
            )
        }
    }
}
