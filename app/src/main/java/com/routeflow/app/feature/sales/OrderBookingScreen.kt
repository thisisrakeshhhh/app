package com.routeflow.app.feature.sales

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.routeflow.app.R
import com.routeflow.app.core.common.CurrencyFormatter
import com.routeflow.app.core.design.LoadingState
import com.routeflow.app.core.design.RFColors

@Composable
fun OrderBookingScreen(
    state: OrderBookingState,
    onSearchChange: (String) -> Unit,
    onCategorySelect: (String?) -> Unit,
    onQuantityChange: (String, Int) -> Unit,
    onSubmit: () -> Unit,
    onAddNewProduct: ((name: String, category: String, unit: String, priceRupees: Double, stock: Int) -> Unit)? = null
) {
    var showAddProductDialog by remember { mutableStateOf(false) }

    if (state.isLoading) {
        LoadingState(Modifier.fillMaxSize())
    } else {
        Column(Modifier.fillMaxSize().imePadding()) {
            // Search Bar & Optional Add Product Button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = state.searchQuery,
                    onValueChange = onSearchChange,
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Search warehouse items…", fontSize = 14.sp) },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp)
                )

                if (onAddNewProduct != null) {
                    Spacer(Modifier.width(8.dp))
                    FilledTonalButton(
                        onClick = { showAddProductDialog = true },
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                        modifier = Modifier.height(48.dp),
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = Color(0xFFEFF6FF),
                            contentColor = Color(0xFF2563EB)
                        )
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Add Item", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // Smooth Horizontal Category Chips Row
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp),
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item {
                    FilterChip(
                        selected = state.selectedCategory == null,
                        onClick = { onCategorySelect(null) },
                        label = { Text("All Products", fontWeight = FontWeight.SemiBold) },
                        shape = RoundedCornerShape(8.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(0xFF2563EB),
                            selectedLabelColor = Color.White
                        )
                    )
                }
                items(state.categories) { category ->
                    FilterChip(
                        selected = state.selectedCategory == category,
                        onClick = { onCategorySelect(category) },
                        label = { Text(category, fontWeight = FontWeight.SemiBold) },
                        shape = RoundedCornerShape(8.dp),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(0xFF2563EB),
                            selectedLabelColor = Color.White
                        )
                    )
                }
            }

            // Dense Product Cards List
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(state.products, key = { it.product.id }) { item ->
                    ProductCard(
                        item = item,
                        quantity = state.cart[item.product.id] ?: 0,
                        onQuantityChange = onQuantityChange
                    )
                }
            }

            // Sticky Cart Footer
            val totalItemsCount = state.cart.values.sum()
            CartSummary(
                totalPaise = state.cartTotalPaise,
                totalItemsCount = totalItemsCount,
                hasItems = state.cart.isNotEmpty(),
                isSubmitting = state.isSubmitting,
                onSubmit = onSubmit
            )
        }
    }

    if (showAddProductDialog && onAddNewProduct != null) {
        AddProductDialog(
            onDismiss = { showAddProductDialog = false },
            onConfirm = { name, category, unit, price, stock ->
                onAddNewProduct(name, category, unit, price, stock)
                showAddProductDialog = false
            }
        )
    }
}

@Composable
private fun ProductCard(
    item: ProductItemState,
    quantity: Int,
    onQuantityChange: (String, Int) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(
            1.dp,
            if (quantity > 0) Color(0xFF93C5FD) else Color(0xFFE2E8F0)
        ),
        shape = RoundedCornerShape(14.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = if (quantity > 0) 2.dp else 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Left info column
            Column(Modifier.weight(1f)) {
                Text(
                    text = item.product.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.TextPrimary
                )
                Spacer(Modifier.height(2.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = CurrencyFormatter.formatPaise(item.product.pricePaise),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF2563EB)
                    )
                    Text(
                        text = " / ${item.product.unit}",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF64748B)
                    )
                }

                Spacer(Modifier.height(6.dp))

                // Warehouse Stock Badge
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = when {
                        item.product.stockQuantity <= 0 -> Color(0xFFFEE2E2)
                        item.product.stockQuantity <= 10 -> Color(0xFFFEF3C7)
                        else -> Color(0xFFDCFCE7)
                    }
                ) {
                    Text(
                        text = when {
                            item.product.stockQuantity <= 0 -> "Out of Stock"
                            item.product.stockQuantity <= 10 -> "In Stock: ${item.product.stockQuantity} (Low Stock)"
                            else -> "In Stock: ${item.product.stockQuantity} units"
                        },
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = when {
                            item.product.stockQuantity <= 0 -> Color(0xFFDC2626)
                            item.product.stockQuantity <= 10 -> Color(0xFFD97706)
                            else -> Color(0xFF15803D)
                        }
                    )
                }

                // Scheme / Promo Badge
                if (item.product.name.contains("Chai", ignoreCase = true) || item.product.stockQuantity > 20) {
                    Spacer(Modifier.height(4.dp))
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = Color(0xFFFAF5FF),
                        border = BorderStroke(1.dp, Color(0xFFE9D5FF))
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Icon(Icons.Default.CardGiftcard, contentDescription = null, tint = Color(0xFF9333EA), modifier = Modifier.size(11.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(
                                text = "Scheme: Buy 10 Get 1 Free",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF9333EA),
                                fontSize = 11.sp
                            )
                        }
                    }
                }

                if (item.freeQuantity > 0) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = "+ ${item.freeQuantity} free bonus applied",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF16A34A),
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Spacer(Modifier.width(12.dp))

            // Quantity Stepper with >=48dp touch targets
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = if (quantity > 0) Color(0xFFEFF6FF) else Color(0xFFF8FAFC),
                border = BorderStroke(1.dp, if (quantity > 0) Color(0xFFBFDBFE) else Color(0xFFE2E8F0))
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Decrement Button (48dp x 48dp)
                    IconButton(
                        onClick = { onQuantityChange(item.product.id, -1) },
                        enabled = quantity > 0,
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Remove,
                            contentDescription = "Decrease",
                            modifier = Modifier.size(20.dp),
                            tint = if (quantity > 0) Color(0xFF1D4ED8) else Color(0xFFCBD5E1)
                        )
                    }

                    Text(
                        text = quantity.toString(),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Black,
                        color = if (quantity > 0) Color(0xFF1D4ED8) else RFColors.TextPrimary,
                        modifier = Modifier.padding(horizontal = 6.dp)
                    )

                    // Increment Button (48dp x 48dp)
                    IconButton(
                        onClick = { onQuantityChange(item.product.id, 1) },
                        enabled = quantity < item.product.stockQuantity,
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "Increase",
                            modifier = Modifier.size(20.dp),
                            tint = if (quantity < item.product.stockQuantity) Color(0xFF1D4ED8) else Color(0xFFCBD5E1)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AddProductDialog(
    onDismiss: () -> Unit,
    onConfirm: (name: String, category: String, unit: String, price: Double, stock: Int) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("General") }
    var unit by remember { mutableStateOf("Pack") }
    var priceText by remember { mutableStateOf("100.0") }
    var stockText by remember { mutableStateOf("50") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Inventory2, contentDescription = null, tint = Color(0xFF2563EB))
                Spacer(Modifier.width(10.dp))
                Text("Add Item Option", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Product / Item Name *") },
                    placeholder = { Text("e.g. Special Chai 500g") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp)
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = category,
                        onValueChange = { category = it },
                        label = { Text("Category") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp)
                    )
                    OutlinedTextField(
                        value = unit,
                        onValueChange = { unit = it },
                        label = { Text("Unit") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp)
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = priceText,
                        onValueChange = { priceText = it },
                        label = { Text("Price (₹)") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        shape = RoundedCornerShape(10.dp)
                    )
                    OutlinedTextField(
                        value = stockText,
                        onValueChange = { stockText = it },
                        label = { Text("Initial Stock") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        shape = RoundedCornerShape(10.dp)
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val price = priceText.toDoubleOrNull() ?: 100.0
                    val stock = stockText.toIntOrNull() ?: 50
                    onConfirm(name, category, unit, price, stock)
                },
                enabled = name.isNotBlank(),
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB))
            ) {
                Text("Save Item Option", fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = Color(0xFF64748B))
            }
        }
    )
}

@Composable
private fun CartSummary(
    totalPaise: Long,
    totalItemsCount: Int,
    hasItems: Boolean,
    isSubmitting: Boolean,
    onSubmit: () -> Unit
) {
    Surface(
        shadowElevation = 12.dp,
        tonalElevation = 4.dp,
        color = Color.White,
        border = BorderStroke(1.dp, Color(0xFFE2E8F0))
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = if (hasItems) "$totalItemsCount Items in Cart" else "Cart Empty",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF64748B),
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = CurrencyFormatter.formatPaise(totalPaise),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Black,
                        color = if (hasItems) Color(0xFF2563EB) else Color(0xFF94A3B8)
                    )
                }

                Button(
                    onClick = onSubmit,
                    enabled = hasItems && !isSubmitting,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .height(50.dp)
                        .defaultMinSize(minWidth = 150.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2563EB),
                        contentColor = Color.White
                    ),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                        Spacer(Modifier.width(8.dp))
                        Text("Submitting…", color = Color.White, fontWeight = FontWeight.Bold)
                    } else {
                        Icon(Icons.Default.ShoppingCart, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                        Spacer(Modifier.width(8.dp))
                        Text("Submit Order", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
            }

            if (!hasItems) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "Add at least 1 item to submit order",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF94A3B8)
                )
            }
        }
    }
}
