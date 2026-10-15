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
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
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
            modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = RFColors.Primary)
        }
    } else {
        val isHindi = currentLanguage == "hi"
        var selectedQueueSection by remember { mutableStateOf("ALL") } // ALL, READY, PICKING, PACKED

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
                .background(Color(0xFFF8FAFC))
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(bottom = 120.dp)
        ) {
            // 1. Warehouse Desk Header Card
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    shape = RoundedCornerShape(12.dp),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
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
                                    fontWeight = FontWeight.Black,
                                    color = Color(0xFF0F172A)
                                )
                                Text(
                                    text = employee.name.ifBlank { if (isHindi) "गोदाम स्टाफ" else "Godown Staff" },
                                    style = MaterialTheme.typography.bodySmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color(0xFF64748B)
                                )
                            }

                            // On Duty Pill
                            Surface(
                                color = Color(0xFFF0FDF4),
                                shape = RoundedCornerShape(6.dp),
                                border = BorderStroke(1.dp, Color(0xFFBBF7D0))
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFF16A34A))
                                    )
                                    Text(
                                        text = if (isHindi) "ड्यूटी सक्रिय" else "On Duty",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF15803D)
                                    )
                                }
                            }
                        }

                        // Quick Scan & Stock Action Strip
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            OutlinedButton(
                                onClick = onScanBarcode,
                                modifier = Modifier.weight(1f).height(44.dp),
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, Color(0xFFBFDBFE)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = Color(0xFFEFF6FF),
                                    contentColor = Color(0xFF1D4ED8)
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp)
                            ) {
                                Icon(Icons.Default.QrCodeScanner, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(if (isHindi) "बारकोड स्कैन" else "Scan SKU", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }

                            OutlinedButton(
                                onClick = { onNavigateTab("warehouse/stock") },
                                modifier = Modifier.weight(1f).height(44.dp),
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                                colors = ButtonDefaults.outlinedButtonColors(
                                    containerColor = Color.White,
                                    contentColor = Color(0xFF334155)
                                ),
                                contentPadding = PaddingValues(horizontal = 10.dp)
                            ) {
                                Icon(Icons.Default.Inventory2, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(if (isHindi) "स्टॉक जाँच" else "Check Stock", fontWeight = FontWeight.Bold, fontSize = 12.sp)
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
                        label = if (isHindi) "पिकिंग तैयार" else "Ready to Pick",
                        count = readyOrders.size,
                        isSelected = selectedQueueSection == "READY",
                        activeColor = Color(0xFFEA580C),
                        onClick = {
                            selectedQueueSection = if (selectedQueueSection == "READY") "ALL" else "READY"
                        }
                    )
                    QueueSectionTab(
                        modifier = Modifier.weight(1f),
                        label = if (isHindi) "पिकिंग जारी" else "Picking",
                        count = inProgressOrders.size,
                        isSelected = selectedQueueSection == "PICKING",
                        activeColor = Color(0xFF2563EB),
                        onClick = {
                            selectedQueueSection = if (selectedQueueSection == "PICKING") "ALL" else "PICKING"
                        }
                    )
                    QueueSectionTab(
                        modifier = Modifier.weight(1f),
                        label = if (isHindi) "पैक पूर्ण" else "Packed",
                        count = packedOrders.size,
                        isSelected = selectedQueueSection == "PACKED",
                        activeColor = Color(0xFF16A34A),
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
                        "READY" -> if (isHindi) "पिकिंग हेतु तैयार ऑर्डर (${readyOrders.size})" else "Ready to Pick (${readyOrders.size})"
                        "PICKING" -> if (isHindi) "पिकिंग प्रगति पर (${inProgressOrders.size})" else "In Picking Progress (${inProgressOrders.size})"
                        "PACKED" -> if (isHindi) "पैक किए गए ऑर्डर (${packedOrders.size})" else "Packed Orders (${packedOrders.size})"
                        else -> if (isHindi) "सक्रिय गोदाम कार्य (${displayedOrders.size})" else "Active Warehouse Orders (${displayedOrders.size})"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0F172A)
                )
            }

            if (displayedOrders.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
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
                                tint = Color(0xFF16A34A),
                                modifier = Modifier.size(40.dp)
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = if (isHindi) "कतार खाली है" else "No orders in this queue",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF0F172A)
                            )
                            Text(
                                text = if (isHindi) "नए स्वीकृत ऑर्डर यहाँ दिखाई देंगे।" else "Approved orders from sales will appear here.",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF64748B)
                            )
                        }
                    }
                }
            } else {
                items(displayedOrders, key = { it.id }) { order ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
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
                                        color = Color(0xFF0F172A)
                                    )
                                    Text(
                                        text = "Order #${order.id.takeLast(6)} • ${order.items.size} items",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFF64748B)
                                    )
                                }

                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = when (order.status) {
                                        "APPROVED" -> Color(0xFFFFF7ED)
                                        "PICKING" -> Color(0xFFEFF6FF)
                                        "PACKED" -> Color(0xFFF0FDF4)
                                        else -> Color(0xFFF8FAFC)
                                    },
                                    border = BorderStroke(
                                        1.dp,
                                        when (order.status) {
                                            "APPROVED" -> Color(0xFFFED7AA)
                                            "PICKING" -> Color(0xFFBFDBFE)
                                            "PACKED" -> Color(0xFFBBF7D0)
                                            else -> Color(0xFFE2E8F0)
                                        }
                                    )
                                ) {
                                    Text(
                                        text = when (order.status) {
                                            "APPROVED" -> if (isHindi) "पिकिंग बाकी" else "Ready to Pick"
                                            "PICKING" -> if (isHindi) "पिकिंग जारी" else "Picking"
                                            "PACKED" -> if (isHindi) "पैक पूर्ण" else "Packed"
                                            else -> order.status
                                        },
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = when (order.status) {
                                            "APPROVED" -> Color(0xFFC2410C)
                                            "PICKING" -> Color(0xFF1D4ED8)
                                            "PACKED" -> Color(0xFF15803D)
                                            else -> Color(0xFF64748B)
                                        },
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                        fontSize = 11.sp
                                    )
                                }
                            }

                            // Dynamic Primary Action Button (Minimum 48dp touch target)
                            when (order.status) {
                                "APPROVED" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/picking") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = Color(0xFFEA580C),
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "पिकिंग शुरू करें" else "Start Picking", fontWeight = FontWeight.Bold)
                                    }
                                }
                                "PICKING" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/picking") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = Color(0xFF2563EB),
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "पिकिंग जारी रखें / पैक करें" else "Continue Picking / Pack", fontWeight = FontWeight.Bold)
                                    }
                                }
                                "PACKED" -> {
                                    Button(
                                        onClick = { onNavigateTab("warehouse/dispatch") },
                                        modifier = Modifier.fillMaxWidth().height(48.dp),
                                        shape = RoundedCornerShape(10.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = Color(0xFF16A34A),
                                            contentColor = Color.White
                                        )
                                    ) {
                                        Icon(Icons.Default.LocalShipping, contentDescription = null, modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(if (isHindi) "डिस्पैच तैयार — ड्राइवर आवंटन" else "Ready for Dispatch", fontWeight = FontWeight.Bold)
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
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) Color.White else Color(0xFFF8FAFC)
        ),
        border = BorderStroke(
            1.5.dp,
            if (isSelected) activeColor else Color(0xFFE2E8F0)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = if (isSelected) 2.dp else 0.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 6.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "$count",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Black,
                color = if (count > 0) activeColor else Color(0xFF64748B)
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                color = if (isSelected) activeColor else Color(0xFF64748B),
                fontSize = 11.sp,
                maxLines = 1
            )
        }
    }
}
