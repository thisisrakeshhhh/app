package com.routeflow.app.core.design

import androidx.compose.ui.graphics.Color

object RFColors {
    // Primary Brand Colors
    val Primary = Color(0xFF2563EB) // Primary RouteFlow blue
    val PrimaryPressed = Color(0xFF1D4ED8) // Primary pressed
    val Secondary = Color(0xFF667085) // Secondary text/slate
    val Accent = Color(0xFF2563EB)
    val Dark = Color(0xFF172033) // Primary text dark
    
    // Backgrounds & Surfaces
    val Background = Color(0xFFF7F8FA) // Light background
    val Surface = Color(0xFFFFFFFF) // Card/surface
    
    // Status Tints & Surfaces
    val Success = Color(0xFF15803D)
    val SuccessSurface = Color(0xFFECFDF3)
    val SuccessLight = Color(0xFFECFDF3)

    val Warning = Color(0xFFB54708)
    val WarningSurface = Color(0xFFFFFAEB)
    val WarningLight = Color(0xFFFFFAEB)

    val Danger = Color(0xFFB42318)
    val DangerSurface = Color(0xFFFEF3F2)
    val DangerLight = Color(0xFFFEF3F2)

    val InfoSurface = Color(0xFFEFF6FF)
    val InfoLight = Color(0xFFEFF6FF)

    val NeutralLight = Color(0xFFF8FAFC)
    
    // Legacy / Convenience aliases
    val Error = Danger
    val ErrorSurface = DangerSurface

    // Neutral
    val TextPrimary = Color(0xFF172033)
    val TextSecondary = Color(0xFF667085)
    val Outline = Color(0xFFE4E7EC) // Border
    val Border = Color(0xFFE4E7EC)
}

object RouteFlowStatus {
    val Completed = RFColors.Success
    val Pending = RFColors.Warning
    val Rejected = RFColors.Danger
}
