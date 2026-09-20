package com.routeflow.app.core.network.api

import kotlinx.serialization.Serializable

@Serializable
data class OrderResponse(val success: Boolean, val orderId: String)
