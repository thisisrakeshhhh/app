package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
import com.routeflow.app.core.database.entity.OrderEntity
import com.routeflow.app.core.database.entity.OrderItemEntity
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.core.database.entity.RetailerEntity
import com.routeflow.app.domain.repository.DemoRepository
import javax.inject.Inject

class OfflineDemoRepository @Inject constructor(
    private val database: RouteFlowDatabase
) : DemoRepository {

    override suspend fun isDemoDataSeeded(): Boolean {
        return database.productDao().getProductCount() > 0
    }

    override suspend fun seedDemoData() {
        database.withTransaction {
            val now = System.currentTimeMillis()
            val retailers = listOf(
                RetailerEntity("R1", "Sharma General Store", "BEAT-04", "Sector 17-C, Chandigarh", "9829012345", 30.7398, 76.7827, 5000000, 1250000, "demo_company", now, "DEMO"),
                RetailerEntity("R2", "Gupta Provision Store", "BEAT-04", "Sector 22-D Market, Chandigarh", "9829023456", 30.7352, 76.7725, 3000000, 450000, "demo_company", now, "DEMO"),
                RetailerEntity("R3", "Balaji Kirana Store", "BEAT-04", "Phase 7 Market, Mohali", "9829034567", 30.7046, 76.7179, 2000000, 890000, "demo_company", now, "DEMO"),
                RetailerEntity("R4", "City Super Mart", "BEAT-04", "Sector 35-C, Chandigarh", "9829045678", 30.7225, 76.7680, 10000000, 2500000, "demo_company", now, "DEMO"),
                RetailerEntity("R5", "Modern General Store", "BEAT-04", "Sector 5, Panchkula", "9829056789", 30.6942, 76.8606, 1500000, 120000, "demo_company", now, "DEMO"),
                RetailerEntity("R6", "Mahadev Departmental Store", "BEAT-04", "Phase 5 Industrial Area, Mohali", "9829067890", 30.7120, 76.7230, 4000000, 670000, "demo_company", now, "DEMO")
            )
            database.retailerDao().insertRetailers(retailers)

            val products = listOf(
                ProductEntity("P1", "Premium Tea", "Beverages", 45000, 100, 0, "1kg Pack"),
                ProductEntity("P2", "Spices Pack", "Groceries", 12000, 200, 0, "200g Pouch"),
                ProductEntity("P3", "Basmati Rice 5kg", "Groceries", 65000, 50, 0, "Bag"),
                ProductEntity("P4", "Cooking Oil 5L", "Groceries", 85000, 80, 0, "Can"),
                ProductEntity("P5", "Soap Case (12 units)", "Personal Care", 36000, 150, 0, "Box"),
                ProductEntity("P6", "Detergent Powder 2kg", "Home Care", 28000, 120, 0, "Pack"),
                ProductEntity("P7", "Salt Pack", "Groceries", 2500, 500, 0, "1kg Pouch"),
                ProductEntity("P8", "Sugar 5kg", "Groceries", 22000, 60, 0, "Bag"),
                ProductEntity("P9", "Pulse Mix 1kg", "Groceries", 14000, 300, 0, "Pack"),
                ProductEntity("P10", "Biscuits Family Pack", "Snacks", 8000, 400, 0, "Pack")
            )
            database.productDao().insertProducts(products)

            val orders = listOf(
                OrderEntity("ORD-DEMO-001", "R1", "EMP-001", "OUT_FOR_DELIVERY", 450000, now, now),
                OrderEntity("ORD-DEMO-002", "R2", "EMP-001", "OUT_FOR_DELIVERY", 320000, now + 1000, now + 1000),
                OrderEntity("ORD-DEMO-003", "R3", "EMP-001", "OUT_FOR_DELIVERY", 890000, now + 2000, now + 2000)
            )
            database.orderDao().insertOrders(orders)

            val orderItems = listOf(
                OrderItemEntity("OI-DEMO-1", "ORD-DEMO-001", "P1", 2, 0, 45000),
                OrderItemEntity("OI-DEMO-2", "ORD-DEMO-002", "P3", 1, 0, 65000),
                OrderItemEntity("OI-DEMO-3", "ORD-DEMO-003", "P4", 1, 0, 85000)
            )
            database.orderDao().insertOrderItems(orderItems)
        }
    }

    override suspend fun resetDemoData() {
        database.withTransaction {
            database.clearAllTables()
            seedDemoData()
        }
    }
}
