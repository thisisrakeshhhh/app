package com.routeflow.app.data.repository

import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CheckoutVisitRequest
import com.routeflow.app.core.network.dto.DailyVisitDto
import com.routeflow.app.core.network.dto.StockCheckDto
import com.routeflow.app.core.network.dto.VisitDto
import com.routeflow.app.domain.repository.FieldOperationsRepository
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkFieldOperationsRepository @Inject constructor(
    private val api: RouteFlowApi
) : FieldOperationsRepository {

    override suspend fun submitVisit(visit: VisitDto): Result<Unit> = try {
        val resp = api.submitVisit(visit)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to record visit"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun checkoutVisit(visitId: String, request: CheckoutVisitRequest): Result<Unit> = try {
        val resp = api.checkoutVisit(visitId, request)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to checkout visit"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun submitStockCheck(stockCheck: StockCheckDto): Result<Unit> = try {
        val resp = api.submitStockCheck(stockCheck)
        if (resp.success) Result.success(Unit) else Result.failure(Exception(resp.message ?: "Failed to record stock audit"))
    } catch (e: Exception) {
        Result.failure(e)
    }

    override suspend fun getDailyVisits(date: String?): Result<List<DailyVisitDto>> = try {
        Result.success(api.getDailyVisits(date))
    } catch (e: Exception) {
        Result.failure(e)
    }
}
