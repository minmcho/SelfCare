//
//  MessageViewModel.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  View model for chat messages
//

import Foundation

struct MessageViewModel: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let agentModel: AgentModel?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        agentModel: AgentModel? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.agentModel = agentModel
    }
    
    var isUser: Bool {
        role == .user
    }
    
    var isAssistant: Bool {
        role == .assistant
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

enum MessageRole: String {
    case user
    case assistant
    case system
}

enum AgentType: String, CaseIterable, Identifiable {
    case auto = "auto"
    case llama4 = "llama4"
    case qwen35 = "qwen35"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("Auto", comment: "Agent type")
        case .llama4: return "Llama 4"
        case .qwen35: return "Qwen 3.5"
        }
    }
}

struct VideoAnalysisResult: Identifiable {
    let id: String
    let sessionId: String
    let analysisSummary: String
    let detectedActivities: [String]
    let wellnessScore: Double
    let language: String
    let frameCount: Int
    let durationSeconds: TimeInterval
    
    var scorePercentage: Int {
        Int(wellnessScore * 100)
    }
    
    var scoreColor: String {
        if wellnessScore >= 0.8 { return "green" }
        if wellnessScore >= 0.6 { return "yellow" }
        return "red"
    }
}
