package com.routeflow.app.data.repository

import androidx.room.withTransaction
import com.routeflow.app.core.database.RouteFlowDatabase
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
            val retailers = listOf(
                RetailerEntity("R1", "Sharma General Store", "BEAT-04", "Main Market, Mansarovar", "9829012345", 26.85, 75.76, 5000000, 1250000),
                RetailerEntity("R2", "Gupta Provision Store", "BEAT-04", "Near Metro Station, Mansarovar", "9829023456", 26.86, 75.77, 3000000, 450000),
                RetailerEntity("R3", "Balaji Kirana Store", "BEAT-04", "SFS Colony, Mansarovar", "9829034567", 26.87, 75.78, 2000000, 890000),
                RetailerEntity("R4", "Pink City Super Mart", "BEAT-04", "VT Road, Mansarovar", "9829045678", 26.88, 75.79, 10000000, 2500000),
                RetailerEntity("R5", "Rajasthan General Store", "BEAT-04", "Patel Marg, Mansarovar", "9829056789", 26.89, 75.80, 1500000, 120000),
                RetailerEntity("R6", "Mahadev Departmental Store", "BEAT-04", "Shipra Path, Mansarovar", "9829067890", 26.90, 75.81, 4000000, 670000)
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
        }
    }

    override suspend fun resetDemoData() {
        database.withTransaction {
            database.clearAllTables()
            seedDemoData()
        }
    }
}
