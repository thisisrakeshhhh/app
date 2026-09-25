package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.CreateReturnResponse
import com.routeflow.app.core.network.dto.InspectItemRequest
import com.routeflow.app.core.network.dto.InspectReturnResponse
import com.routeflow.app.core.network.dto.ReturnItemRequest
import com.routeflow.app.core.network.dto.ReturnRequestDto

interface ReturnRepository {
    suspend fun getPendingReturns(): Result<List<ReturnRequestDto>>
    suspend fun createReturn(orderId: String, items: List<ReturnItemRequest>, notes: String? = null): Result<CreateReturnResponse>
    suspend fun inspectReturn(id: String, action: String, items: List<InspectItemRequest>?, notes: String? = null): Result<InspectReturnResponse>
}
