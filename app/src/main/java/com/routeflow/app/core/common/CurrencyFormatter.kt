package com.routeflow.app.core.common

import java.text.NumberFormat
import java.util.Locale

object CurrencyFormatter {
    private val locale = Locale("en", "IN")
    private val formatter = NumberFormat.getCurrencyInstance(locale)

    fun formatPaise(paise: Long): String {
        return formatter.format(paise / 100.0)
    }
}
