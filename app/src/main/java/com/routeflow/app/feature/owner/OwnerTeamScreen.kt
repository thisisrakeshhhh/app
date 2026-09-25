package com.routeflow.app.feature.owner

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.R
import com.routeflow.app.core.design.RFColors
import com.routeflow.app.core.network.dto.TeamMemberStatusDto
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OwnerTeamScreen(
    state: OwnerTeamState,
    onRefresh: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.team_monitor_title), fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.refresh))
                    }
                }
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (state.isLoading && state.teamMembers.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else if (state.teamMembers.isEmpty()) {
                Text(
                    text = "No active field staff found.",
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(24.dp),
                    style = MaterialTheme.typography.bodyLarge,
                    color = RFColors.TextSecondary
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(state.teamMembers, key = { it.id }) { member ->
                        TeamMemberCard(member = member)
                    }
                }
            }
        }
    }
}

@Composable
private fun TeamMemberCard(member: TeamMemberStatusDto) {
    val context = LocalContext.current
    val isOnShift = member.shiftStatus == "ON_SHIFT"

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(if (isOnShift) RFColors.Success else Color.Gray)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = member.fullName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                }

                Text(
                    text = if (isOnShift) stringResource(R.string.on_shift) else stringResource(R.string.off_shift),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = if (isOnShift) RFColors.Success else Color.Gray
                )
            }

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${member.role} · Beats: ${if (member.assignedBeats.isEmpty()) "None" else member.assignedBeats.joinToString(", ")}",
                style = MaterialTheme.typography.bodySmall,
                color = RFColors.TextSecondary
            )

            if (member.shiftStartTime != null) {
                val timeStr = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date(member.shiftStartTime))
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Shift Started: $timeStr",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Progress bar for completed stops vs total stops
            val progress = if (member.totalStops > 0) member.completedStops.toFloat() / member.totalStops else 0f
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Stops Progress",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "${member.completedStops} / ${member.totalStops} completed",
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.Accent
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            LinearProgressIndicator(
                progress = progress,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(RoundedCornerShape(4.dp)),
                color = RFColors.Primary,
                trackColor = Color(0xFFE2E8F0)
            )

            // Live Location Info
            Spacer(modifier = Modifier.height(12.dp))
            if (member.lastLocation != null) {
                val loc = member.lastLocation
                val locAgeMin = (System.currentTimeMillis() - loc.timestamp) / 60000
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.LocationOn,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = if (loc.isStale) RFColors.Warning else RFColors.Success
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Lat: ${"%.4f".format(loc.latitude)}, Lng: ${"%.4f".format(loc.longitude)}",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        Text(
                            text = if (loc.isStale) "Stale location (${locAgeMin}m ago)" else "Updated ${locAgeMin}m ago (±${loc.accuracy.toInt()}m)",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (loc.isStale) RFColors.Warning else RFColors.Success
                        )
                    }

                    OutlinedButton(
                        onClick = {
                            val mapUri = Uri.parse("geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}(${Uri.encode(member.fullName)})")
                            val mapIntent = Intent(Intent.ACTION_VIEW, mapUri)
                            context.startActivity(mapIntent)
                        }
                    ) {
                        Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Map", style = MaterialTheme.typography.labelMedium)
                    }
                }
            } else {
                Text(
                    text = "No GPS location reported yet",
                    style = MaterialTheme.typography.labelSmall,
                    color = RFColors.TextSecondary
                )
            }
        }
    }
}
