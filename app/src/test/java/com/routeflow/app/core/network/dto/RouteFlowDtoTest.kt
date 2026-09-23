package com.routeflow.app.core.network.dto

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteFlowDtoTest {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
    }

    @Test
    fun decodeRetailerDto_mapsCorrectly() {
        val payload = """
            {
                "id": "R1",
                "name": "Sharma General Store",
                "beatId": "BEAT-04",
                "address": "Main Market, Sector 1",
                "contactNumber": "9829012345",
                "latitude": 26.85,
                "longitude": 75.76,
                "creditLimitPaise": 5000000,
                "outstandingAmountPaise": 1250000
            }
        """.trimIndent()

        val dto = json.decodeFromString<RetailerDto>(payload)
        assertEquals("R1", dto.id)
        assertEquals("Sharma General Store", dto.name)
        assertEquals("BEAT-04", dto.beatId)
        assertEquals(5000000L, dto.creditLimitPaise)

        val entity = dto.toEntity()
        assertEquals(dto.id, entity.id)
        assertEquals(dto.name, entity.name)
        assertEquals(dto.beatId, entity.beatId)
        assertEquals(dto.outstandingAmountPaise, entity.outstandingAmountPaise)

        val backToDto = entity.toDto()
        assertEquals(dto, backToDto)
    }

    @Test
    fun decodeProductDto_mapsCorrectly() {
        val payload = """
            {
                "id": "P1",
                "name": "Premium Tea",
                "category": "Beverages",
                "pricePaise": 45000,
                "stockQuantity": 100,
                "reservedQuantity": 10,
                "unit": "1kg Pack",
                "imageUrl": null
            }
        """.trimIndent()

        val dto = json.decodeFromString<ProductDto>(payload)
        assertEquals("P1", dto.id)
        assertEquals(45000L, dto.pricePaise)
        assertEquals(100, dto.stockQuantity)
        assertEquals(10, dto.reservedQuantity)
        assertNull(dto.imageUrl)

        val entity = dto.toEntity()
        assertEquals(dto.id, entity.id)
        assertEquals(dto.reservedQuantity, entity.reservedQuantity)

        val backToDto = entity.toDto()
        assertEquals(dto, backToDto)
    }

    @Test
    fun decodeOrderItemDto_handlesBooleanSerialization() {
        val payloadTrue = """
            {
                "id": "item_1",
                "orderId": "order_1",
                "productId": "P1",
                "quantity": 5,
                "freeQuantity": 1,
                "pricePaiseAtTime": 45000,
                "isPicked": true
            }
        """.trimIndent()

        val dtoTrue = json.decodeFromString<OrderItemDto>(payloadTrue)
        assertTrue(dtoTrue.isPicked)
        assertEquals(1, dtoTrue.freeQuantity)

        val entityTrue = dtoTrue.toEntity()
        assertTrue(entityTrue.isPicked)
        assertEquals(dtoTrue, entityTrue.toDto())

        val payloadFalse = """
            {
                "id": "item_2",
                "orderId": "order_1",
                "productId": "P2",
                "quantity": 2,
                "freeQuantity": 0,
                "pricePaiseAtTime": 12000,
                "isPicked": false
            }
        """.trimIndent()

        val dtoFalse = json.decodeFromString<OrderItemDto>(payloadFalse)
        assertFalse(dtoFalse.isPicked)
        val entityFalse = dtoFalse.toEntity()
        assertFalse(entityFalse.isPicked)
    }

    @Test
    fun decodeOrderDto_mapsCorrectlyWithNullables() {
        val payload = """
            {
                "id": "ord_100",
                "retailerId": "R1",
                "employeeId": "user_sales",
                "status": "SUBMITTED",
                "totalAmountPaise": 90000,
                "createdAt": 1726243200000,
                "updatedAt": 1726243200000,
                "deliveryEmployeeId": null,
                "rejectionReason": null,
                "paymentMethod": null
            }
        """.trimIndent()

        val dto = json.decodeFromString<OrderDto>(payload)
        assertEquals("ord_100", dto.id)
        assertEquals("SUBMITTED", dto.status)
        assertNull(dto.deliveryEmployeeId)
        assertNull(dto.rejectionReason)

        val entity = dto.toEntity()
        assertEquals(dto.id, entity.id)
        assertEquals(dto.status, entity.status)
        assertNull(entity.rejectionReason)
    }

    @Test
    fun decodeAuthResponse_handlesSnakeCaseAnnotations() {
        val payload = """
            {
                "access_token": "mock.jwt.token",
                "refresh_token": "mock-refresh-uuid",
                "user": {
                    "id": "user_sales",
                    "name": "Rakesh Kumar",
                    "role": "SALESPERSON",
                    "company_id": "comp_1"
                }
            }
        """.trimIndent()

        val auth = json.decodeFromString<AuthResponse>(payload)
        assertEquals("mock.jwt.token", auth.accessToken)
        assertEquals("mock-refresh-uuid", auth.refreshToken)
        assertEquals("user_sales", auth.user?.id)
        assertEquals("Rakesh Kumar", auth.user?.name)
        assertEquals("SALESPERSON", auth.user?.role)
        assertEquals("comp_1", auth.user?.companyId)
    }

    @Test
    fun decodeOrderSubmitResponse_handlesIdempotency() {
        val payload = """{"success":true,"orderId":"ord_100","idempotent":true}"""
        val response = json.decodeFromString<OrderSubmitResponse>(payload)
        assertTrue(response.success)
        assertEquals("ord_100", response.orderId)
        assertTrue(response.idempotent)
    }
}
