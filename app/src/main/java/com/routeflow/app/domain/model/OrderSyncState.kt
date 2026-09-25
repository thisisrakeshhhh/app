package com.routeflow.app.domain.model

enum class OrderSyncState {
    SAVED_OFFLINE,
    SYNCING,
    SYNCED,
    NEEDS_ATTENTION
}
