package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CheckoutVisitRequest
import com.routeflow.app.core.network.dto.DailyVisitDto
import com.routeflow.app.core.network.dto.StockCheckDto
import com.routeflow.app.core.network.dto.VisitDto

interface FieldOperationsRepository {
    suspend fun submitVisit(visit: VisitDto): Result<Unit>
    suspend fun checkoutVisit(visitId: String, request: CheckoutVisitRequest): Result<Unit>
    suspend fun submitStockCheck(stockCheck: StockCheckDto): Result<Unit>
    suspend fun getDailyVisits(date: String? = null): Result<List<DailyVisitDto>>
}
