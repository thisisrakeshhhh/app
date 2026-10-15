package com.routeflow.app.feature.owner

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.domain.model.Employee
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun OwnerHomeScreen(
    employee: Employee,
    state: OwnerHomeState,
    onViewApprovals: () -> Unit,
    onViewProducts: () -> Unit = {},
    onViewRetailers: () -> Unit = {},
    onViewEmployees: () -> Unit = {},
    onViewHandovers: () -> Unit = {},
    onViewCollections: () -> Unit = {},
    onViewReturns: () -> Unit = {},
    onViewTeam: () -> Unit = {},
    onViewReports: () -> Unit = {},
    onRefresh: () -> Unit = {}
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        val scrollState = rememberScrollState()
        val formattedDate = remember {
            SimpleDateFormat("EEEE, d MMMM", Locale.getDefault()).format(Date())
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(RFColors.Background)
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 1. Executive Greeting Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Good morning, ${employee.name} Ji",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.TextPrimary
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = formattedDate,
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }
                IconButton(onClick = onRefresh) {
                    Icon(
                        Icons.Default.Refresh,
                        contentDescription = "Refresh",
                        tint = RFColors.Primary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // 2. Primary Decision Panel: Orders Requiring Approval
            val pendingCount = state.pendingApprovalsCount
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onViewApprovals)
                    .testTag("primary_action_approvals"),
                shape = RoundedCornerShape(16.dp),
                color = if (pendingCount > 0) RFColors.InfoSurface else Color.White,
                border = BorderStroke(
                    1.dp,
                    if (pendingCount > 0) Color(0xFFBFDBFE) else RFColors.Border
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(18.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Surface(
                            shape = CircleShape,
                            color = if (pendingCount > 0) Color(0xFFDBEAFE) else Color(0xFFF1F5F9),
                            modifier = Modifier.size(44.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    Icons.Default.PendingActions,
                                    contentDescription = null,
                                    tint = if (pendingCount > 0) RFColors.Primary else RFColors.TextSecondary,
                                    modifier = Modifier.size(22.dp)
                                )
                            }
                        }

                        Column {
                            Text(
                                text = if (pendingCount > 0) {
                                    "$pendingCount ${if (pendingCount == 1) "order needs" else "orders need"} approval"
                                } else {
                                    "All orders approved"
                                },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = RFColors.TextPrimary
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = if (pendingCount > 0) {
                                    "Review wholesale credit & inventory checks"
                                } else {
                                    "Approval queue is clear"
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = if (pendingCount > 0) RFColors.Primary else RFColors.TextSecondary
                            )
                        }
                    }

                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (pendingCount > 0) RFColors.Primary else Color(0xFFF1F5F9)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Review",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                color = if (pendingCount > 0) Color.White else RFColors.TextSecondary
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                tint = if (pendingCount > 0) Color.White else RFColors.TextSecondary,
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }
            }

            // 3. Business Pulse: Single Horizontal Summary Surface (3 Lightweight Cells)
            Text(
                text = "Business Pulse",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = RFColors.TextPrimary
            )

            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                color = Color.White,
                border = BorderStroke(1.dp, RFColors.Border)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 16.dp, horizontal = 12.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Cell 1: Sales Today
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = CurrencyFormatter.formatPaise(state.deliveredSalesTodayPaise),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.TextPrimary
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Sales today",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary
                        )
                    }

                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(36.dp)
                            .background(RFColors.Border)
                    )

                    // Cell 2: Collected Today
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = CurrencyFormatter.formatPaise(state.cashCollectedTodayPaise),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.Success
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Collected today",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary
                        )
                    }

                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(36.dp)
                            .background(RFColors.Border)
                    )

                    // Cell 3: Market Credit
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = CurrencyFormatter.formatPaise(state.totalOutstandingPaise),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = if (state.totalOutstandingPaise > 0) RFColors.Warning else RFColors.TextPrimary
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Market credit",
                            style = MaterialTheme.typography.bodySmall,
                            color = RFColors.TextSecondary
                        )
                    }
                }
            }

            // 4. Attention Section: Maximum 3 Real Operational Issues
            Text(
                text = "Needs Attention",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = RFColors.TextPrimary
            )

            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                color = Color.White,
                border = BorderStroke(1.dp, RFColors.Border)
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    // Row 1: Low stock alert
                    AttentionRow(
                        icon = Icons.Default.Inventory2,
                        iconTint = if (state.lowStockCount > 0) RFColors.Warning else RFColors.Success,
                        iconBg = if (state.lowStockCount > 0) RFColors.WarningSurface else RFColors.SuccessSurface,
                        title = if (state.lowStockCount > 0) "${state.lowStockCount} low-stock products" else "Inventory healthy",
                        subtitle = if (state.lowStockCount > 0) "Replenishment needed" else "No critical stockouts",
                        statusText = if (state.lowStockCount > 0) "Review" else "OK",
                        onClick = onViewProducts
                    )

                    HorizontalDivider(color = RFColors.Border, thickness = 0.5.dp)

                    // Row 2: Cash Handover
                    AttentionRow(
                        icon = Icons.Default.AccountBalanceWallet,
                        iconTint = if (state.pendingHandoverCount > 0) RFColors.Primary else RFColors.Success,
                        iconBg = if (state.pendingHandoverCount > 0) RFColors.InfoSurface else RFColors.SuccessSurface,
                        title = if (state.pendingHandoverCount > 0) "${state.pendingHandoverCount} unsettled cash handover" else "All cash settled",
                        subtitle = if (state.pendingHandoverCount > 0) "Driver handover waiting" else "Zero pending handovers",
                        statusText = if (state.pendingHandoverCount > 0) "Settle" else "OK",
                        onClick = onViewHandovers
                    )

                    HorizontalDivider(color = RFColors.Border, thickness = 0.5.dp)

                    // Row 3: Delivery Exceptions
                    AttentionRow(
                        icon = Icons.Default.LocalShipping,
                        iconTint = if (state.failedDeliveriesCount > 0) RFColors.Danger else RFColors.Success,
                        iconBg = if (state.failedDeliveriesCount > 0) RFColors.DangerSurface else RFColors.SuccessSurface,
                        title = if (state.failedDeliveriesCount > 0) "${state.failedDeliveriesCount} failed delivery" else "Zero delivery exceptions",
                        subtitle = if (state.failedDeliveriesCount > 0) "Customer return or reattempt" else "All routes executing normally",
                        statusText = if (state.failedDeliveriesCount > 0) "Action" else "OK",
                        onClick = onViewReturns
                    )
                }
            }

            // 5. Operational Pulse Summary
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                color = Color.White,
                border = BorderStroke(1.dp, RFColors.Border)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(RFColors.Success)
                        )
                        Text(
                            text = "Field Team Pulse",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = RFColors.TextPrimary
                        )
                    }

                    Text(
                        text = "${state.staffOnDutyCount} active on duty",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.Success
                    )
                }
            }
        }
    }
}

@Composable
private fun AttentionRow(
    icon: ImageVector,
    iconTint: Color,
    iconBg: Color,
    title: String,
    subtitle: String,
    statusText: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Surface(
                shape = CircleShape,
                color = iconBg,
                modifier = Modifier.size(36.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = RFColors.TextPrimary
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = statusText,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = iconTint
            )
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = RFColors.TextSecondary,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
