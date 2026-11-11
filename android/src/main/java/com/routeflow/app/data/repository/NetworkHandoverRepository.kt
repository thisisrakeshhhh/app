package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.PaymentDao
import com.routeflow.app.core.network.api.RouteFlowApi
import com.routeflow.app.core.network.dto.AcknowledgeHandoverRequest
import com.routeflow.app.core.network.dto.AcknowledgeHandoverResponse
import com.routeflow.app.core.network.dto.CashHandoverDto
import com.routeflow.app.core.network.dto.CashHandoverSummaryResponse
import com.routeflow.app.core.network.dto.SubmitHandoverRequest
import com.routeflow.app.core.network.dto.SubmitHandoverResponse
import com.routeflow.app.domain.repository.HandoverRepository
import kotlinx.coroutines.flow.firstOrNull
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NetworkHandoverRepository @Inject constructor(
    private val api: RouteFlowApi,
    private val paymentDao: PaymentDao
) : HandoverRepository {

    override suspend fun getSummary(): Result<CashHandoverSummaryResponse> {
        return try {
            val response = api.getHandoverSummary()
            Result.success(response)
        } catch (_: Exception) {
            // Fallback to local paymentDao calculation if offline
            val localCash = paymentDao.getTotalCollectedPaise().firstOrNull() ?: 0L
            Result.success(
                CashHandoverSummaryResponse(
                    cashHeldPaise = localCash,
                    totalCollectedPaise = localCash,
                    totalSettledPaise = 0L,
                    pendingHandover = null,
                    recentHandovers = emptyList()
                )
            )
        }
    }

    override suspend fun submitHandover(amountPaise: Long, notes: String?): Result<SubmitHandoverResponse> {
        return try {
            val response = api.submitHandoverRequest(
                SubmitHandoverRequest(amountPaise = amountPaise, notes = notes)
            )
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun getOwnerHandovers(): Result<List<CashHandoverDto>> {
        return try {
            val response = api.getOwnerHandovers()
            Result.success(response.handovers)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun acknowledgeHandover(
        id: String,
        action: String,
        receivedPaise: Long?,
        notes: String?
    ): Result<AcknowledgeHandoverResponse> {
        return try {
            val response = api.acknowledgeHandover(
                id = id,
                request = AcknowledgeHandoverRequest(
                    action = action,
                    receivedAmountPaise = receivedPaise,
                    notes = notes
                )
            )
            Result.success(response)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
