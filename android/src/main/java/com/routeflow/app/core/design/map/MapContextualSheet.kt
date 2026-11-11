package com.routeflow.app.core.design.map

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Directions
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.PointOfSale
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.RFColors

/**
 * Compact contextual information sheet for Map-First UI (~25% screen height).
 * Reveals shop, delivery stop, or vehicle details and actionable workflows
 * without covering the map.
 */
@Composable
fun MapContextualSheet(
    marker: LogisticsMarker,
    onDismiss: () -> Unit,
    onPrimaryAction: () -> Unit,
    primaryActionLabel: String,
    primaryActionIcon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    onSecondaryAction: (() -> Unit)? = null,
    secondaryActionLabel: String? = null,
    secondaryActionIcon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Header Row: Badge, Title, Dismiss
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Type or Sequence Badge
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(
                                when (marker.type) {
                                    LogisticsMarkerType.DELIVERY_STOP -> Color(0xFFEFF6FF)
                                    LogisticsMarkerType.RETAILER -> Color(0xFFF0FDF4)
                                    LogisticsMarkerType.VEHICLE -> Color(0xFFFEF3C7)
                                    LogisticsMarkerType.WAREHOUSE_HUB -> Color(0xFFF1F5F9)
                                }
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (marker.sequenceNumber != null) {
                            Text(
                                text = "#${marker.sequenceNumber}",
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp,
                                color = RFColors.Primary
                            )
                        } else {
                            Icon(
                                imageVector = when (marker.type) {
                                    LogisticsMarkerType.DELIVERY_STOP -> Icons.Default.LocalShipping
                                    LogisticsMarkerType.RETAILER -> Icons.Default.Store
                                    LogisticsMarkerType.VEHICLE -> Icons.Default.LocalShipping
                                    LogisticsMarkerType.WAREHOUSE_HUB -> Icons.Default.VerifiedUser
                                },
                                contentDescription = null,
                                tint = RFColors.Primary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = marker.title,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        marker.subtitle?.let {
                            Text(
                                text = it,
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFF64748B),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }

                // Close Button
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color(0xFF94A3B8),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Financial & Status Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Balance / Udhaar / COD Amount
                marker.balancePaise?.let { balance ->
                    val isDebit = balance > 0
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = if (isDebit) Color(0xFFFEF2F2) else Color(0xFFF0FDF4),
                        border = BorderStroke(1.dp, if (isDebit) Color(0xFFFECACA) else Color(0xFFBBF7D0))
                    ) {
                        Text(
                            text = if (marker.type == LogisticsMarkerType.DELIVERY_STOP) {
                                "COD: ${CurrencyFormatter.formatPaise(balance)}"
                            } else {
                                "Udhaar: ${CurrencyFormatter.formatPaise(balance)}"
                            },
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isDebit) Color(0xFFDC2626) else Color(0xFF16A34A),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }
                }

                // Credit limit if available
                marker.creditLimitPaise?.let { limit ->
                    if (limit > 0) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = Color(0xFFF8FAFC),
                            border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                        ) {
                            Text(
                                text = "Limit: ${CurrencyFormatter.formatPaise(limit)}",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = Color(0xFF64748B),
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                            )
                        }
                    }
                }

                // Address preview if available
                marker.address?.takeIf { it.isNotBlank() }?.let { addr ->
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = null,
                            tint = Color(0xFF94A3B8),
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = addr,
                            fontSize = 11.sp,
                            color = Color(0xFF64748B),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }

            // Action Buttons Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Secondary action (e.g. Visit / Call / Navigate)
                if (onSecondaryAction != null && secondaryActionLabel != null) {
                    OutlinedButton(
                        onClick = onSecondaryAction,
                        modifier = Modifier
                            .weight(1f)
                            .height(44.dp),
                        shape = RoundedCornerShape(12.dp),
                        border = BorderStroke(1.5.dp, RFColors.Primary),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = RFColors.Primary),
                        contentPadding = PaddingValues(horizontal = 8.dp)
                    ) {
                        if (secondaryActionIcon != null) {
                            Icon(
                                imageVector = secondaryActionIcon,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                        }
                        Text(
                            text = secondaryActionLabel,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1
                        )
                    }
                }

                // Primary action (e.g. Van Spot Sale / Deliver Order)
                Button(
                    onClick = onPrimaryAction,
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RFColors.Primary,
                        contentColor = Color.White
                    ),
                    contentPadding = PaddingValues(horizontal = 8.dp)
                ) {
                    if (primaryActionIcon != null) {
                        Icon(
                            imageVector = primaryActionIcon,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                    }
                    Text(
                        text = primaryActionLabel,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1
                    )
                }

                // Phone quick dial button
                marker.contactPhone?.takeIf { it.isNotBlank() }?.let { phone ->
                    IconButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
                            context.startActivity(intent)
                        },
                        modifier = Modifier
                            .size(44.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color(0xFFF1F5F9))
                    ) {
                        Icon(
                            imageVector = Icons.Default.Phone,
                            contentDescription = "Call",
                            tint = Color(0xFF16A34A),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}
