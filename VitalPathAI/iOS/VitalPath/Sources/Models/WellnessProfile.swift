//
//  WellnessProfile.swift
//  VitalPath - Wellness Coaching Platform
//
//  SwiftData model for user wellness profile with privacy-first design
//  Aligns with GraphQL schema for Supabase backend sync
//

import Foundation
import SwiftData

/// Represents a user's wellness profile with safety boundaries
/// CRITICAL: Never store PHI (Protected Health Information) in this model
@Model
public final class WellnessProfile {
    // MARK: - Identity (Anonymized)
    /// Internal UUID - never expose to backend directly
    @Attribute(.unique) public var id: String
    /// Anonymized user reference for backend sync (hashed supabase auth ID)
    public var anonymizedUserId: String
    
    // MARK: - Wellness Goals (NOT medical objectives)
    /// User-selected wellness focus areas (e.g., "Better Sleep", "Stress Management")
    public var wellnessGoals: [String]
    /// Activity level for lifestyle recommendations only
    public var activityLevel: ActivityLevel
    /// Dietary preferences (NOT medical restrictions)
    public var dietaryPreferences: [String]
    
    // MARK: - Safety Boundaries
    /// Topics user wants to avoid
    public var excludedTopics: [String]
    /// Crisis resources locale (defaults to user's region)
    public var crisisResourceLocale: String
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    public var lastSyncedAt: Date?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \WellnessSession.profile)
    public var sessions: [WellnessSession]
    
    @Relationship(deleteRule: .nullify)
    public var wearableConnection: WearableConnection?
    
    // MARK: - Computed Properties
    /// Check if profile needs backend sync
    public var needsSync: Bool {
        lastSyncedAt == nil || lastSyncedAt! < updatedAt
    }
    
    // MARK: - Initializers
    public init(
        id: String = UUID().uuidString,
        anonymizedUserId: String = "",
        wellnessGoals: [String] = [],
        activityLevel: ActivityLevel = .moderate,
        dietaryPreferences: [String] = [],
        excludedTopics: [String] = [],
        crisisResourceLocale: String = "US"
    ) {
        self.id = id
        self.anonymizedUserId = anonymizedUserId
        self.wellnessGoals = wellnessGoals
        self.activityLevel = activityLevel
        self.dietaryPreferences = dietaryPreferences
        self.excludedTopics = excludedTopics
        self.crisisResourceLocale = crisisResourceLocale
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sessions = []
    }
}

// MARK: - Activity Level Enum
/// Lifestyle activity classification - NOT medical assessment
@Observable
public enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .sedentary: return "Mostly Sitting"
        case .light: return "Light Activity"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
}

// MARK: - GraphQL Alignment
/*
 This model aligns with the following GraphQL schema:
 
 type WellnessProfile {
   id: ID!
   anonymizedUserId: String!
   wellnessGoals: [String!]!
   activityLevel: ActivityLevel!
   dietaryPreferences: [String!]!
   excludedTopics: [String!]!
   crisisResourceLocale: String!
   createdAt: DateTime!
   updatedAt: DateTime!
   lastSyncedAt: DateTime
   sessions: [WellnessSession!]!
   wearableConnection: WearableConnection
 }
 
 enum ActivityLevel {
   SEDENTARY
   LIGHT
   MODERATE
   ACTIVE
   VERY_ACTIVE
 }
 */
