package com.routeflow.app.core.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.routeflow.app.core.database.entity.ProductEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProductDao {
    @Query("SELECT * FROM products")
    fun getAllProducts(): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE category = :category")
    fun getProductsByCategory(category: String): Flow<List<ProductEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProducts(products: List<ProductEntity>)

    @Query("SELECT COUNT(*) FROM products")
    suspend fun getProductCount(): Int

    @Query("UPDATE products SET stockQuantity = :newQuantity WHERE id = :productId")
    suspend fun updateStock(productId: String, newQuantity: Int)

    @Query("UPDATE products SET stockQuantity = :newQuantity WHERE id = :productId AND :newQuantity >= reservedQuantity AND :newQuantity >= 0")
    suspend fun updateStockSafely(productId: String, newQuantity: Int): Int

    @Query("UPDATE products SET reservedQuantity = :newReserved WHERE id = :productId")
    suspend fun updateReservation(productId: String, newReserved: Int)

    @Query("UPDATE products SET reservedQuantity = reservedQuantity + :quantity WHERE id = :productId AND (stockQuantity - reservedQuantity) >= :quantity")
    suspend fun reserveStockSafely(productId: String, quantity: Int): Int

    @Query("UPDATE products SET reservedQuantity = max(0, reservedQuantity - :quantity) WHERE id = :productId")
    suspend fun releaseStockSafely(productId: String, quantity: Int): Int

    @Query("UPDATE products SET isActive = :isActive WHERE id = :productId")
    suspend fun updateProductActiveStatus(productId: String, isActive: Boolean)

    @Query("UPDATE products SET name = :name, category = :category, pricePaise = :pricePaise, unit = :unit, isActive = :isActive WHERE id = :productId")
    suspend fun updateProductDetails(productId: String, name: String, category: String, pricePaise: Long, unit: String, isActive: Boolean)

    @Query("SELECT * FROM products WHERE barcode = :barcode OR sku = :barcode LIMIT 1")
    suspend fun getProductByBarcode(barcode: String): ProductEntity?

    @Query("SELECT * FROM products WHERE id = :productId LIMIT 1")
    suspend fun getProductById(productId: String): ProductEntity?

    @Query("DELETE FROM products")
    suspend fun deleteAllProducts()
}
