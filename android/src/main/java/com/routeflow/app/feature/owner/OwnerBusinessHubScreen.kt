package com.routeflow.app.feature.owner

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.Payments

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerBusinessHubScreen(
    state: OwnerMasterState,
    onNavigateProducts: () -> Unit,
    onNavigateRetailers: () -> Unit,
    onNavigateBeats: () -> Unit,
    onNavigateEmployees: () -> Unit,
    onNavigateHandovers: () -> Unit = {},
    onNavigateCollections: () -> Unit = {},
    onNavigateReturns: () -> Unit = {},
    onNavigateRoutes: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Operations, reconciliations & master data control",
            style = MaterialTheme.typography.bodySmall,
            color = RFColors.TextSecondary
        )
            Text(
                text = "Financial & Settlement Operations",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = RFColors.TextPrimary
            )

            BusinessCard(
                title = stringResource(R.string.owner_handover_reconciliation),
                subtitle = "Review & acknowledge driver and sales cash collections",
                icon = Icons.Default.AccountBalanceWallet,
                onClick = onNavigateHandovers
            )

            BusinessCard(
                title = stringResource(R.string.owner_payment_clearance),
                subtitle = "Verify UPI / bank transfers and clear customer cheques",
                icon = Icons.Default.Payments,
                onClick = onNavigateCollections
            )

            BusinessCard(
                title = stringResource(R.string.owner_returns_management),
                subtitle = "Authorize returns, inspect damaged goods & issue credit notes",
                icon = Icons.Default.AssignmentReturn,
                onClick = onNavigateReturns
            )

            Spacer(Modifier.height(8.dp))

            Text(
                text = "Master Data & Operations Setup",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = RFColors.TextPrimary
            )

            BusinessCard(
                title = stringResource(R.string.owner_tab_products),
                subtitle = "${state.products.size} Products in Catalog",
                icon = Icons.Default.Inventory2,
                onClick = onNavigateProducts
            )

            BusinessCard(
                title = stringResource(R.string.owner_tab_retailers),
                subtitle = "${state.retailers.size} Retailers Onboarded",
                icon = Icons.Default.Store,
                onClick = onNavigateRetailers
            )

            BusinessCard(
                title = stringResource(R.string.owner_tab_beats),
                subtitle = "${state.beats.size} Beats Configured",
                icon = Icons.Default.Map,
                onClick = onNavigateBeats
            )

            BusinessCard(
                title = "Daily Route Planning",
                subtitle = "Manual stop ordering with road route estimation",
                icon = Icons.Default.Map,
                onClick = onNavigateRoutes
            )

            BusinessCard(
                title = stringResource(R.string.owner_tab_employees),
                subtitle = "${state.employees.size} Team Members",
                icon = Icons.Default.People,
                onClick = onNavigateEmployees
            )

            Spacer(Modifier.height(120.dp))
        }
    }


@Composable
private fun BusinessCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFE2E8F0)),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                androidx.compose.material3.Surface(
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
                    color = RFColors.InfoSurface,
                    modifier = Modifier.size(44.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            icon,
                            contentDescription = null,
                            modifier = Modifier.size(24.dp),
                            tint = RFColors.Primary
                        )
                    }
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }
            }
            Icon(Icons.Default.ChevronRight, contentDescription = null, tint = RFColors.TextSecondary)
        }
    }
}
