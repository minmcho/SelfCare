//
//  WellnessSession.swift
//  VitalPath - Wellness Coaching Platform
//
//  SwiftData model for AI wellness coaching sessions
//  Implements safety metadata and fallback response tracking
//

import Foundation
import SwiftData

/// Represents a single wellness coaching session with AI
/// SAFETY: Contains validation status and crisis escalation flags
@Model
public final class WellnessSession {
    // MARK: - Identity
    @Attribute(.unique) public var id: String
    /// Reference to parent profile
    public var profileId: String
    
    // MARK: - Session Content (Anonymized)
    /// User's input (stripped of PHI before storage)
    public var userInput: String
    /// AI response (validated against wellness boundaries)
    public var aiResponse: String
    /// Anonymized context sent to AI (for debugging without PHI)
    public var anonymizedContext: String?
    
    // MARK: - Safety Validation
    /// Whether response passed wellness boundary checks
    public var safetyValidated: Bool
    /// Categories detected in user input (for personalization)
    public var detectedCategories: [String]
    /// Crisis keywords detected (triggers escalation)
    public var crisisKeywordsDetected: [String]
    /// Whether crisis resources were shown
    public var crisisResourcesShown: Bool
    
    // MARK: - AI Service Metadata
    /// Which AI provider generated this response
    public var aiProvider: AIProvider
    /// Whether this was a fallback response (AI service unavailable)
    public var isFallbackResponse: Bool
    /// Fallback reason if applicable
    public var fallbackReason: String?
    /// Response latency in milliseconds
    public var responseLatencyMs: Int?
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Relationships
    @Relationship(inverse: \WellnessProfile.sessions)
    public var profile: WellnessProfile?
    
    // MARK: - Computed Properties
    /// Check if session contains crisis indicators
    public var hasCrisisIndicators: Bool {
        !crisisKeywordsDetected.isEmpty || crisisResourcesShown
    }
    
    /// Check if session needs sync to backend
    public var needsSync: Bool {
        profile?.lastSyncedAt == nil || updatedAt > (profile?.lastSyncedAt ?? .distantPast)
    }
    
    // MARK: - Initializers
    public init(
        id: String = UUID().uuidString,
        profileId: String = "",
        userInput: String,
        aiResponse: String,
        anonymizedContext: String? = nil,
        safetyValidated: Bool = false,
        detectedCategories: [String] = [],
        crisisKeywordsDetected: [String] = [],
        crisisResourcesShown: Bool = false,
        aiProvider: AIProvider = .primary,
        isFallbackResponse: Bool = false,
        fallbackReason: String? = nil,
        responseLatencyMs: Int? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.userInput = userInput
        self.aiResponse = aiResponse
        self.anonymizedContext = anonymizedContext
        self.safetyValidated = safetyValidated
        self.detectedCategories = detectedCategories
        self.crisisKeywordsDetected = crisisKeywordsDetected
        self.crisisResourcesShown = crisisResourcesShown
        self.aiProvider = aiProvider
        self.isFallbackResponse = isFallbackResponse
        self.fallbackReason = fallbackReason
        self.responseLatencyMs = responseLatencyMs
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AI Provider Enum
/// Tracks which AI service generated the response for fallback chain analysis
@Observable
public enum AIProvider: String, Codable, CaseIterable {
    case primary = "primary"           // Main CrewAI/OpenClaw agent
    case fallback = "fallback"         // Simplified fallback agent
    case local = "local"               // On-device responses
    case cached = "cached"             // Previously cached response
    case staticResource = "static"     // Static wellness resource
    
    /// Whether this provider supports full AI capabilities
    public var hasFullCapabilities: Bool {
        switch self {
        case .primary: return true
        case .fallback, .local, .cached, .staticResource: return false
        }
    }
}

// MARK: - GraphQL Alignment
/*
 This model aligns with the following GraphQL schema:
 
 type WellnessSession {
   id: ID!
   profileId: ID!
   userInput: String!
   aiResponse: String!
   anonymizedContext: String
   safetyValidated: Boolean!
   detectedCategories: [String!]!
   crisisKeywordsDetected: [String!]!
   crisisResourcesShown: Boolean!
   aiProvider: AIProvider!
   isFallbackResponse: Boolean!
   fallbackReason: String
   responseLatencyMs: Int
   createdAt: DateTime!
   updatedAt: DateTime!
   profile: WellnessProfile
 }
 
 enum AIProvider {
   PRIMARY
   FALLBACK
   LOCAL
   CACHED
   STATIC_RESOURCE
 }
 */
