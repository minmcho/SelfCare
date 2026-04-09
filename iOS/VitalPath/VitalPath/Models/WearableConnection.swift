//
//  WearableConnection.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  SwiftData model for wearable device integration
//  Supports Apple Health, Fitbit, Garmin with circuit breaker pattern
//

import Foundation
import SwiftData

@Model
final class WearableConnection {
    @Attribute(.unique) var id: String
    var userId: String
    var deviceType: WearableDeviceType
    var isConnected: Bool
    var lastSyncAt: Date?
    var permissions: [HealthPermission]
    var syncStatus: SyncStatus
    var failureCount: Int
    var circuitBreakerState: CircuitBreakerState
    var metadata: [String: String]?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        deviceType: WearableDeviceType,
        isConnected: Bool = false,
        lastSyncAt: Date? = nil,
        permissions: [HealthPermission] = [],
        syncStatus: SyncStatus = .disconnected,
        failureCount: Int = 0,
        circuitBreakerState: CircuitBreakerState = .closed,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.lastSyncAt = lastSyncAt
        self.permissions = permissions
        self.syncStatus = syncStatus
        self.failureCount = failureCount
        self.circuitBreakerState = circuitBreakerState
        self.metadata = metadata
    }
    
    var shouldAttemptReconnect: Bool {
        switch circuitBreakerState {
        case .closed: return true
        case .open: return false
        case .halfOpen: return true
        }
    }
    
    func recordFailure() {
        failureCount += 1
        if failureCount >= 5 {
            circuitBreakerState = .open
            syncStatus = .failed
        }
    }
    
    func recordSuccess() {
        failureCount = 0
        circuitBreakerState = .closed
        lastSyncAt = Date()
    }
}

// MARK: - Device Types
enum WearableDeviceType: String, Codable, CaseIterable, Identifiable {
    case appleWatch = "apple_watch"
    case fitbit = "fitbit"
    case garmin = "garmin"
    case oura = "oura"
    case whoop = "whoop"
    case manual = "manual"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .fitbit: return "Fitbit"
        case .garmin: return "Garmin"
        case .oura: return "Oura Ring"
        case .whoop: return "WHOOP"
        case .manual: return NSLocalizedString("Manual Entry", comment: "Device type")
        }
    }
    
    var icon: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .fitbit: return "heart.text.square"
        case .garmin: return "globe"
        case .oura: return "circle.fill"
        case .whoop: return "bandage.fill"
        case .manual: return "pencil.and.outline"
        }
    }
}

// MARK: - Health Permissions
enum HealthPermission: String, Codable, CaseIterable, Identifiable {
    case steps = "steps"
    case heartRate = "heart_rate"
    case sleep = "sleep"
    case workouts = "workouts"
    case calories = "calories"
    case hrv = "hrv"
    case bloodOxygen = "blood_oxygen"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .steps: return NSLocalizedString("Steps", comment: "Health permission")
        case .heartRate: return NSLocalizedString("Heart Rate", comment: "Health permission")
        case .sleep: return NSLocalizedString("Sleep", comment: "Health permission")
        case .workouts: return NSLocalizedString("Workouts", comment: "Health permission")
        case .calories: return NSLocalizedString("Calories", comment: "Health permission")
        case .hrv: return "HRV"
        case .bloodOxygen: return NSLocalizedString("Blood Oxygen", comment: "Health permission")
        }
    }
    
    var description: String {
        switch self {
        case .steps: return NSLocalizedString("Track daily step count", comment: "Health permission")
        case .heartRate: return NSLocalizedString("Monitor heart rate zones", comment: "Health permission")
        case .sleep: return NSLocalizedString("Analyze sleep patterns", comment: "Health permission")
        case .workouts: return NSLocalizedString("Record exercise sessions", comment: "Health permission")
        case .calories: return NSLocalizedString("Track energy expenditure", comment: "Health permission")
        case .hrv: return NSLocalizedString("Heart rate variability", comment: "Health permission")
        case .bloodOxygen: return NSLocalizedString("Blood oxygen saturation", comment: "Health permission")
        }
    }
}

// MARK: - Sync Status
enum SyncStatus: String, Codable, CaseIterable, Identifiable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    case permissionDenied = "permission_denied"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .disconnected: return NSLocalizedString("Disconnected", comment: "Sync status")
        case .connecting: return NSLocalizedString("Connecting...", comment: "Sync status")
        case .syncing: return NSLocalizedString("Syncing...", comment: "Sync status")
        case .synced: return NSLocalizedString("Synced", comment: "Sync status")
        case .failed: return NSLocalizedString("Failed", comment: "Sync status")
        case .permissionDenied: return NSLocalizedString("Permission Denied", comment: "Sync status")
        }
    }
    
    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "blue"
        case .syncing: return "orange"
        case .synced: return "green"
        case .failed: return "red"
        case .permissionDenied: return "yellow"
        }
    }
}

// MARK: - Circuit Breaker State
enum CircuitBreakerState: String, Codable, CaseIterable, Identifiable {
    case closed = "closed"      // Normal operation
    case open = "open"          // Failing, stop attempts
    case halfOpen = "half_open" // Testing recovery
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .closed: return NSLocalizedString("Normal operation", comment: "Circuit breaker")
        case .open: return NSLocalizedString("Temporarily disabled", comment: "Circuit breaker")
        case .halfOpen: return NSLocalizedString("Testing connection", comment: "Circuit breaker")
        }
    }
}

// MARK: - Health Data Point
struct HealthDataPoint: Identifiable, Codable {
    let id: String
    let type: HealthPermission
    let value: Double
    let unit: String
    let timestamp: Date
    let source: WearableDeviceType
    
    init(
        id: String = UUID().uuidString,
        type: HealthPermission,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        source: WearableDeviceType
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
    }
}

// MARK: - Preview
#Preview {
    WearableConnection(
        userId: "user_123",
        deviceType: .appleWatch,
        isConnected: true,
        permissions: [.steps, .heartRate, .sleep],
        syncStatus: .synced
    )
}
