package com.routeflow.app.feature.sales

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RouteFlowStatus

@Composable
fun OrderBookingScreen(
    state: OrderBookingState,
    onSearchChange: (String) -> Unit,
    onCategorySelect: (String?) -> Unit,
    onQuantityChange: (String, Int) -> Unit,
    onSubmit: () -> Unit
) {
    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        Column(Modifier.fillMaxSize()) {
            SearchBar(state.searchQuery, onSearchChange)
            CategoryFilter(state.categories, state.selectedCategory, onCategorySelect)
            
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(state.products) { item ->
                    ProductCard(item, state.cart[item.product.id] ?: 0, onQuantityChange)
                }
            }
            
            CartSummary(state.totalAmountPaise, state.cart.isNotEmpty(), onSubmit)
        }
    }
}

@Composable
private fun SearchBar(query: String, onQueryChange: (String) -> Unit) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = Modifier.fillMaxWidth().padding(20.dp),
        placeholder = { Text("Search products...") },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
        singleLine = true,
        shape = MaterialTheme.shapes.medium
    )
}

@Composable
private fun CategoryFilter(categories: List<String>, selected: String?, onSelect: (String?) -> Unit) {
    LazyRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            FilterChip(
                selected = selected == null,
                onClick = { onSelect(null) },
                label = { Text("All") }
            )
        }
        items(categories) { category ->
            FilterChip(
                selected = selected == category,
                onClick = { onSelect(category) },
                label = { Text(category) }
            )
        }
    }
}

@Composable
private fun ProductCard(item: ProductItemState, quantity: Int, onQuantityChange: (String, Int) -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(item.product.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text("${item.product.unit} · ${CurrencyFormatter.formatPaise(item.product.pricePaise)}", 
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Stock: ${item.product.stockQuantity}", style = MaterialTheme.typography.labelSmall, 
                    color = if (item.product.stockQuantity < 10) RouteFlowStatus.Rejected else Color.Unspecified)
                
                if (item.freeQuantity > 0) {
                    Text("Promo: ${item.freeQuantity} free units applied", 
                        style = MaterialTheme.typography.labelSmall, color = RouteFlowStatus.Completed)
                }
            }
            
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = { onQuantityChange(item.product.id, -1) }, enabled = quantity > 0) {
                    Icon(Icons.Default.Remove, contentDescription = null)
                }
                Text(quantity.toString(), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                IconButton(onClick = { onQuantityChange(item.product.id, 1) }, enabled = quantity < item.product.stockQuantity) {
                    Icon(Icons.Default.Add, contentDescription = null)
                }
            }
        }
    }
}

@Composable
private fun CartSummary(totalPaise: Long, hasItems: Boolean, onSubmit: () -> Unit) {
    Surface(shadowElevation = 8.dp, tonalElevation = 2.dp) {
        Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
            Column {
                Text("Total Amount", style = MaterialTheme.typography.labelSmall)
                Text(CurrencyFormatter.formatPaise(totalPaise), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
            }
            Button(onClick = onSubmit, enabled = hasItems, modifier = Modifier.height(56.dp).padding(start = 16.dp)) {
                Text("Submit Order")
            }
        }
    }
}
