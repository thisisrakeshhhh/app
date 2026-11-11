package com.routeflow.app.domain.repository

import com.routeflow.app.core.network.dto.AcknowledgeHandoverResponse
import com.routeflow.app.core.network.dto.CashHandoverDto
import com.routeflow.app.core.network.dto.CashHandoverSummaryResponse
import com.routeflow.app.core.network.dto.SubmitHandoverResponse

interface HandoverRepository {
    suspend fun getSummary(): Result<CashHandoverSummaryResponse>
    suspend fun submitHandover(amountPaise: Long, notes: String? = null): Result<SubmitHandoverResponse>
    suspend fun getOwnerHandovers(): Result<List<CashHandoverDto>>
    suspend fun acknowledgeHandover(id: String, action: String, receivedPaise: Long?, notes: String?): Result<AcknowledgeHandoverResponse>
}
