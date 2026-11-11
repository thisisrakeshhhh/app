package com.routeflow.app.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.domain.model.OrderSyncState

@Composable
fun OrderSyncBadge(
    state: OrderSyncState,
    errorMessage: String? = null,
    modifier: Modifier = Modifier
) {
    val (label, bgColor, textColor, icon) = when (state) {
        OrderSyncState.SAVED_OFFLINE -> Quadruple(
            "Saved Offline",
            Color(0xFFFEF3C7), // Amber 100
            Color(0xFF92400E), // Amber 800
            Icons.Default.CloudOff
        )
        OrderSyncState.SYNCING -> Quadruple(
            "Syncing…",
            Color(0xFFDBEAFE), // Blue 100
            Color(0xFF1E40AF), // Blue 800
            Icons.Default.Sync
        )
        OrderSyncState.SYNCED -> Quadruple(
            "Synced",
            Color(0xFFD1FAE5), // Emerald 100
            Color(0xFF065F46), // Emerald 800
            Icons.Default.CheckCircle
        )
        OrderSyncState.NEEDS_ATTENTION -> Quadruple(
            "Needs Attention",
            Color(0xFFFEE2E2), // Red 100
            Color(0xFF991B1B), // Red 800
            Icons.Default.ErrorOutline
        )
    }

    Column(modifier = modifier) {
        Box(
            modifier = Modifier
                .background(bgColor, shape = RoundedCornerShape(12.dp))
                .border(1.dp, textColor.copy(alpha = 0.3f), shape = RoundedCornerShape(12.dp))
                .padding(horizontal = 8.dp, vertical = 4.dp),
            contentAlignment = Alignment.Center
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (state == OrderSyncState.SYNCING) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(12.dp),
                        strokeWidth = 1.5.dp,
                        color = textColor
                    )
                } else {
                    Icon(
                        imageVector = icon,
                        contentDescription = label,
                        tint = textColor,
                        modifier = Modifier.size(13.dp)
                    )
                }
                Spacer(Modifier.width(4.dp))
                Text(
                    text = label,
                    color = textColor,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
        if (state == OrderSyncState.NEEDS_ATTENTION && !errorMessage.isNullOrBlank()) {
            Text(
                text = errorMessage,
                color = textColor,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 2.dp, start = 4.dp)
            )
        }
    }
}

private data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
