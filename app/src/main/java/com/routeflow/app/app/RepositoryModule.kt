package com.routeflow.app.app

import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.data.repository.NetworkFieldOperationsRepository
import com.routeflow.app.data.repository.NetworkOrderRepository
import com.routeflow.app.data.repository.NetworkShiftRepository
import com.routeflow.app.data.repository.OfflineBeatRepository
import com.routeflow.app.data.repository.OfflineDemoRepository
import com.routeflow.app.data.repository.SecureSessionRepository
import com.routeflow.app.data.repository.OfflineProductRepository
import com.routeflow.app.data.repository.OfflineRetailerRepository
import com.routeflow.app.domain.repository.BeatRepository
import com.routeflow.app.domain.repository.DemoRepository
import com.routeflow.app.domain.repository.EmployeeRepository
import com.routeflow.app.domain.repository.FieldOperationsRepository
import com.routeflow.app.domain.repository.OrderRepository
import com.routeflow.app.domain.repository.ProductRepository
import com.routeflow.app.domain.repository.RetailerRepository
import com.routeflow.app.domain.repository.SessionRepository
import com.routeflow.app.domain.repository.ShiftRepository
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
    abstract fun bindOrderRepository(repository: NetworkOrderRepository): OrderRepository

    @Binds
    @Singleton
    abstract fun bindDemoRepository(repository: OfflineDemoRepository): DemoRepository

    @Binds
    @Singleton
    abstract fun bindSessionRepository(repository: SecureSessionRepository): SessionRepository

    @Binds
    @Singleton
    abstract fun bindBeatRepository(repository: OfflineBeatRepository): BeatRepository

    @Binds
    @Singleton
    abstract fun bindShiftRepository(repository: NetworkShiftRepository): ShiftRepository

    @Binds
    @Singleton
    abstract fun bindFieldOperationsRepository(repository: NetworkFieldOperationsRepository): FieldOperationsRepository

    @Binds
    @Singleton
    abstract fun bindCollectionRepository(repository: com.routeflow.app.data.repository.OfflineCollectionRepository): com.routeflow.app.domain.repository.CollectionRepository

    @Binds
    @Singleton
    abstract fun bindHandoverRepository(repository: com.routeflow.app.data.repository.NetworkHandoverRepository): com.routeflow.app.domain.repository.HandoverRepository

    @Binds
    @Singleton
    abstract fun bindReturnRepository(repository: com.routeflow.app.data.repository.NetworkReturnRepository): com.routeflow.app.domain.repository.ReturnRepository
}
