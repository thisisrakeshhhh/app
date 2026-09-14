package com.routeflow.app.app

import com.routeflow.app.data.repository.FakeEmployeeRepository
import com.routeflow.app.domain.repository.EmployeeRepository
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
}
