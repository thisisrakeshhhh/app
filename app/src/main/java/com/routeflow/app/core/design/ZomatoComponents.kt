package com.routeflow.app.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Zomato-grade design system tokens and reusable UI components.
 * Characterized by:
 * - 14-16dp soft rounded card geometry with subtle diffuse elevation
 * - Pill status badges with pastel tints and vibrant dot indicators
 * - Tactile 48dp+ primary and outline action buttons
 * - Iconic Zomato/Blinkit ADD / [-] qty [+] stepper
 * - Floating docked summary/action bottom bar
 */
object ZomatoTheme {
    val Background = Color(0xFFF8FAFC)
    val Surface = Color.White
    val BorderSubtle = Color(0xFFF1F5F9)
    val BorderCard = Color(0xFFE2E8F0)

    val BrandBlue = Color(0xFF2563EB)
    val BrandBlueLight = Color(0xFFEFF6FF)
    val BrandBlueDark = Color(0xFF1D4ED8)

    val TextHeading = Color(0xFF0F172A)
    val TextBody = Color(0xFF334155)
    val TextMuted = Color(0xFF64748B)

    // Status tints
    val GreenBg = Color(0xFFECFDF5)
    val GreenBorder = Color(0xFFA7F3D0)
    val GreenText = Color(0xFF059669)

    val AmberBg = Color(0xFFFFFBEB)
    val AmberBorder = Color(0xFFFDE68A)
    val AmberText = Color(0xFFD97706)

    val RedBg = Color(0xFFFEF2F2)
    val RedBorder = Color(0xFFFECACA)
    val RedText = Color(0xFFDC2626)

    val BlueBg = Color(0xFFEFF6FF)
    val BlueBorder = Color(0xFFBFDBFE)
    val BlueText = Color(0xFF2563EB)

    val PurpleBg = Color(0xFFFAF5FF)
    val PurpleBorder = Color(0xFFE9D5FF)
    val PurpleText = Color(0xFF9333EA)
}

/**
 * Zomato-style elevated white card with 14dp corners and hairline border.
 */
@Composable
fun ZCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 14.dp,
    elevation: Dp = 2.dp,
    borderColor: Color = ZomatoTheme.BorderCard,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    if (onClick != null) {
        Card(
            onClick = onClick,
            modifier = modifier,
            shape = RoundedCornerShape(cornerRadius),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            border = BorderStroke(1.dp, borderColor),
            elevation = CardDefaults.cardElevation(defaultElevation = elevation)
        ) {
            content()
        }
    } else {
        Card(
            modifier = modifier,
            shape = RoundedCornerShape(cornerRadius),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            border = BorderStroke(1.dp, borderColor),
            elevation = CardDefaults.cardElevation(defaultElevation = elevation)
        ) {
            content()
        }
    }
}

/**
 * Capsule status badge with optional live dot indicator.
 */
@Composable
fun ZPillBadge(
    text: String,
    modifier: Modifier = Modifier,
    bgColor: Color = ZomatoTheme.BlueBg,
    textColor: Color = ZomatoTheme.BlueText,
    borderColor: Color = Color.Transparent,
    showDot: Boolean = false,
    dotColor: Color = textColor
) {
    Surface(
        modifier = modifier,
        color = bgColor,
        shape = CircleShape,
        border = if (borderColor != Color.Transparent) BorderStroke(1.dp, borderColor) else null
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            if (showDot) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .background(dotColor, CircleShape)
                )
            }
            Text(
                text = text,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = textColor,
                fontSize = 11.sp,
                maxLines = 1
            )
        }
    }
}

/**
 * Primary action button with 48dp touch height, 12dp radius, and bold typography.
 */
@Composable
fun ZButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    containerColor: Color = ZomatoTheme.BrandBlue,
    contentColor: Color = Color.White,
    elevation: Dp = 1.dp
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(48.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
            disabledContainerColor = Color(0xFFCBD5E1),
            disabledContentColor = Color.White
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = elevation)
    ) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/**
 * Secondary outlined button with 48dp touch height, white container, and hairline slate border.
 */
@Composable
fun ZOutlinedButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    textColor: Color = ZomatoTheme.BrandBlue,
    borderColor: Color = ZomatoTheme.BorderCard
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.height(48.dp),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, borderColor),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = Color.White,
            contentColor = textColor
        )
    ) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = textColor)
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            color = textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

/**
 * The iconic Zomato/Blinkit quantity stepper:
 * When qty == 0: Displays an "ADD" button with + icon.
 * When qty > 0: Expands into [-] qty [+] with 48dp touch height.
 */
@Composable
fun ZQuantityStepper(
    quantity: Int,
    onQuantityChange: (Int) -> Unit,
    maxQuantity: Int = 9999,
    modifier: Modifier = Modifier
) {
    if (quantity == 0) {
        Surface(
            onClick = { onQuantityChange(1) },
            modifier = modifier
                .width(84.dp)
                .height(42.dp),
            shape = RoundedCornerShape(10.dp),
            color = Color.White,
            border = BorderStroke(1.5.dp, ZomatoTheme.BrandBlue),
            shadowElevation = 1.dp
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "ADD",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Black,
                    color = ZomatoTheme.BrandBlue,
                    fontSize = 13.sp
                )
                Spacer(Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Add item",
                    tint = ZomatoTheme.BrandBlue,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    } else {
        Surface(
            modifier = modifier
                .width(104.dp)
                .height(42.dp),
            shape = RoundedCornerShape(10.dp),
            color = ZomatoTheme.BrandBlueLight,
            border = BorderStroke(1.5.dp, ZomatoTheme.BrandBlue),
            shadowElevation = 1.dp
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(
                    onClick = { onQuantityChange(quantity - 1) },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = "Decrease",
                        tint = ZomatoTheme.BrandBlueDark,
                        modifier = Modifier.size(18.dp)
                    )
                }

                Text(
                    text = "$quantity",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    color = ZomatoTheme.BrandBlueDark,
                    fontSize = 15.sp
                )

                IconButton(
                    onClick = { if (quantity < maxQuantity) onQuantityChange(quantity + 1) },
                    enabled = quantity < maxQuantity,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Increase",
                        tint = if (quantity < maxQuantity) ZomatoTheme.BrandBlueDark else Color(0xFFCBD5E1),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

/**
 * Zomato-style rounded search bar with clear button.
 */
@Composable
fun ZSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        placeholder = {
            Text(
                placeholder,
                style = MaterialTheme.typography.bodyMedium,
                color = ZomatoTheme.TextMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        },
        leadingIcon = {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = ZomatoTheme.TextMuted,
                modifier = Modifier.size(20.dp)
            )
        },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Clear",
                        tint = ZomatoTheme.TextMuted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        },
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = ZomatoTheme.BrandBlue,
            unfocusedBorderColor = ZomatoTheme.BorderCard,
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White
        )
    )
}

/**
 * Floating docked action bar with items/price summary on left and primary CTA on right.
 */
@Composable
fun ZFloatingBottomBar(
    leftTitle: String,
    leftSubtitle: String,
    ctaText: String,
    onCtaClick: () -> Unit,
    modifier: Modifier = Modifier,
    ctaEnabled: Boolean = true,
    containerColor: Color = Color.White,
    borderColor: Color = ZomatoTheme.BorderCard
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        shape = RoundedCornerShape(16.dp),
        color = containerColor,
        border = BorderStroke(1.dp, borderColor),
        shadowElevation = 6.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = leftTitle,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    color = ZomatoTheme.TextHeading
                )
                Text(
                    text = leftSubtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = ZomatoTheme.TextMuted
                )
            }

            Spacer(Modifier.width(12.dp))

            Button(
                onClick = onCtaClick,
                enabled = ctaEnabled,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = ZomatoTheme.BrandBlue,
                    contentColor = Color.White
                ),
                modifier = Modifier.height(44.dp)
            ) {
                Text(
                    text = ctaText,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.width(6.dp))
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

/**
 * Compact KPI metric tile.
 */
@Composable
fun ZMetricTile(
    title: String,
    value: String,
    icon: ImageVector,
    accentColor: Color,
    modifier: Modifier = Modifier,
    subtitle: String? = null
) {
    ZCard(
        modifier = modifier,
        cornerRadius = 12.dp,
        elevation = 1.dp
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = accentColor.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.size(32.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = accentColor,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Black,
                    color = ZomatoTheme.TextHeading
                )
            }

            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = ZomatoTheme.TextBody,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = ZomatoTheme.TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
