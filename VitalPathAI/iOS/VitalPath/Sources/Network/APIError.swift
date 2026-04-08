//
//  APIError.swift
//  VitalPath - Wellness Coaching Platform
//
//  Custom error types with retry eligibility for resilient API calls
//

import Foundation

/// Custom error enum for API operations with retry logic
public enum APIError: LocalizedError, Equatable {
    // MARK: - Network Errors
    case networkUnavailable
    case timeout
    case connectionLost
    
    // MARK: - HTTP Errors
    case badRequest(code: Int, message: String?)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(code: Int, message: String?)
    
    // MARK: - Authentication Errors
    case authenticationRequired
    case tokenExpired
    case invalidCredentials
    
    // MARK: - Data Errors
    case decodingError(String)
    case invalidResponse
    case missingData
    
    // MARK: - AI Service Errors
    case aiServiceUnavailable
    case aiServiceTimeout
    case aiServiceRateLimited
    case safetyValidationFailed(reason: String)
    case crisisDetected(resourcesShown: Bool)
    
    // MARK: - Local Storage Errors
    case storageError(String)
    case modelNotFound
    case syncConflict
    
    // MARK: - Error Properties
    /// Whether this error is eligible for automatic retry
    public var isRetryEligible: Bool {
        switch self {
        case .networkUnavailable, .timeout, .connectionLost:
            return true
        case .serverError(let code, _):
            // 5xx errors are generally retryable
            return code >= 500 && code < 600
        case .rateLimited:
            return true // Retry after the specified interval
        case .aiServiceUnavailable, .aiServiceTimeout, .aiServiceRateLimited:
            return true // AI services may recover
        case .authenticationRequired, .tokenExpired:
            return false // Need user action
        case .invalidCredentials:
            return false // Need user action
        default:
            return false
        }
    }
    
    /// Recommended retry delay in seconds
    public var recommendedRetryDelay: TimeInterval {
        switch self {
        case .rateLimited(let retryAfter):
            return retryAfter ?? 60.0
        case .timeout, .connectionLost:
            return 2.0
        case .networkUnavailable:
            return 5.0
        case .serverError:
            return 3.0
        case .aiServiceUnavailable, .aiServiceTimeout:
            return 5.0
        case .aiServiceRateLimited:
            return 30.0
        default:
            return 1.0
        }
    }
    
    /// Whether this error requires fallback chain activation
    public var requiresFallback: Bool {
        switch self {
        case .aiServiceUnavailable, .aiServiceTimeout, .aiServiceRateLimited:
            return true
        case .networkUnavailable, .timeout, .connectionLost:
            return true
        case .serverError(let code, _):
            return code >= 500
        default:
            return false
        }
    }
    
    /// Whether this error indicates a crisis situation
    public var isCrisisError: Bool {
        if case .crisisDetected = self {
            return true
        }
        return false
    }
    
    // MARK: - LocalizedError Conformance
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Connection lost during request"
        case .badRequest(_, let message):
            return message ?? "Invalid request"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests, please wait"
        case .serverError(_, let message):
            return message ?? "Server error occurred"
        case .authenticationRequired:
            return "Please sign in to continue"
        case .tokenExpired:
            return "Session expired, please sign in again"
        case .invalidCredentials:
            return "Invalid username or password"
        case .decodingError(let reason):
            return "Failed to parse response: \(reason)"
        case .invalidResponse:
            return "Received invalid response from server"
        case .missingData:
            return "Required data is missing"
        case .aiServiceUnavailable:
            return "Wellness coaching service temporarily unavailable"
        case .aiServiceTimeout:
            return "Wellness service is taking longer than expected"
        case .aiServiceRateLimited:
            return "Wellness service is busy, please try again shortly"
        case .safetyValidationFailed(let reason):
            return "Content safety check failed: \(reason)"
        case .crisisDetected:
            return "Crisis resources available"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .modelNotFound:
            return "Requested data not found locally"
        case .syncConflict:
            return "Data sync conflict detected"
        }
    }
    
    /// Privacy-safe error description for logging (no user data)
    public var safeForLogging: String {
        switch self {
        case .decodingError:
            return "APIError.decodingError"
        case .badRequest(_, let message):
            return "APIError.badRequest(code: _, message: \(message != nil ? "[REDACTED]" : "nil"))"
        case .serverError(_, let message):
            return "APIError.serverError(code: _, message: \(message != nil ? "[REDACTED]" : "nil"))"
        case .safetyValidationFailed:
            return "APIError.safetyValidationFailed(reason: [REDACTED])"
        default:
            return String(describing: self)
        }
    }
}

// MARK: - Result Extensions
extension Result {
    /// Convert throwing async function to Result with APIError handling
    static func catching(_ operation: () async throws -> Success) async -> Result<Success, APIError> {
        do {
            return .success(try await operation())
        } catch let apiError as APIError {
            return .failure(apiError)
        } catch {
            // Convert unknown errors to appropriate APIError
            if (error as NSError).code == NSURLErrorTimedOut {
                return .failure(.timeout)
            } else if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return .failure(.networkUnavailable)
            } else {
                return .failure(.invalidResponse)
            }
        }
    }
}

// MARK: - Retry Strategy
public struct RetryStrategy {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let exponentialBackoff: Bool
    
    public static let `default` = RetryStrategy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        exponentialBackoff: true
    )
    
    public static let aggressive = RetryStrategy(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 10.0,
        exponentialBackoff: true
    )
    
    public static let conservative = RetryStrategy(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 60.0,
        exponentialBackoff: true
    )
    
    /// Calculate delay for given attempt number
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard exponentialBackoff else { return baseDelay }
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
}
