//
//  MessageBubbleView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Chat message bubble with modern iOS styling
//

import SwiftUI

struct MessageBubbleView: View {
    let message: MessageViewModel
    
    var body: some View {
        HStack {
            if message.isAssistant {
                agentAvatar
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.isUser ? Color.teal : Color(.systemGray5))
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                
                HStack(spacing: 8) {
                    if let agent = message.agentModel {
                        Text(agent.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if message.isUser {
                userAvatar
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var agentAvatar: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 30))
            .foregroundColor(.teal)
            .frame(width: 40, height: 40)
            .background(Color.teal.opacity(0.1))
            .clipShape(Circle())
    }
    
    private var userAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 30))
            .foregroundColor(.blue)
            .frame(width: 40, height: 40)
    }
}

#Preview {
    VStack {
        MessageBubbleView(
            message: MessageViewModel(
                role: .user,
                content: "I'm feeling stressed about work today",
                agentModel: nil
            )
        )
        
        MessageBubbleView(
            message: MessageViewModel(
                role: .assistant,
                content: "I understand work stress can be challenging. Let's explore some wellness strategies that might help you manage this feeling.",
                agentModel: .llama4
            )
        )
    }
    .padding()
}
