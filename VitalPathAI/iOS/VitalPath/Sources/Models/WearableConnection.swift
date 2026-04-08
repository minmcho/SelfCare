//
//  WearableConnection.swift
//  VitalPath - Wellness Coaching Platform
//
//  SwiftData model for wearable device integration
//  Supports HealthKit, Apple Watch, and third-party fitness trackers
//

import Foundation
import SwiftData

/// Represents a connected wearable device for wellness data
/// PRIVACY: Only stores anonymized aggregate data, never raw health metrics
@Model
public final class WearableConnection {
    // MARK: - Identity
    @Attribute(.unique) public var id: String
    /// Reference to owning profile
    public var profileId: String
    
    // MARK: - Device Information
    /// Device type (Apple Watch, Fitbit, Garmin, etc.)
    public var deviceType: WearableDeviceType
    /// Device identifier (anonymized)
    public var deviceId: String
    /// Whether connection is currently active
    public var isConnected: Bool
    /// Last sync timestamp
    public var lastSyncAt: Date?
    
    // MARK: - Permissions
    /// Steps data permission granted
    public var stepsPermission: Bool
    /// Heart rate data permission granted (aggregate only)
    public var heartRatePermission: Bool
    /// Sleep data permission granted
    public var sleepPermission: Bool
    /// Activity minutes permission granted
    public var activityMinutesPermission: Bool
    
    // MARK: - Aggregated Metrics (NOT raw data)
    /// Daily step count average (last 7 days)
    public var avgDailySteps: Int?
    /// Weekly active minutes average
    public var avgWeeklyActiveMinutes: Int?
    /// Sleep quality score (1-10, anonymized)
    public var sleepQualityScore: Int?
    
    // MARK: - Sync Status
    /// Whether auto-sync is enabled
    public var autoSyncEnabled: Bool
    /// Sync interval in minutes
    public var syncIntervalMinutes: Int
    /// Last error message if sync failed
    public var lastSyncError: String?
    /// Consecutive sync failures (for circuit breaker)
    public var consecutiveSyncFailures: Int
    
    // MARK: - Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Relationships
    @Relationship(inverse: \WellnessProfile.wearableConnection)
    public var profile: WellnessProfile?
    
    // MARK: - Computed Properties
    /// Check if wearable has any permissions granted
    public var hasAnyPermissions: Bool {
        stepsPermission || heartRatePermission || sleepPermission || activityMinutesPermission
    }
    
    /// Check if sync is overdue
    public var isSyncOverdue: Bool {
        guard let lastSync = lastSyncAt, autoSyncEnabled else { return false }
        return Date().timeIntervalSince(lastSync) > TimeInterval(syncIntervalMinutes * 60)
    }
    
    /// Check if circuit breaker should activate
    public var shouldActivateCircuitBreaker: Bool {
        consecutiveSyncFailures >= 5
    }
    
    // MARK: - Initializers
    public init(
        id: String = UUID().uuidString,
        profileId: String = "",
        deviceType: WearableDeviceType = .appleWatch,
        deviceId: String = "",
        isConnected: Bool = false,
        stepsPermission: Bool = false,
        heartRatePermission: Bool = false,
        sleepPermission: Bool = false,
        activityMinutesPermission: Bool = false
    ) {
        self.id = id
        self.profileId = profileId
        self.deviceType = deviceType
        self.deviceId = deviceId
        self.isConnected = isConnected
        self.stepsPermission = stepsPermission
        self.heartRatePermission = heartRatePermission
        self.sleepPermission = sleepPermission
        self.activityMinutesPermission = activityMinutesPermission
        self.autoSyncEnabled = true
        self.syncIntervalMinutes = 30
        self.consecutiveSyncFailures = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Methods
    /// Record successful sync
    public func recordSuccessfulSync() {
        lastSyncAt = Date()
        consecutiveSyncFailures = 0
        lastSyncError = nil
        updatedAt = Date()
    }
    
    /// Record failed sync with circuit breaker logic
    public func recordFailedSync(error: String) {
        consecutiveSyncFailures += 1
        lastSyncError = error
        updatedAt = Date()
    }
    
    /// Reset circuit breaker
    public func resetCircuitBreaker() {
        consecutiveSyncFailures = 0
        lastSyncError = nil
        updatedAt = Date()
    }
}

// MARK: - Wearable Device Types
@Observable
public enum WearableDeviceType: String, Codable, CaseIterable {
    case appleWatch = "apple_watch"
    case fitbit = "fitbit"
    case garmin = "garmin"
    case oura = "oura"
    case whoop = "whoop"
    case other = "other"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .fitbit: return "Fitbit"
        case .garmin: return "Garmin"
        case .oura: return "Oura Ring"
        case .whoop: return "WHOOP"
        case .other: return "Other Device"
        }
    }
    
    /// Supported data types per device
    public var supportedDataTypes: [WearableDataType] {
        switch self {
        case .appleWatch:
            return [.steps, .heartRate, .sleep, .activityMinutes, .workouts]
        case .fitbit:
            return [.steps, .heartRate, .sleep, .activityMinutes]
        case .garmin:
            return [.steps, .heartRate, .sleep, .activityMinutes, .workouts]
        case .oura:
            return [.sleep, .heartRate, .activityMinutes]
        case .whoop:
            return [.heartRate, .sleep, .activityMinutes]
        case .other:
            return [.steps]
        }
    }
}

// MARK: - Wearable Data Types
@Observable
public enum WearableDataType: String, Codable, CaseIterable {
    case steps = "steps"
    case heartRate = "heart_rate"
    case sleep = "sleep"
    case activityMinutes = "activity_minutes"
    case workouts = "workouts"
    
    /// Display name
    public var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .sleep: return "Sleep"
        case .activityMinutes: return "Active Minutes"
        case .workouts: return "Workouts"
        }
    }
}

// MARK: - GraphQL Alignment
/*
 This model aligns with the following GraphQL schema:
 
 type WearableConnection {
   id: ID!
   profileId: ID!
   deviceType: WearableDeviceType!
   deviceId: String!
   isConnected: Boolean!
   lastSyncAt: DateTime
   stepsPermission: Boolean!
   heartRatePermission: Boolean!
   sleepPermission: Boolean!
   activityMinutesPermission: Boolean!
   avgDailySteps: Int
   avgWeeklyActiveMinutes: Int
   sleepQualityScore: Int
   autoSyncEnabled: Boolean!
   syncIntervalMinutes: Int!
   lastSyncError: String
   consecutiveSyncFailures: Int!
   createdAt: DateTime!
   updatedAt: DateTime!
   profile: WellnessProfile
 }
 
 enum WearableDeviceType {
   APPLE_WATCH
   FITBIT
   GARMIN
   OURA
   WHOOP
   OTHER
 }
 
 enum WearableDataType {
   STEPS
   HEART_RATE
   SLEEP
   ACTIVITY_MINUTES
   WORKOUTS
 }
 */
