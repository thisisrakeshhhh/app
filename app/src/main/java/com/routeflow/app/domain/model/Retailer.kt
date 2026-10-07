package com.routeflow.app.domain.model

data class Retailer(
    val id: String,
    val name: String,
    val beatId: String,
    val address: String,
    val contactNumber: String,
    val latitude: Double,
    val longitude: Double,
    val creditLimitPaise: Long,
    val outstandingAmountPaise: Long,
    val companyId: String = "",
    val lastSyncedAt: Long = 0L,
    val source: String = "SERVER"
)
