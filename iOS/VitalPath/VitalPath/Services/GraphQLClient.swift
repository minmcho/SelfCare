//
//  GraphQLClient.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Apollo iOS GraphQL client with auth interceptor, retry logic, and circuit breaker
//  Supports Llama 4, Qwen 3.5, and multi-modal requests
//

import Foundation
import Apollo

// MARK: - API Error Types
enum APIError: LocalizedError, Equatable {
    case networkError(Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case graphqlError(errors: [GraphQLError])
    case authenticationRequired
    case serverError(message: String)
    case rateLimitExceeded(retryAfter: TimeInterval)
    case circuitBreakerOpen
    case timeout
    case unknown
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .httpError, .serverError, .timeout:
            return true
        case .authenticationRequired, .rateLimitExceeded, .circuitBreakerOpen, .decodingError, .graphqlError, .unknown:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return NSLocalizedString("Network error: \(error.localizedDescription)", comment: "API Error")
        case .httpError(let statusCode, _):
            return NSLocalizedString("HTTP error: \(statusCode)", comment: "API Error")
        case .decodingError(let error):
            return NSLocalizedString("Decoding error: \(error.localizedDescription)", comment: "API Error")
        case .graphqlError(let errors):
            return errors.first?.message ?? NSLocalizedString("GraphQL error", comment: "API Error")
        case .authenticationRequired:
            return NSLocalizedString("Authentication required", comment: "API Error")
        case .serverError(let message):
            return NSLocalizedString("Server error: \(message)", comment: "API Error")
        case .rateLimitExceeded(let retryAfter):
            return String(format: NSLocalizedString("Rate limit exceeded. Retry in %.0f seconds", comment: "API Error"), retryAfter)
        case .circuitBreakerOpen:
            return NSLocalizedString("Service temporarily unavailable", comment: "API Error")
        case .timeout:
            return NSLocalizedString("Request timeout", comment: "API Error")
        case .unknown:
            return NSLocalizedString("Unknown error occurred", comment: "API Error")
        }
    }
}

// MARK: - Circuit Breaker
class CircuitBreaker {
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    
    init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 60) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }
    
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        guard try await isOpen() == false else {
            throw APIError.circuitBreakerOpen
        }
        
        do {
            let result = try await operation()
            await recordSuccess()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }
    
    private func isOpen() async -> Bool {
        switch state {
        case .closed:
            return false
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > resetTimeout {
                state = .halfOpen
                return false
            }
            return true
        case .halfOpen:
            return false
        }
    }
    
    private func recordSuccess() async {
        failureCount = 0
        state = .closed
    }
    
    private func recordFailure() async {
        failureCount += 1
        lastFailureTime = Date()
        if failureCount >= failureThreshold {
            state = .open
        }
    }
}

// MARK: - Authentication Interceptor
class AuthInterceptor: ApolloInterceptor {
    private let tokenProvider: () async -> String?
    
    init(tokenProvider: @escaping () async -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        Task {
            if let token = await tokenProvider() {
                request.addHeader(name: "Authorization", value: "Bearer \(token)")
            }
            chain.proceedAsync(
                request: request,
                response: response,
                completion: completion
            )
        }
    }
}

// MARK: - Retry Interceptor
class RetryInterceptor: ApolloInterceptor {
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    init(maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        chain.proceedAsync(
            request: request,
            response: response,
            completion: { result in
                switch result {
                case .failure(let error):
                    if let apiError = error as? APIError, apiError.isRetryable {
                        self.retry(chain: chain, request: request, response: response, completion: completion, attempt: 0)
                    } else {
                        completion(result)
                    }
                case .success:
                    completion(result)
                }
            }
        )
    }
    
    private func retry<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void,
        attempt: Int
    ) {
        guard attempt < maxRetries else {
            completion(.failure(APIError.timeout))
            return
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay * Double(attempt + 1)) {
            chain.proceedAsync(
                request: request,
                response: response,
                completion: { result in
                    switch result {
                    case .failure(let error):
                        if let apiError = error as? APIError, apiError.isRetryable {
                            self.retry(chain: chain, request: request, response: response, completion: completion, attempt: attempt + 1)
                        } else {
                            completion(result)
                        }
                    case .success:
                        completion(result)
                    }
                }
            )
        }
    }
}

// MARK: - GraphQL Client
@MainActor
final class GraphQLClient {
    static let shared = GraphQLClient()
    
    private var apolloClient: ApolloClient?
    private let circuitBreaker = CircuitBreaker()
    private var authToken: String?
    
    private init() {}
    
    func configure(baseURL: String, authToken: String? = nil) {
        self.authToken = authToken
        
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        let provider = NetworkTransportProvider { [weak self] in
            let requestChain = RequestChainNetworkTransport(
                interceptorProvider: self?.createInterceptorProvider() ?? DefaultInterceptorProvider(),
                endpointURL: URL(string: baseURL)!
            )
            return requestChain
        }
        
        apolloClient = ApolloClient(networkProvider: provider, store: store)
    }
    
    private func createInterceptorProvider() -> InterceptorProvider {
        return SimpleInterceptorProvider(
            interceptors: [
                AuthInterceptor(tokenProvider: { [weak self] in
                    await self?.authToken
                }),
                RetryInterceptor(),
                MaxRetryInterceptor(maxRetries: 3),
                CacheReadInterceptor(),
                NetworkFetchInterceptor(),
                ResponseCodeInterceptor(),
                JSONResponseParsingInterceptor(),
                CacheWriteInterceptor()
            ]
        )
    }
    
    // MARK: - Query Methods
    
    func fetchWellnessProfile(userId: String) async throws -> WellnessProfileQuery.Data {
        try await circuitBreaker.execute {
            let query = WellnessProfileQuery(userId: userId)
            return try await apolloClient?.fetch(query: query).get().data
                ?? throw APIError.serverError(message: "No data returned")
        }
    }
    
    func sendMessage(
        sessionId: String,
        content: String,
        agentModel: AgentModel,
        languageCode: String,
        mediaUrls: [String]? = nil
    ) async throws -> SendMessageMutation.Data {
        try await circuitBreaker.execute {
            let mutation = SendMessageMutation(
                sessionId: sessionId,
                content: content,
                agentModel: agentModel.rawValue,
                languageCode: languageCode,
                mediaUrls: mediaUrls
            )
            return try await apolloClient?.perform(mutation: mutation).get().data
                ?? throw APIError.serverError(message: "No data returned")
        }
    }
    
    func uploadVideoForAnalysis(
        videoData: Data,
        mimeType: String,
        analysisType: VideoAnalysisType
    ) async throws -> UploadVideoMutation.Data {
        try await circuitBreaker.execute {
            let mutation = UploadVideoMutation(
                videoData: videoData,
                mimeType: mimeType,
                analysisType: analysisType.rawValue
            )
            return try await apolloClient?.perform(mutation: mutation).get().data
                ?? throw APIError.serverError(message: "No data returned")
        }
    }
    
    func getCrisisResources(languageCode: String) async throws -> CrisisResourcesQuery.Data {
        try await circuitBreaker.execute {
            let query = CrisisResourcesQuery(languageCode: languageCode)
            return try await apolloClient?.fetch(query: query).get().data
                ?? throw APIError.serverError(message: "No data returned")
        }
    }
    
    func syncWearableData(
        deviceId: String,
        healthData: [HealthDataPoint]
    ) async throws -> SyncWearableMutation.Data {
        try await circuitBreaker.execute {
            let mutation = SyncWearableMutation(
                deviceId: deviceId,
                healthData: healthData.map { $0.toGraphQLInput() }
            )
            return try await apolloClient?.perform(mutation: mutation).get().data
                ?? throw APIError.serverError(message: "No data returned")
        }
    }
    
    // MARK: - Subscription Methods
    
    func subscribeToSessionUpdates(sessionId: String) -> AsyncThrowingStream<SessionUpdateSubscription.Data, Error> {
        AsyncThrowingStream { continuation in
            let subscription = SessionUpdateSubscription(sessionId: sessionId)
            let cancellable = apolloClient?.subscribe(subscription: subscription) { result in
                switch result {
                case .success(let graphQLResult):
                    if let data = graphQLResult.data {
                        continuation.yield(data)
                    }
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                cancellable?.cancel()
            }
        }
    }
}

// MARK: - Helper Extensions
extension HealthDataPoint {
    func toGraphQLInput() -> HealthDataInput {
        return HealthDataInput(
            type: self.type.rawValue,
            value: self.value,
            unit: self.unit,
            timestamp: self.timestamp.ISO8601Format()
        )
    }
}

// MARK: - GraphQL Operations (Stubs - Generate with Apollo CLI)
// These would be auto-generated by Apollo iOS CLI from your GraphQL schema

struct WellnessProfileQuery: GraphQLQuery {
    typealias Data = WellnessProfileQueryData
    let userId: String
    // Implementation generated by Apollo CLI
}

struct SendMessageMutation: GraphQLMutation {
    typealias Data = SendMessageMutationData
    let sessionId: String
    let content: String
    let agentModel: String
    let languageCode: String
    let mediaUrls: [String]?
    // Implementation generated by Apollo CLI
}

struct UploadVideoMutation: GraphQLMutation {
    typealias Data = UploadVideoMutationData
    let videoData: Data
    let mimeType: String
    let analysisType: String
    // Implementation generated by Apollo CLI
}

struct CrisisResourcesQuery: GraphQLQuery {
    typealias Data = CrisisResourcesQueryData
    let languageCode: String
    // Implementation generated by Apollo CLI
}

struct SyncWearableMutation: GraphQLMutation {
    typealias Data = SyncWearableMutationData
    let deviceId: String
    let healthData: [HealthDataInput]
    // Implementation generated by Apollo CLI
}

struct SessionUpdateSubscription: GraphQLSubscription {
    typealias Data = SessionUpdateSubscriptionData
    let sessionId: String
    // Implementation generated by Apollo CLI
}

// MARK: - Input Types
struct HealthDataInput {
    let type: String
    let value: Double
    let unit: String
    let timestamp: String
}

enum VideoAnalysisType: String {
    case activity = "activity"
    case form = "form"
    case wellness = "wellness"
}
