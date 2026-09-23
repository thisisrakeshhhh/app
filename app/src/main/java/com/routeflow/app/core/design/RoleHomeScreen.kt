package com.routeflow.app.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.routeflow.app.domain.model.Employee

@Composable
fun RoleHomeScreen(
    employee: Employee,
    title: String,
    location: String,
    emptyTitle: String,
    emptyMessage: String,
    upcoming: List<String>,
) {
    Column(
        Modifier.fillMaxSize().testTag("home_${employee.role.name}")
            .verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Text("Hello, ${employee.name}", style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.primary)
        Text(title, style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.semantics { heading() })
        Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(20.dp)) {
            Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                RoleIcon(employee.role, Modifier.size(32.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(location, style = MaterialTheme.typography.titleMedium)
                    Text("Wholesale Distributors", style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
        Surface(shape = RoundedCornerShape(20.dp),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
            EmptyState(emptyTitle, emptyMessage, Modifier.padding(20.dp))
        }
        Text("Coming in later milestones", style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() })
        upcoming.forEach { item ->
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(item, style = MaterialTheme.typography.bodyLarge)
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
        }
        Text("This is a demo workspace. No orders, collections or deliveries are recorded here.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
