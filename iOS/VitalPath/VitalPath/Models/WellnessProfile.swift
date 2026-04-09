//
//  WellnessProfile.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  SwiftData model for user wellness profile
//  Supports localization and privacy-preserving data storage
//

import Foundation
import SwiftData

@Model
final class WellnessProfile {
    @Attribute(.unique) var id: String
    var name: String
    var email: String?
    var dateOfBirth: Date?
    var timezone: String
    var languageCode: String
    var wellnessGoals: [String]
    var healthConditions: [String] // Anonymized - no PHI
    var activityLevel: ActivityLevel
    var createdAt: Date
    var updatedAt: Date
    
    // Computed properties
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        email: String? = nil,
        dateOfBirth: Date? = nil,
        timezone: String = TimeZone.current.identifier,
        languageCode: String = "en",
        wellnessGoals: [String] = [],
        healthConditions: [String] = [],
        activityLevel: ActivityLevel = .moderate
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.timezone = timezone
        self.languageCode = languageCode
        self.wellnessGoals = wellnessGoals
        self.healthConditions = healthConditions
        self.activityLevel = activityLevel
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Activity Level Enum
enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sedentary: return NSLocalizedString("Sedentary", comment: "Activity level")
        case .light: return NSLocalizedString("Light Activity", comment: "Activity level")
        case .moderate: return NSLocalizedString("Moderate", comment: "Activity level")
        case .active: return NSLocalizedString("Active", comment: "Activity level")
        case .veryActive: return NSLocalizedString("Very Active", comment: "Activity level")
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return NSLocalizedString("Little or no exercise", comment: "Activity level description")
        case .light: return NSLocalizedString("Light exercise 1-3 days/week", comment: "Activity level description")
        case .moderate: return NSLocalizedString("Moderate exercise 3-5 days/week", comment: "Activity level description")
        case .active: return NSLocalizedString("Hard exercise 6-7 days/week", comment: "Activity level description")
        case .veryActive: return NSLocalizedString("Very hard exercise & physical job", comment: "Activity level description")
        }
    }
}

// MARK: - Preview Model
#Preview {
    WellnessProfile(
        name: "John Doe",
        wellnessGoals: [
            NSLocalizedString("Improve Sleep", comment: "Wellness goal"),
            NSLocalizedString("Reduce Stress", comment: "Wellness goal")
        ],
        activityLevel: .moderate
    )
}
