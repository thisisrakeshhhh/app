package com.routeflow.app.core.common

import java.text.NumberFormat
import java.util.Locale

object CurrencyFormatter {
    private val locale = Locale("en", "IN")

    fun formatPaise(paise: Long): String {
        val absPaise = kotlin.math.abs(paise)
        val isNegative = paise < 0
        val isWhole = (absPaise % 100L) == 0L
        val rupees = absPaise / 100.0

        val nf = NumberFormat.getCurrencyInstance(locale).apply {
            maximumFractionDigits = if (isWhole) 0 else 2
            minimumFractionDigits = if (isWhole) 0 else 2
        }
        var formatted = nf.format(rupees)
            .replace("\u00A0", "")
            .replace("INR", "₹")
            .replace("Rs.", "₹")
            .replace("₹ ", "₹")
            .trim()

        if (!formatted.startsWith("₹") && !formatted.startsWith("-₹")) {
            formatted = if (formatted.startsWith("-")) "-₹" + formatted.substring(1).trim() else "₹$formatted"
        }

        return if (isNegative && !formatted.startsWith("-")) "-$formatted" else formatted
    }
}

