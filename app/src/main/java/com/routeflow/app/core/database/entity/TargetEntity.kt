package com.routeflow.app.core.database.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "targets")
data class TargetEntity(
    @PrimaryKey val employeeId: String,
    val monthlyTargetPaise: Long,
    val currentAchievedPaise: Long,
    val incentiveRule: String
)
