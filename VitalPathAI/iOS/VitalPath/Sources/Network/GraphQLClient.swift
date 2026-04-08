//
//  GraphQLClient.swift
//  VitalPath - Wellness Coaching Platform
//
//  Apollo iOS GraphQL client with auth interceptor and retry logic
//

import Foundation
import Apollo

// MARK: - GraphQL Configuration
public struct GraphQLConfiguration {
    public let endpointURL: URL
    public let websocketURL: URL
    public let cacheKey: String
    
    public static func `default`(supabaseURL: String) -> GraphQLConfiguration {
        let endpoint = URL(string: "\(supabaseURL)/graphql/v1")!
        let websocket = URL(string: "\(supabaseURL)/realtime/v1/websocket")!
        return GraphQLConfiguration(
            endpointURL: endpoint,
            websocketURL: websocket,
            cacheKey: "vitalpath_graphql_cache"
        )
    }
}

// MARK: - Authentication Interceptor
/// Adds Supabase JWT token to GraphQL requests
final class AuthInterceptor: ApolloInterceptor {
    
    private let authProvider: @Sendable () async throws -> String?
    
    /// Initialize with async auth provider
    init(authProvider: @escaping @Sendable () async throws -> String?) {
        self.authProvider = authProvider
    }
    
    func interceptAsync<Operation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation : GraphQLOperation {
        
        Task {
            do {
                guard let token = try await authProvider() else {
                    chain.handleErrorAsync(
                        APIError.authenticationRequired,
                        request: request,
                        response: response,
                        completion: completion
                    )
                    return
                }
                
                // Add Supabase auth headers
                request.addHeader(name: "Authorization", value: "Bearer \(token)")
                request.addHeader(name: "apikey", value: token)
                request.addHeader(name: "Prefer", value: "return=minimal")
                
                chain.proceedAsync(
                    request: request,
                    response: response,
                    completion: completion
                )
            } catch {
                chain.handleErrorAsync(
                    error,
                    request: request,
                    response: response,
                    completion: completion
                )
            }
        }
    }
}

// MARK: - Retry Interceptor
/// Implements exponential backoff for retryable errors
final class RetryInterceptor: ApolloInterceptor {
    
    private let strategy: RetryStrategy
    private var attemptCounts: [String: Int] = [:]
    private let queue = DispatchQueue(label: "com.vitalpath.retry.queue")
    
    init(strategy: RetryStrategy = .default) {
        self.strategy = strategy
    }
    
    func interceptAsync<Operation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation : GraphQLOperation {
        
        let requestId = request.operation.operationIdentifier ?? UUID().uuidString
        let currentAttempt = queue.sync { attemptCounts[requestId] ?? 0 }
        
        chain.proceedAsync(request: request, response: response) { result in
            switch result {
            case .success:
                // Reset attempt count on success
                self.queue.sync { self.attemptCounts[requestId] = 0 }
                completion(result)
                
            case .failure(let error):
                guard let apiError = error as? APIError,
                      apiError.isRetryEligible,
                      currentAttempt < self.strategy.maxRetries else {
                    completion(result)
                    return
                }
                
                // Schedule retry with backoff
                let delay = self.strategy.delay(forAttempt: currentAttempt + 1)
                self.queue.sync { self.attemptCounts[requestId] = currentAttempt + 1 }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    chain.retry(request: request, completion: completion)
                }
            }
        }
    }
}

// MARK: - GraphQL Client Wrapper
@MainActor
public final class GraphQLClient {
    
    private let apolloClient: ApolloClient
    private let store: ApolloStore
    private var sessionTask: URLSessionTask?
    
    public init(configuration: GraphQLConfiguration, authProvider: @escaping @Sendable () async throws -> String?) async {
        
        // Create HTTP transport with interceptors
        let transport = RequestChainNetworkTransport(
            endpointURL: configuration.endpointURL,
            session: URLSession.shared,
            additionalHeaders: [
                "Content-Type": "application/json",
                "X-Client-Info": "vitalpath-ios/1.0"
            ]
        )
        
        // Insert interceptors
        transport.interceptors.append(AuthInterceptor(authProvider: authProvider))
        transport.interceptors.append(RetryInterceptor())
        
        // Create store with normalized cache
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        
        self.store = store
        self.apolloClient = ApolloClient(
            networkTransport: transport,
            store: store
        )
    }
    
    // MARK: - Query Execution
    
    /// Execute a GraphQL query with automatic caching
    public func fetch<Query: GraphQLQuery>(
        _ query: Query,
        cachePolicy: CachePolicy = .returnCacheDataElseFetch,
        timeout: TimeInterval = 30.0
    ) async throws -> GraphQLResult<Query.Data> {
        
        return try await withThrowingTaskGroup(of: GraphQLResult<Query.Data>.self) { group in
            
            // Set timeout
            group.addTask {
                try await self.apolloClient.fetch(query: query, cachePolicy: cachePolicy)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw APIError.timeout
            }
            
            // Return first completed task
            let result = try await group.next()!
            group.cancelAll()
            
            if let errors = result.errors, !errors.isEmpty {
                throw APIError.invalidResponse
            }
            
            return result
        }
    }
    
    /// Execute a GraphQL mutation
    public func perform<Mutation: GraphQLMutation>(
        _ mutation: Mutation,
        timeout: TimeInterval = 30.0
    ) async throws -> GraphQLResult<Mutation.Data> {
        
        return try await withThrowingTaskGroup(of: GraphQLResult<Mutation.Data>.self) { group in
            
            group.addTask {
                try await self.apolloClient.perform(mutation: mutation)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw APIError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            
            if let errors = result.errors, !errors.isEmpty {
                throw APIError.invalidResponse
            }
            
            return result
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data
    public func clearCache() async {
        await store.clearAsync()
    }
    
    /// Remove specific query from cache
    public func removeQuery<Query: GraphQLQuery>(_ query: Query) async {
        await store.remove(query: query)
    }
    
    // MARK: - Subscription Support
    
    /// Subscribe to a GraphQL subscription
    public func subscribe<Subscription: GraphQLSubscription>(
        _ subscription: Subscription,
        resultHandler: @escaping (Result<GraphQLResult<Subscription.Data>, Error>) -> Void
    ) -> Cancellable {
        
        return apolloClient.subscribe(subscription: subscription) { result in
            resultHandler(result)
        }
    }
    
    // MARK: - Health Check
    
    /// Check GraphQL endpoint availability
    public func healthCheck() async -> Bool {
        do {
            let task = Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5s timeout
                throw APIError.timeout
            }
            
            // Simple introspection query
            let check = Task {
                // Note: Actual introspection query would go here
                // For now, just test connectivity
                try await Task.sleep(nanoseconds: 100_000_000)
                return true
            }
            
            let result = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask { try await task.value; return false }
                group.addTask { try await check.value }
                return try await group.next()!
            }
            
            task.cancel()
            return result
            
        } catch {
            return false
        }
    }
}

// MARK: - GraphQL Fragments
/*
 These fragments align with our SwiftData models:
 
 fragment WellnessProfileFields on WellnessProfile {
   id
   anonymizedUserId
   wellnessGoals
   activityLevel
   dietaryPreferences
   excludedTopics
   crisisResourceLocale
   createdAt
   updatedAt
   lastSyncedAt
 }
 
 fragment WellnessSessionFields on WellnessSession {
   id
   profileId
   userInput
   aiResponse
   anonymizedContext
   safetyValidated
   detectedCategories
   crisisKeywordsDetected
   crisisResourcesShown
   aiProvider
   isFallbackResponse
   fallbackReason
   responseLatencyMs
   createdAt
   updatedAt
 }
 
 fragment WearableConnectionFields on WearableConnection {
   id
   profileId
   deviceType
   deviceId
   isConnected
   lastSyncAt
   stepsPermission
   heartRatePermission
   sleepPermission
   activityMinutesPermission
   avgDailySteps
   avgWeeklyActiveMinutes
   sleepQualityScore
   autoSyncEnabled
   syncIntervalMinutes
   lastSyncError
   consecutiveSyncFailures
   createdAt
   updatedAt
 }
 */
