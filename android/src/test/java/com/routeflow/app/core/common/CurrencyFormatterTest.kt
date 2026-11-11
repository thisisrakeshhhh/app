package com.routeflow.app.core.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CurrencyFormatterTest {

    @Test
    fun testWholeRupeesFormatting() {
        val f58800 = CurrencyFormatter.formatPaise(5880000L)
        assertTrue("Expected ₹58,800 but was $f58800", f58800 == "₹58,800")

        val f288 = CurrencyFormatter.formatPaise(28800L)
        assertTrue("Expected ₹288 but was $f288", f288 == "₹288")

        val f12500 = CurrencyFormatter.formatPaise(1250000L)
        assertTrue("Expected ₹12,500 but was $f12500", f12500 == "₹12,500")

        val f0 = CurrencyFormatter.formatPaise(0L)
        assertTrue("Expected ₹0 but was $f0", f0 == "₹0")
    }

    @Test
    fun testFractionalRupeesFormatting() {
        val f288_50 = CurrencyFormatter.formatPaise(28850L)
        assertTrue("Expected ₹288.50 but was $f288_50", f288_50 == "₹288.50")
    }

    @Test
    fun testNegativeRupeesFormatting() {
        val neg = CurrencyFormatter.formatPaise(-1250000L)
        assertTrue("Expected -₹12,500 but was $neg", neg == "-₹12,500")
    }
}
