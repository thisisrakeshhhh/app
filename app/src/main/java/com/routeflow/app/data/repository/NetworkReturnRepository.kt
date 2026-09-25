package com.routeflow.app.data.repository

import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.CreateReturnRequest
import com.routeflow.app.core.network.dto.CreateReturnResponse
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.InspectReturnRequest
import com.routeflow.app.core.network.dto.InspectReturnResponse
import com.routeflow.app.core.network.dto.ReturnItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto
import com.routeflow.app.domain.repository.ReturnRepository
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkReturnRepository @Inject constructor(
    private val api: RouteFlowApi
) : ReturnRepository {

    override suspend fun getPendingReturns(): Result<List<ReturnRequestDto>> {
        return try {
            val response = api.getPendingReturns()
            Result.success(response.returns)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun createReturn(
        orderId: String,
        items: List<ReturnItemRequest>,
        notes: String?
    ): Result<CreateReturnResponse> {
        return try {
            val response = api.createReturn(
                CreateReturnRequest(orderId = orderId, items = items, notes = notes)
            )
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun inspectReturn(
        id: String,
        action: String,
        items: List<InspectItemRequest>?,
        notes: String?
    ): Result<InspectReturnResponse> {
        return try {
            val response = api.inspectReturn(
                id = id,
                request = InspectReturnRequest(action = action, items = items, notes = notes)
            )
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
