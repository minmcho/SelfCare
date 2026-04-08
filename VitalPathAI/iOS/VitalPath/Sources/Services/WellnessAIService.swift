//
//  WellnessAIService.swift
//  VitalPath - Wellness Coaching Platform
//
//  AI wellness service with fallback chain for resilience
//  Implements circuit breaker pattern and graceful degradation
//

import Foundation

// MARK: - Service Configuration
public struct WellnessAIServiceConfiguration {
    public let primaryEndpoint: URL
    public let fallbackEndpoint: URL
    public let timeout: TimeInterval
    public let maxConcurrentRequests: Int
    
    public static let `default` = WellnessAIServiceConfiguration(
        primaryEndpoint: URL(string: "https://ai.vitalpath.app/wellness")!,
        fallbackEndpoint: URL(string: "https://fallback.vitalpath.app/wellness")!,
        timeout: 15.0,
        maxConcurrentRequests: 5
    )
}

// MARK: - AI Response Model
public struct WellnessAIResponse: Codable {
    public let response: String
    public let categories: [String]
    public let crisisKeywords: [String]
    public let requiresCrisisResources: Bool
    public let confidenceScore: Double
    public let provider: String
    public let latencyMs: Int
    public let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case response, categories, crisisKeywords, requiresCrisisResources
        case confidenceScore, provider, latencyMs, metadata
    }
}

// MARK: - Circuit Breaker State
enum CircuitBreakerState {
    case closed      // Normal operation
    case open        // Failing, use fallback
    case halfOpen    // Testing if service recovered
    
    var allowsRequests: Bool {
        switch self {
        case .closed, .halfOpen: return true
        case .open: return false
        }
    }
}

// MARK: - Circuit Breaker
final class CircuitBreaker {
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private var state: CircuitBreakerState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let queue = DispatchQueue(label: "com.vitalpath.circuitbreaker")
    
    init(failureThreshold: Int = 5, recoveryTimeout: TimeInterval = 30.0) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
    }
    
    func recordSuccess() {
        queue.sync {
            failureCount = 0
            state = .closed
        }
    }
    
    func recordFailure() {
        queue.sync {
            failureCount += 1
            lastFailureTime = Date()
            
            if failureCount >= failureThreshold {
                state = .open
            }
        }
    }
    
    func canExecute() -> Bool {
        queue.sync {
            switch state {
            case .closed:
                return true
            case .open:
                // Check if recovery timeout has passed
                if let lastFailure = lastFailureTime,
                   Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                    state = .halfOpen
                    return true
                }
                return false
            case .halfOpen:
                return true
            }
        }
    }
    
    var currentState: CircuitBreakerState {
        queue.sync { state }
    }
}

// MARK: - Wellness AI Service
@MainActor
public final class WellnessAIService {
    
    private let configuration: WellnessAIServiceConfiguration
    private let session: URLSession
    private let circuitBreaker: CircuitBreaker
    private let safetyValidator: SafetyValidatorProtocol
    private var activeTask: Task<WellnessAIResponse, Error>?
    
    public init(
        configuration: WellnessAIServiceConfiguration = .default,
        safetyValidator: SafetyValidatorProtocol
    ) {
        self.configuration = configuration
        self.safetyValidator = safetyValidator
        
        // Configure session with timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout * 2
        config.httpMaximumConnectionsPerHost = configuration.maxConcurrentRequests
        self.session = URLSession(configuration: config)
        
        self.circuitBreaker = CircuitBreaker()
    }
    
    // MARK: - Primary Request Method
    
    /// Send user input to AI service with full fallback chain
    /// - Parameters:
    ///   - userInput: User's message (will be anonymized before sending)
    ///   - context: Optional conversation context
    ///   - profileId: User's profile ID for personalization
    /// - Returns: Validated wellness response with safety metadata
    public func getWellnessResponse(
        userInput: String,
        context: String? = nil,
        profileId: String
    ) async throws -> WellnessAIResponse {
        
        // Cancel any in-flight request
        activeTask?.cancel()
        
        // Anonymize input before any network calls (PRIVACY FIRST)
        let anonymizedInput = await anonymizeInput(userInput)
        let anonymizedContext = context.map { anonymizeContext($0) }
        
        // Try primary AI service first
        do {
            let response = try await executeWithFallbackChain(
                input: anonymizedInput,
                context: anonymizedContext,
                profileId: profileId
            )
            
            // Validate response against wellness boundaries (SAFETY FIRST)
            let validationResult = await safetyValidator.validateResponse(response.response)
            
            if !validationResult.isValid {
                throw APIError.safetyValidationFailed(reason: validationResult.reason)
            }
            
            // Check for crisis indicators
            if !response.crisisKeywords.isEmpty || validationResult.requiresCrisisResources {
                throw APIError.crisisDetected(resourcesShown: true)
            }
            
            return response
            
        } catch {
            // Log error safely (no user data)
            logError(error)
            throw error
        }
    }
    
    // MARK: - Fallback Chain Execution
    
    private func executeWithFallbackChain(
        input: String,
        context: String?,
        profileId: String
    ) async throws -> WellnessAIResponse {
        
        // Try 1: Primary AI Service (if circuit breaker allows)
        if circuitBreaker.canExecute() {
            do {
                return try await callPrimaryService(input: input, context: context, profileId: profileId)
            } catch {
                circuitBreaker.recordFailure()
                // Continue to fallback
            }
        }
        
        // Try 2: Fallback AI Service (simplified model)
        do {
            return try await callFallbackService(input: input, context: context, profileId: profileId)
        } catch {
            // Continue to local responses
        }
        
        // Try 3: Cached Response (if available)
        if let cached = await getCachedResponse(input: input) {
            return cached
        }
        
        // Try 4: Local Wellness Tips (pre-defined safe responses)
        return generateLocalResponse(for: input)
    }
    
    // MARK: - Primary Service Call
    
    private func callPrimaryService(
        input: String,
        context: String?,
        profileId: String
    ) async throws -> WellnessAIResponse {
        
        var request = URLRequest(url: configuration.primaryEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeout
        
        let payload: [String: Any] = [
            "input": input,
            "context": context as Any,
            "profileId": profileId,
            "provider": "primary"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw handleHTTPError(statusCode: httpResponse.statusCode)
        }
        
        let aiResponse = try JSONDecoder().decode(WellnessAIResponse.self, from: data)
        circuitBreaker.recordSuccess()
        
        return aiResponse
    }
    
    // MARK: - Fallback Service Call
    
    private func callFallbackService(
        input: String,
        context: String?,
        profileId: String
    ) async throws -> WellnessAIResponse {
        
        var request = URLRequest(url: configuration.fallbackEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeout / 2 // Shorter timeout for fallback
        
        let payload: [String: Any] = [
            "input": input,
            "profileId": profileId,
            "provider": "fallback"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.aiServiceUnavailable
        }
        
        var aiResponse = try JSONDecoder().decode(WellnessAIResponse.self, from: data)
        // Mark as fallback response
        // Note: In production, this would be set by the server
        
        return aiResponse
    }
    
    // MARK: - Input Anonymization (PRIVACY FIRST)
    
    private func anonymizeInput(_ input: String) async -> String {
        // Remove potential PHI patterns
        var anonymized = input
        
        // Remove phone numbers
        let phoneRegex = #"(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        if let regex = try? NSRegularExpression(pattern: phoneRegex) {
            let range = NSRange(anonymized.startIndex..., in: anonymized)
            anonymized = regex.stringByReplacingMatches(
                in: anonymized,
                range: range,
                withTemplate: "[PHONE_REDACTED]"
            )
        }
        
        // Remove email addresses
        let emailRegex = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailRegex) {
            let range = NSRange(anonymized.startIndex..., in: anonymized)
            anonymized = regex.stringByReplacingMatches(
                in: anonymized,
                range: range,
                withTemplate: "[EMAIL_REDACTED]"
            )
        }
        
        // Remove medical IDs (pattern: letters + numbers)
        let medicalIdRegex = #"\b[A-Z]{2,}\d{4,}\b"#
        if let regex = try? NSRegularExpression(pattern: medicalIdRegex) {
            let range = NSRange(anonymized.startIndex..., in: anonymized)
            anonymized = regex.stringByReplacingMatches(
                in: anonymized,
                range: range,
                withTemplate: "[ID_REDACTED]"
            )
        }
        
        return anonymized
    }
    
    private func anonymizeContext(_ context: String) -> String {
        // Simplified context anonymization
        // In production, this would use more sophisticated NLP
        return context
            .replacingOccurrences(of: #"\"name\":\s*\"[^\"]+\""#, with: "\"name\": \"[REDACTED]\"", options: .regularExpression)
            .replacingOccurrences(of: #"\"age\":\s*\d+"#, with: "\"age\": [REDACTED]", options: .regularExpression)
    }
    
    // MARK: - Cache Management
    
    private func getCachedResponse(input: String) async -> WellnessAIResponse? {
        // TODO: Implement semantic cache using pgvector similarity
        // For now, return nil to skip cache
        return nil
    }
    
    // MARK: - Local Response Generation
    
    private func generateLocalResponse(for input: String) -> WellnessAIResponse {
        // Generate safe, generic wellness tips based on detected intent
        let categories = detectIntentCategories(input)
        
        let safeResponses: [String: String] = [
            "stress": "Consider trying deep breathing exercises or a short walk. Small steps toward relaxation can make a big difference in your day.",
            "sleep": "Creating a consistent sleep schedule and limiting screen time before bed can support better rest. What's your current bedtime routine like?",
            "nutrition": "Balanced meals with plenty of vegetables and whole foods support overall wellness. Have you explored any new healthy recipes lately?",
            "exercise": "Regular movement, even just 10 minutes a day, can boost energy and mood. What types of activities do you enjoy?",
            "mindfulness": "Taking a few moments each day for mindful breathing can help center your thoughts. Would you like to try a quick breathing exercise?",
            "default": "Small, consistent steps toward wellness can make a meaningful difference. What area of wellness feels most important to you right now?"
        ]
        
        let category = categories.first ?? "default"
        let response = safeResponses[category] ?? safeResponses["default"]!
        
        return WellnessAIResponse(
            response: response,
            categories: categories,
            crisisKeywords: [],
            requiresCrisisResources: false,
            confidenceScore: 0.6,
            provider: "local",
            latencyMs: 0,
            metadata: ["fallback_reason": "service_unavailable"]
        )
    }
    
    private func detectIntentCategories(_ input: String) -> [String] {
        let lowercased = input.lowercased()
        var categories: [String] = []
        
        if lowercased.contains("stress") || lowercased.contains("anxious") || lowercased.contains("overwhelmed") {
            categories.append("stress")
        }
        if lowercased.contains("sleep") || lowercased.contains("tired") || lowercased.contains("insomnia") {
            categories.append("sleep")
        }
        if lowercased.contains("eat") || lowercased.contains("food") || lowercased.contains("diet") || lowercased.contains("nutrition") {
            categories.append("nutrition")
        }
        if lowercased.contains("exercise") || lowercased.contains("workout") || lowercased.contains("activity") {
            categories.append("exercise")
        }
        if lowercased.contains("mindful") || lowercased.contains("meditate") || lowercased.contains("breathe") {
            categories.append("mindfulness")
        }
        
        return categories.isEmpty ? ["general"] : categories
    }
    
    // MARK: - Error Handling
    
    private func handleHTTPError(statusCode: Int) -> APIError {
        switch statusCode {
        case 401, 403:
            return .unauthorized
        case 429:
            return .aiServiceRateLimited
        case 500..<600:
            return .aiServiceUnavailable
        default:
            return .invalidResponse
        }
    }
    
    private func logError(_ error: Error) {
        // PRIVACY: Never log user input or responses
        // Only log error type and safe metadata
        print("[WellnessAIService] Error: \(error.localizedDescription)")
        // In production, send to Sentry with privacy filters
    }
    
    // MARK: - Public Properties
    
    public var circuitBreakerStatus: String {
        switch circuitBreaker.currentState {
        case .closed: return "Healthy"
        case .open: return "Open (Using Fallback)"
        case .halfOpen: return "Testing Recovery"
        }
    }
}

// MARK: - Protocol for Testing
public protocol SafetyValidatorProtocol {
    func validateResponse(_ response: String) async -> ValidationResult
}

public struct ValidationResult {
    public let isValid: Bool
    public let reason: String
    public let requiresCrisisResources: Bool
    
    public static let valid = ValidationResult(isValid: true, reason: "", requiresCrisisResources: false)
}
