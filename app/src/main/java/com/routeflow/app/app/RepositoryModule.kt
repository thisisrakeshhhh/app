package com.routeflow.app.app

import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.data.repository.InMemorySessionRepository
import com.routeflow.app.data.repository.OfflineDemoRepository
import com.routeflow.app.data.repository.OfflineProductRepository
import com.routeflow.app.data.repository.OfflineRetailerRepository
import com.routeflow.app.domain.repository.DemoRepository
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindEmployeeRepository(repository: FakeEmployeeRepository): EmployeeRepository

    @Binds
    @Singleton
    abstract fun bindRetailerRepository(repository: OfflineRetailerRepository): RetailerRepository

    @Binds
    @Singleton
    abstract fun bindProductRepository(repository: OfflineProductRepository): ProductRepository

    @Binds
    @Singleton
    abstract fun bindDemoRepository(repository: OfflineDemoRepository): DemoRepository

    @Binds
    @Singleton
    abstract fun bindSessionRepository(repository: InMemorySessionRepository): SessionRepository
}
