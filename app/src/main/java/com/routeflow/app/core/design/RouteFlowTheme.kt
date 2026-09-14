package com.routeflow.app.core.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val LightColors = lightColorScheme(
    primary = Color(0xFF17634D),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD9EDE2),
    onPrimaryContainer = Color(0xFF103D30),
    secondary = Color(0xFF596845),
    secondaryContainer = Color(0xFFE7EDDA),
    onSecondaryContainer = Color(0xFF303C22),
    background = Color(0xFFF7F8F2),
    onBackground = Color(0xFF202B25),
    surface = Color(0xFFFCFDF8),
    onSurface = Color(0xFF202B25),
    surfaceVariant = Color(0xFFE8ECE4),
    onSurfaceVariant = Color(0xFF4E5C52),
    outlineVariant = Color(0xFFD4DCD1),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFA0D7BA),
    onPrimary = Color(0xFF003827),
    primaryContainer = Color(0xFF23523F),
    onPrimaryContainer = Color(0xFFD9EDE2),
    secondaryContainer = Color(0xFF3D4932),
    onSecondaryContainer = Color(0xFFE7EDDA),
    background = Color(0xFF111914),
    surface = Color(0xFF18211B),
    onSurface = Color(0xFFE1E9DF),
    onBackground = Color(0xFFE1E9DF),
    surfaceVariant = Color(0xFF344138),
    onSurfaceVariant = Color(0xFFBFCBBE),
)

private val RouteFlowTypography = Typography(
    headlineLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold,
        fontSize = 30.sp, lineHeight = 36.sp),
    headlineSmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold,
        fontSize = 24.sp, lineHeight = 30.sp),
    titleMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold,
        fontSize = 18.sp, lineHeight = 24.sp),
    bodyLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 16.sp, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 14.sp, lineHeight = 21.sp),
    labelLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp, lineHeight = 22.sp),
)

@Composable
fun RouteFlowTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = RouteFlowTypography,
        content = content,
    )
}
