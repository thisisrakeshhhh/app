package com.routeflow.app.data.repository

import com.routeflow.app.core.database.dao.ProductDao
import com.routeflow.app.core.database.entity.ProductEntity
import com.routeflow.app.domain.model.Product
import com.routeflow.app.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class OfflineProductRepository @Inject constructor(
    private val productDao: ProductDao
) : ProductRepository {
    override fun getAllProducts(): Flow<List<Product>> =
        productDao.getAllProducts().map { entities ->
            entities.map { it.asDomainModel() }
        }

    override fun getProductsByCategory(category: String): Flow<List<Product>> =
        productDao.getProductsByCategory(category).map { entities ->
            entities.map { it.asDomainModel() }
        }

    override suspend fun saveProducts(products: List<Product>) {
        productDao.insertProducts(products.map { it.asEntity() })
    }
}

private fun ProductEntity.asDomainModel() = Product(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    unit = unit,
    imageUrl = imageUrl
)

private fun Product.asEntity() = ProductEntity(
    id = id,
    name = name,
    category = category,
    pricePaise = pricePaise,
    stockQuantity = stockQuantity,
    unit = unit,
    imageUrl = imageUrl
)
