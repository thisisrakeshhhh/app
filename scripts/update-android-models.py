from pathlib import Path
root=Path('app/src/main/java/com/routeflow/app')
def edit(f,fn):
 p=root/f;s=p.read_text(encoding='utf-8');p.write_text(fn(s),encoding='utf-8')
edit(Path('core/database/RouteFlowDatabase.kt'),lambda s:s.replace('        CollectionRecordEntity::class','        com.routeflow.app.core.database.entity.LocalShiftEntity::class,\n        com.routeflow.app.core.database.entity.FieldRecordEntity::class,\n        CollectionRecordEntity::class').replace('version = 7','version = 8').replace('    companion object {','    abstract fun fieldRecordDao(): com.routeflow.app.core.database.dao.FieldRecordDao\n\n    companion object {').replace('        val MIGRATION_4_5', '''        val MIGRATION_7_8 = object : Migration(7, 8) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE visits ADD COLUMN companyId TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE visits ADD COLUMN notes TEXT")
                db.execSQL("ALTER TABLE visits ADD COLUMN noOrderReason TEXT")
                db.execSQL("ALTER TABLE sync_outbox ADD COLUMN syncState TEXT NOT NULL DEFAULT 'SAVED_OFFLINE'")
                db.execSQL("ALTER TABLE collection_records ADD COLUMN paymentState TEXT NOT NULL DEFAULT 'ENTERED'")
                db.execSQL("ALTER TABLE collection_records ADD COLUMN serverId TEXT")
                db.execSQL("CREATE TABLE IF NOT EXISTS local_shifts (id TEXT NOT NULL PRIMARY KEY, userId TEXT NOT NULL, companyId TEXT NOT NULL, status TEXT NOT NULL, startTime INTEGER NOT NULL, endTime INTEGER)")
                db.execSQL("CREATE TABLE IF NOT EXISTS field_records (id TEXT NOT NULL PRIMARY KEY, userId TEXT NOT NULL, companyId TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, createdAt INTEGER NOT NULL)")
            }
        }

        val MIGRATION_4_5'''))
edit(Path('app/DatabaseModule.kt'),lambda s:s.replace('RouteFlowDatabase.MIGRATION_6_7','RouteFlowDatabase.MIGRATION_6_7,\n            RouteFlowDatabase.MIGRATION_7_8').replace('        .fallbackToDestructiveMigration()\n',''))
edit(Path('core/database/entity/VisitEntity.kt'),lambda s:s.replace('    val status: String','    @androidx.room.ColumnInfo(defaultValue = "\'\'") val companyId: String = "",\n    val notes: String? = null,\n    val noOrderReason: String? = null,\n    val status: String'))
edit(Path('core/database/entity/SyncOutboxEntity.kt'),lambda s:s.replace('    val lastError:', '    @androidx.room.ColumnInfo(defaultValue = "\'SAVED_OFFLINE\'") val syncState: String = "SAVED_OFFLINE",\n    val lastError:'))
edit(Path('core/database/entity/CollectionRecordEntity.kt'),lambda s:s.replace('    val isSynced:', '    @androidx.room.ColumnInfo(defaultValue = "\'ENTERED\'") val paymentState: String = "ENTERED",\n    val serverId: String? = null,\n    val isSynced:'))
edit(Path('core/database/dao/CollectionRecordDao.kt'),lambda s:s.replace('WHERE companyId = :companyId ORDER','WHERE companyId = :companyId AND collectedBy = :userId ORDER').replace('fun observeCollections(companyId: String)', 'fun observeCollections(companyId: String, userId: String)').replace('    @Query("UPDATE collection_records SET isSynced = 1', '''    @Query("UPDATE collection_records SET isSynced = 1, paymentState = :state, serverId = :serverId, receiptId = :receiptId WHERE id = :id")
    suspend fun confirm(id: String, state: String, serverId: String?, receiptId: String)

    @Query("UPDATE collection_records SET isSynced = 1'''))
edit(Path('core/database/dao/ShiftLocationDao.kt'),lambda s:s.replace('    @Query("UPDATE shift_locations_outbox SET', '''    @Query("SELECT * FROM shift_locations_outbox WHERE userId=:userId AND companyId=:companyId AND isSynced=0 ORDER BY timestamp,id LIMIT :limit")
    suspend fun getPendingForAccount(userId: String, companyId: String, limit: Int = 50): List<ShiftLocationEntity>

    @Query("UPDATE shift_locations_outbox SET'''))
edit(Path('core/database/dao/SyncOutboxDao.kt'),lambda s:s.replace('ORDER BY createdAt ASC','ORDER BY createdAt ASC, id ASC').replace('    @Insert\n', '''    @Query("SELECT * FROM sync_outbox WHERE userId=:userId AND companyId=:companyId AND type != 'QUARANTINED' ORDER BY createdAt,id")
    fun observeForAccount(userId: String, companyId: String): Flow<List<SyncOutboxEntity>>

    @Query("UPDATE sync_outbox SET syncState='SAVED_OFFLINE', lastError=NULL WHERE id=:id AND userId=:userId AND companyId=:companyId AND type NOT IN ('PERMANENT_FAILURE','QUARANTINED')")
    suspend fun retry(id: Long, userId: String, companyId: String)

    @Insert
'''))
edit(Path('core/database/dao/VisitDao.kt'),lambda s:s.replace('    @Insert', '''    @Query("SELECT * FROM visits WHERE employeeId=:userId AND companyId=:companyId AND status='ACTIVE' LIMIT 1")
    suspend fun activeForAccount(userId: String, companyId: String): VisitEntity?

    @Query("SELECT * FROM visits WHERE id=:id")
    suspend fun getVisit(id: String): VisitEntity?

    @Insert'''))

def dto(s):
 s=s.replace('data class StartShiftRequest(\n','data class StartShiftRequest(\n    val shiftId: String = java.util.UUID.randomUUID().toString(),\n    val startTime: Long = System.currentTimeMillis(),\n    val idempotencyKey: String = java.util.UUID.randomUUID().toString(),\n')
 s=s.replace('data class EndShiftRequest(\n','data class EndShiftRequest(\n    val shiftId: String = "",\n    val endTime: Long = System.currentTimeMillis(),\n    val idempotencyKey: String = java.util.UUID.randomUUID().toString(),\n')
 for name in ['SubmitHandoverRequest','AcknowledgeHandoverRequest','CreateReturnRequest','InspectReturnRequest','StockCheckDto']:
  s=s.replace(f'data class {name}(\n',f'data class {name}(\n    val idempotencyKey: String = java.util.UUID.randomUUID().toString(),\n')
 s=s.replace('data class RecordCollectionRequest(\n','data class RecordCollectionRequest(\n    val reference: String? = null,\n    val allocations: List<InvoiceAllocation>? = null,\n')
 s=s.replace('data class RecordCollectionResponse(\n','data class RecordCollectionResponse(\n    val status: String = "ENTERED",\n    val unappliedPaise: Long = 0,\n')
 s=s.replace('data class CollectionDto(\n','data class CollectionDto(\n    val status: String = "ENTERED",\n    val unapplied_paise: Long = 0,\n    val reference: String? = null,\n')
 s=s.replace('data class OtpResponse(\n','data class OtpResponse(\n    val deliveryStatus: String = "UNAVAILABLE",\n')
 s=s.replace('data class ReturnItemRequest(\n','data class ReturnItemRequest(\n    val freeQuantity: Int = 0,\n')
 s=s.replace('data class ReturnItemDto(\n','data class ReturnItemDto(\n    val free_quantity: Int = 0,\n')
 s=s.replace('data class InspectItemRequest(\n','data class InspectItemRequest(\n    val saleableFreeQuantity: Int = 0,\n    val damagedFreeQuantity: Int = 0,\n')
 s=s.replace('data class CashHandoverDto(\n','data class CashHandoverDto(\n    val expected_amount_paise: Long? = null,\n    val resolution_notes: String? = null,\n')
 return s+'''
@Serializable
data class InvoiceAllocation(val invoiceId: String, val amountPaise: Long)
@Serializable
data class CollectionReviewRequest(val action: String, val reason: String, val idempotencyKey: String = java.util.UUID.randomUUID().toString(), val allocations: List<InvoiceAllocation>? = null)
@Serializable
data class ReturnActionRequest(val notes: String, val action: String = "APPROVE", val idempotencyKey: String = java.util.UUID.randomUUID().toString())
@Serializable
data class ClosingRequest(val businessDate: String, val notes: String, val idempotencyKey: String = java.util.UUID.randomUUID().toString())
@Serializable
data class EmployeeCashDto(val id: String, val full_name: String, val cashHeldPaise: Long, val totalCollectedPaise: Long, val totalSettledPaise: Long)
@Serializable
data class ClosingDto(val id: String, val business_date: String, val closed_at: Long, val snapshot: String, val notes: String)
@Serializable
data class ClosingResponse(val balances: List<EmployeeCashDto> = emptyList(), val closings: List<ClosingDto> = emptyList())
@Serializable
data class ShiftPauseRequest(val shiftId: String, val timestamp: Long = System.currentTimeMillis(), val idempotencyKey: String = java.util.UUID.randomUUID().toString())
@Serializable
data class VisitCheckoutEvent(val visitId: String, val request: CheckoutVisitRequest)
'''
edit(Path('core/network/dto/RouteFlowDtos.kt'),dto)

api=root/'core/network/api/RouteFlowApi.kt';s=api.read_text();s=s.rsplit('}',1)[0]+'''
    @GET("owner/closing")
    suspend fun getClosing(): com.routeflow.app.core.network.dto.ClosingResponse = error("Not implemented")
    @POST("owner/closing")
    suspend fun closeDay(@Body request: com.routeflow.app.core.network.dto.ClosingRequest): StatusResponse = error("Not implemented")
    @POST("collections/{id}/review")
    suspend fun reviewCollection(@Path("id") id: String, @Body request: com.routeflow.app.core.network.dto.CollectionReviewRequest): StatusResponse = error("Not implemented")
    @POST("returns/{id}/{step}")
    suspend fun returnAction(@Path("id") id: String, @Path("step") step: String, @Body request: com.routeflow.app.core.network.dto.ReturnActionRequest): StatusResponse = error("Not implemented")
    @POST("shifts/{action}")
    suspend fun pauseShift(@Path("action") action: String, @Body request: com.routeflow.app.core.network.dto.ShiftPauseRequest, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null): com.routeflow.app.core.network.dto.ShiftResponse = error("Not implemented")
    @GET("shifts/current")
    suspend fun currentShift(): com.routeflow.app.core.network.dto.ShiftResponse = error("Not implemented")
}
'''
methods=['submitOrder','submitVisit','checkoutVisit','submitStockCheck','startShift','endShift','uploadShiftLocations','recordCollection','submitHandoverRequest']
import re
for method in methods:
 s=re.sub(r'(suspend fun '+method+r'\([^\n]*)(\):)',r'\1, @retrofit2.http.Header("X-RouteFlow-Account") account: String? = null\2',s)
api.write_text(s)
for p in Path('app/src/test').rglob('*.kt'):
 s=p.read_text()
 for method in methods:
  # Existing fake method signatures contain no annotations/nested parentheses.
  s=re.sub(r'(override suspend fun '+method+r'\([^)]*)(\))',r'\1, account: String?\2',s)
 p.write_text(s)
