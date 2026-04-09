//
//  WellnessSession.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  SwiftData model for wellness coaching sessions
//  Tracks AI interactions with safety metadata
//

import Foundation
import SwiftData

@Model
final class WellnessSession {
    @Attribute(.unique) var id: String
    var userId: String
    var sessionId: String // Backend session ID
    var agentModel: AgentModel
    var messages: [Message]
    var status: SessionStatus
    var startedAt: Date
    var endedAt: Date?
    var safetyFlags: [SafetyFlag]
    var languageCode: String
    var metadata: [String: String]?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        sessionId: String,
        agentModel: AgentModel = .auto,
        messages: [Message] = [],
        status: SessionStatus = .active,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        safetyFlags: [SafetyFlag] = [],
        languageCode: String = "en",
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.sessionId = sessionId
        self.agentModel = agentModel
        self.messages = messages
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.safetyFlags = safetyFlags
        self.languageCode = languageCode
        self.metadata = metadata
    }
    
    var duration: TimeInterval? {
        guard let ended = endedAt else { return nil }
        return ended.timeIntervalSince(startedAt)
    }
}

// MARK: - Message Model
@Model
final class Message {
    @Attribute(.unique) var id: String
    var sessionId: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var agentModel: AgentModel?
    var safetyValidated: Bool
    var containsMedia: Bool
    var mediaUrls: [String]?
    
    init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        agentModel: AgentModel? = nil,
        safetyValidated: Bool = true,
        containsMedia: Bool = false,
        mediaUrls: [String]? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.agentModel = agentModel
        self.safetyValidated = safetyValidated
        self.containsMedia = containsMedia
        self.mediaUrls = mediaUrls
    }
}

// MARK: - Supporting Enums
enum MessageRole: String, Codable, CaseIterable, Identifiable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .user: return NSLocalizedString("You", comment: "Message role")
        case .assistant: return NSLocalizedString("Coach", comment: "Message role")
        case .system: return NSLocalizedString("System", comment: "Message role")
        }
    }
}

enum AgentModel: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case llama4 = "llama4"
    case qwen35 = "qwen35"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("Auto Select", comment: "AI Agent")
        case .llama4: return "Llama 4"
        case .qwen35: return "Qwen 3.5"
        }
    }
    
    var capabilities: String {
        switch self {
        case .auto: return NSLocalizedString("Best agent for your request", comment: "AI Agent")
        case .llama4: return NSLocalizedString("Advanced text reasoning (128K context)", comment: "AI Agent")
        case .qwen35: return NSLocalizedString("Multi-modal analysis (256K context)", comment: "AI Agent")
        }
    }
}

enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case escalated = "escalated" // Crisis escalation
    case failed = "failed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .active: return NSLocalizedString("Active", comment: "Session status")
        case .completed: return NSLocalizedString("Completed", comment: "Session status")
        case .paused: return NSLocalizedString("Paused", comment: "Session status")
        case .escalated: return NSLocalizedString("Escalated", comment: "Session status")
        case .failed: return NSLocalizedString("Failed", comment: "Session status")
        }
    }
}

enum SafetyFlag: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case crisisKeywords = "crisis_keywords"
    case medicalClaim = "medical_claim"
    case selfHarm = "self_harm"
    case emergency = "emergency"
    
    var id: String { rawValue }
    
    var severity: Int {
        switch self {
        case .none: return 0
        case .medicalClaim: return 1
        case .crisisKeywords: return 2
        case .selfHarm: return 3
        case .emergency: return 4
        }
    }
    
    var requiresEscalation: Bool {
        return self == .selfHarm || self == .emergency
    }
}

// MARK: - Preview
#Preview {
    let session = WellnessSession(
        userId: "user_123",
        sessionId: "session_456",
        agentModel: .llama4
    )
    
    let message = Message(
        sessionId: session.sessionId,
        role: .user,
        content: "I'm feeling stressed about work"
    )
    
    session.messages.append(message)
    
    return session
}
