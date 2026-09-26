package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.*
import com.routeflow.app.core.network.dto.*
import com.routeflow.app.core.security.TokenStorage
import com.routeflow.app.data.sync.SyncManager
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DurableFieldRepository @Inject constructor(private val db: RouteFlowDatabase, private val tokens: TokenStorage,
    private val sync: SyncManager, private val json: Json) {
    suspend fun queue(type: String, payload: String, key: String, localChange: suspend () -> Unit = {}) {
        val user = requireNotNull(tokens.getUserId()); val company = requireNotNull(tokens.getCompanyId())
        db.withTransaction {
            check(user == tokens.getUserId() && company == tokens.getCompanyId())
            localChange()
            db.syncOutboxDao().insertSyncItem(SyncOutboxEntity(type = type, payload = payload, idempotencyKey = key, userId = user, companyId = company))
        }
        sync.scheduleSync(user, company)
    }
    suspend fun checkIn(retailerId: String, latitude: Double? = null, longitude: Double? = null, accuracy: Float? = null): VisitEntity {
        val user = requireNotNull(tokens.getUserId()); val company = requireNotNull(tokens.getCompanyId()); val id = UUID.randomUUID().toString()
        val visit = VisitEntity(id = id, retailerId = retailerId, employeeId = user, companyId = company, checkInTime = System.currentTimeMillis(), latitude = latitude, longitude = longitude, accuracy = accuracy, status = "ACTIVE")
        val event = VisitDto(id = id, retailerId = retailerId, checkInTime = visit.checkInTime, latitude = latitude, longitude = longitude, accuracy = accuracy, status = "ACTIVE", idempotencyKey = "visit_$id")
        queue("VISIT_START", json.encodeToString(event), "visit_$id") {
            check(db.visitDao().activeForAccount(user, company) == null) { "ACTIVE_VISIT" }
            db.visitDao().insertVisit(visit)
        }
        return visit
    }
    suspend fun checkout(id: String, notes: String?, outcome: String?) {
        val user = requireNotNull(tokens.getUserId()); val company = requireNotNull(tokens.getCompanyId())
        val request = CheckoutVisitRequest(noOrderReason = outcome, notes = notes)
        queue("VISIT_END", json.encodeToString(VisitCheckoutEvent(id, request)), "checkout_$id") {
            val visit = requireNotNull(db.visitDao().getVisit(id))
            check(visit.employeeId == user && visit.companyId == company && visit.status == "ACTIVE")
            db.visitDao().insertVisit(visit.copy(status = "COMPLETED", checkOutTime = request.checkOutTime, notes = notes, noOrderReason = outcome))
        }
    }
    suspend fun stockCheck(request: StockCheckDto) {
        val payload = json.encodeToString(request)
        queue("STOCK_CHECK", payload, request.idempotencyKey) {
            db.fieldRecordDao().saveRecord(FieldRecordEntity(request.idempotencyKey, requireNotNull(tokens.getUserId()), requireNotNull(tokens.getCompanyId()), "STOCK_CHECK", payload, System.currentTimeMillis()))
        }
    }
}
