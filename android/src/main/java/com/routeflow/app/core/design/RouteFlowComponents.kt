package com.routeflow.app.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * RouteFlow design system tokens and reusable UI components.
 * Characterized by:
 * - 12-14dp soft rounded card geometry with subtle diffuse elevation
 * - Pill status badges with pastel tints and vibrant dot indicators
 * - Tactile 48dp primary and outline action buttons
 * - High-speed wholesale quantity stepper (ADD / [-] qty [+])
 * - Floating docked summary/action bottom bar
 */
object RFDesignTokens {
    val Background = RFColors.Background
    val Surface = RFColors.Surface
    val BorderSubtle = Color(0xFFF1F5F9)
    val BorderCard = RFColors.Border

    val BrandBlue = RFColors.Primary
    val BrandBlueLight = RFColors.InfoSurface
    val BrandBlueDark = RFColors.PrimaryPressed

    val TextHeading = RFColors.TextPrimary
    val TextBody = RFColors.TextPrimary
    val TextMuted = RFColors.TextSecondary

    // Status tints
    val GreenBg = RFColors.SuccessSurface
    val GreenBorder = Color(0xFFA7F3D0)
    val GreenText = RFColors.Success

    val AmberBg = RFColors.WarningSurface
    val AmberBorder = Color(0xFFFDE68A)
    val AmberText = RFColors.Warning

    val RedBg = RFColors.DangerSurface
    val RedBorder = Color(0xFFFECACA)
    val RedText = RFColors.Danger

    val BlueBg = RFColors.InfoSurface
    val BlueBorder = Color(0xFFBFDBFE)
    val BlueText = RFColors.Primary

    val PurpleBg = Color(0xFFFAF5FF)
    val PurpleBorder = Color(0xFFE9D5FF)
    val PurpleText = Color(0xFF7C3AED)
}

/**
 * RouteFlow elevated white card with 16dp corners, subtle border and zero heavy drop shadow.
 */
@Composable
fun RFCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 16.dp,
    elevation: Dp = 0.dp,
    borderColor: Color = RFColors.Border,
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
 * Account/Profile Bottom Sheet triggered by the top bar avatar.
 * Displays employee details, role, language switcher, sync status, and logout.
 */
@Composable
fun RFAccountBottomSheet(
    employeeName: String,
    roleTitle: String,
    currentLanguage: String,
    onLanguageChange: (String) -> Unit,
    onLogout: () -> Unit,
    onDismiss: () -> Unit,
    syncStatusText: String = "Online • Synced"
) {
    Surface(
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        color = Color.White,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Drag handle
            Box(
                modifier = Modifier
                    .width(36.dp)
                    .height(4.dp)
                    .background(Color(0xFFCBD5E1), CircleShape)
                    .align(Alignment.CenterHorizontally)
            )

            // User Info Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    shape = CircleShape,
                    color = RFColors.InfoSurface,
                    border = BorderStroke(1.dp, Color(0xFFBFDBFE)),
                    modifier = Modifier.size(52.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            text = employeeName.take(1).uppercase(),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = RFColors.Primary
                        )
                    }
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = employeeName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = RFColors.TextPrimary
                    )
                    Text(
                        text = roleTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = RFColors.TextSecondary
                    )
                }
            }

            androidx.compose.material3.HorizontalDivider(color = RFColors.Border)

            // Language Switch Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = "App Language",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = RFColors.TextPrimary
                    )
                    Text(
                        text = if (currentLanguage == "hi") "हिन्दी सक्रिय है" else "English active",
                        style = MaterialTheme.typography.bodySmall,
                        color = RFColors.TextSecondary
                    )
                }

                Row(
                    modifier = Modifier
                        .background(Color(0xFFF1F5F9), RoundedCornerShape(10.dp))
                        .padding(3.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Surface(
                        onClick = { onLanguageChange("en") },
                        shape = RoundedCornerShape(8.dp),
                        color = if (currentLanguage == "en") Color.White else Color.Transparent,
                        border = if (currentLanguage == "en") BorderStroke(1.dp, RFColors.Border) else null
                    ) {
                        Text(
                            "English",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = if (currentLanguage == "en") FontWeight.Bold else FontWeight.Medium,
                            color = if (currentLanguage == "en") RFColors.TextPrimary else RFColors.TextSecondary
                        )
                    }
                    Surface(
                        onClick = { onLanguageChange("hi") },
                        shape = RoundedCornerShape(8.dp),
                        color = if (currentLanguage == "hi") Color.White else Color.Transparent,
                        border = if (currentLanguage == "hi") BorderStroke(1.dp, RFColors.Border) else null
                    ) {
                        Text(
                            "हिन्दी",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = if (currentLanguage == "hi") FontWeight.Bold else FontWeight.Medium,
                            color = if (currentLanguage == "hi") RFColors.TextPrimary else RFColors.TextSecondary
                        )
                    }
                }
            }

            androidx.compose.material3.HorizontalDivider(color = RFColors.Border)

            // Sync Status Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(RFColors.Success, CircleShape)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = syncStatusText,
                    style = MaterialTheme.typography.bodySmall,
                    color = RFColors.TextSecondary
                )
            }

            // Logout Button
            Button(
                onClick = {
                    onDismiss()
                    onLogout()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFColors.DangerSurface,
                    contentColor = RFColors.Danger
                ),
                elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp)
            ) {
                Text(
                    text = "Sign Out",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = RFColors.Danger
                )
            }
        }
    }
}

/**
 * Capsule status badge with optional live dot indicator.
 */
@Composable
fun RFPillBadge(
    text: String,
    modifier: Modifier = Modifier,
    bgColor: Color = RFDesignTokens.BlueBg,
    textColor: Color = RFDesignTokens.BlueText,
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
fun RFButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    containerColor: Color = RFDesignTokens.BrandBlue,
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
fun RFOutlinedButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    textColor: Color = RFDesignTokens.BrandBlue,
    borderColor: Color = RFDesignTokens.BorderCard
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
 * RouteFlow wholesale quantity stepper:
 * When qty == 0: Displays an "ADD" button with + icon.
 * When qty > 0: Expands into [-] qty [+] with 48dp touch height.
 */
@Composable
fun RFQuantityStepper(
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
            border = BorderStroke(1.5.dp, RFDesignTokens.BrandBlue),
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
                    color = RFDesignTokens.BrandBlue,
                    fontSize = 13.sp
                )
                Spacer(Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Add item",
                    tint = RFDesignTokens.BrandBlue,
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
            color = RFDesignTokens.BrandBlueLight,
            border = BorderStroke(1.5.dp, RFDesignTokens.BrandBlue),
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
                        tint = RFDesignTokens.BrandBlueDark,
                        modifier = Modifier.size(18.dp)
                    )
                }

                Text(
                    text = "$quantity",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    color = RFDesignTokens.BrandBlueDark,
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
                        tint = if (quantity < maxQuantity) RFDesignTokens.BrandBlueDark else Color(0xFFCBD5E1),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

/**
 * RouteFlow rounded search bar with clear button.
 */
@Composable
fun RFSearchBar(
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
                color = RFDesignTokens.TextMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        },
        leadingIcon = {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = RFDesignTokens.TextMuted,
                modifier = Modifier.size(20.dp)
            )
        },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Clear",
                        tint = RFDesignTokens.TextMuted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        },
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = RFDesignTokens.BrandBlue,
            unfocusedBorderColor = RFDesignTokens.BorderCard,
            focusedContainerColor = Color.White,
            unfocusedContainerColor = Color.White
        )
    )
}

/**
 * Floating docked action bar with items/price summary on left and primary CTA on right.
 */
@Composable
fun RFFloatingBottomBar(
    leftTitle: String,
    leftSubtitle: String,
    ctaText: String,
    onCtaClick: () -> Unit,
    modifier: Modifier = Modifier,
    ctaEnabled: Boolean = true,
    containerColor: Color = Color.White,
    borderColor: Color = RFDesignTokens.BorderCard
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
                    color = RFDesignTokens.TextHeading
                )
                Text(
                    text = leftSubtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = RFDesignTokens.TextMuted
                )
            }

            Spacer(Modifier.width(12.dp))

            Button(
                onClick = onCtaClick,
                enabled = ctaEnabled,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = RFDesignTokens.BrandBlue,
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
fun RFMetricTile(
    title: String,
    value: String,
    icon: ImageVector,
    accentColor: Color,
    modifier: Modifier = Modifier,
    subtitle: String? = null
) {
    RFCard(
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
                    color = RFDesignTokens.TextHeading
                )
            }

            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = RFDesignTokens.TextBody,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = RFDesignTokens.TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
