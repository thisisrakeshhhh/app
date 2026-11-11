package com.routeflow.app.core.util

/**
 * Universal human-readable status formatter for RouteFlow production UI.
 * Prevents raw database / backend enums (e.g. ACCEPTED, PENDING_INSPECTION)
 * from appearing directly to business users, store managers, and field staff.
 */
object StatusMapper {

    /**
     * Returns a clean, professional English label for any backend status or enum.
     */
    fun statusLabel(status: String?): String {
        if (status.isNullOrBlank()) return "Unknown"
        val normalized = status.trim().uppercase()
        return when (normalized) {
            // Handovers & Settlements
            "ACCEPTED" -> "Accepted / Settled"
            "SETTLED" -> "Settled"
            "PENDING" -> "Pending Verification"
            "SUBMITTED" -> "Submitted"
            "VERIFIED" -> "Verified"
            "REJECTED" -> "Rejected"
            "REVERSED" -> "Reversed"

            // Orders & Fulfillment
            "APPROVED" -> "Approved"
            "PENDING_APPROVAL" -> "Approval Pending"
            "NEEDS_ATTENTION" -> "Needs Attention"
            "PICKING" -> "Picking in Progress"
            "PACKED" -> "Packed"
            "ASSIGNED" -> "Trip Assigned"
            "ASSIGNED_TO_TRIP" -> "Assigned to Trip"
            "READY_FOR_DISPATCH" -> "Ready for Dispatch"
            "DISPATCHED" -> "Dispatched"
            "OUT_FOR_DELIVERY" -> "Out for Delivery"
            "DELIVERED" -> "Delivered"
            "PARTIALLY_DELIVERED" -> "Partially Delivered"
            "DELIVERY_FAILED" -> "Delivery Failed"
            "CANCELLED" -> "Cancelled"

            // Stock & Inventory
            "LOW_STOCK" -> "Low Stock"
            "OUT_OF_STOCK" -> "Out of Stock"
            "IN_STOCK" -> "In Stock"
            "NEAR_EXPIRY" -> "Near Expiry"
            "DAMAGED" -> "Damaged"
            "STOCK_READY" -> "Stock Ready"

            // Warehouse Inspection & Returns
            "PENDING_INSPECTION" -> "Inspection Pending"
            "INSPECTED" -> "Inspected"
            "REQUESTED" -> "Return Requested"
            "AUTHORIZED" -> "Authorized"
            "RECEIVED" -> "Received at Godown"
            "CREDITED" -> "Credit Settled"
            "RETURNED_TO_WAREHOUSE" -> "Returned to Godown"
            "CUSTOMER_RETURN", "RMA" -> "Customer Return"

            // Delivery Failure / Visit Reasons
            "SHOP_CLOSED" -> "Shop Closed"
            "SHORTAGE" -> "Shortage"
            "REFUSED" -> "Customer Refused"
            "OTHER" -> "Other Reason"

            // Shifts & Visits
            "ON_SHIFT" -> "On Duty"
            "OFF_SHIFT" -> "Off Duty"
            "COMPLETED" -> "Completed"
            "ACTIVE" -> "Active"
            "INACTIVE" -> "Inactive"

            // Sync States
            "SYNCED" -> "Synced"
            "PENDING_SYNC" -> "Pending Sync"
            "FAILED" -> "Sync Failed"

            else -> {
                // Graceful fallback for any unspecified underscore-separated enum
                normalized
                    .split("_")
                    .joinToString(" ") { word ->
                        word.lowercase().replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
                    }
            }
        }
    }

    /**
     * Returns supportive Hindi helper label for bilingual UI displays.
     */
    fun statusLabelHi(status: String?): String {
        if (status.isNullOrBlank()) return "अज्ञात"
        val normalized = status.trim().uppercase()
        return when (normalized) {
            "ACCEPTED" -> "स्वीकृत / चुकता"
            "SETTLED" -> "चुकता"
            "PENDING" -> "सत्यापन बाकी"
            "SUBMITTED" -> "प्रस्तुत"
            "VERIFIED" -> "सत्यापित"
            "REJECTED" -> "अस्वीकृत"
            "REVERSED" -> "रद्द किया गया"

            "APPROVED" -> "स्वीकृत"
            "PENDING_APPROVAL" -> "अनुमोदन बाकी"
            "NEEDS_ATTENTION" -> "ध्यान दें"
            "PICKING" -> "पिकिंग जारी"
            "PACKED" -> "पैक हो चुका"
            "READY_FOR_DISPATCH" -> "डिस्पैच के लिए तैयार"
            "DISPATCHED" -> "डिस्पैच किया गया"
            "OUT_FOR_DELIVERY" -> "डिलीवरी पर रवाना"
            "DELIVERED" -> "वितरित"
            "PARTIALLY_DELIVERED" -> "आंशिक रूप से दिया"
            "DELIVERY_FAILED" -> "डिलीवरी असफल"
            "CANCELLED" -> "रद्द"

            "LOW_STOCK" -> "कम स्टॉक"
            "OUT_OF_STOCK" -> "स्टॉक खत्म"
            "IN_STOCK" -> "उपलब्ध स्टॉक"

            "PENDING_INSPECTION" -> "जांच बाकी"
            "INSPECTED" -> "जांचा गया"
            "SHOP_CLOSED" -> "दुकान बंद"

            "ON_SHIFT" -> "ड्यूटी पर"
            "OFF_SHIFT" -> "ड्यूटी समाप्त"
            "COMPLETED" -> "पूर्ण"

            else -> statusLabel(status)
        }
    }
}
