package com.routeflow.app.core.design

import androidx.compose.ui.graphics.Color

object RFColors {
    // Primary Brand Colors
    val Primary = Color(0xFF0F172A) // Slate 900 (Premium Navy)
    val Secondary = Color(0xFF334155) // Slate 700
    val Accent = Color(0xFF3B82F6) // Blue 500
    
    // Backgrounds
    val Background = Color(0xFFF8FAFC) // Slate 50
    val Surface = Color.White
    
    // Status
    val Success = Color(0xFF10B981) // Emerald 500
    val Warning = Color(0xFFF59E0B) // Amber 500
    val Error = Color(0xFFEF4444) // Red 500
    
    // Neutral
    val TextPrimary = Color(0xFF0F172A)
    val TextSecondary = Color(0xFF64748B) // Slate 500
    val Outline = Color(0xFFE2E8F0) // Slate 200
}

object RouteFlowStatus {
    val Completed = RFColors.Success
    val Pending = RFColors.Warning
    val Rejected = RFColors.Error
}
