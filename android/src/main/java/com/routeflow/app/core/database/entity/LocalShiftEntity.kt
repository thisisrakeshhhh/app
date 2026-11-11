package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "local_shifts")
data class LocalShiftEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val companyId: String,
    val status: String,
    val startTime: Long,
    val endTime: Long? = null
)

@Entity(tableName = "field_records")
data class FieldRecordEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val companyId: String,
    val kind: String,
    val payload: String,
    val createdAt: Long
)
