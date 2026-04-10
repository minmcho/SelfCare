//
//  MessageBubbleView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Glass-morphic chat message bubble with rich animations
//

import SwiftUI

struct MessageBubbleView: View {
    let message: MessageViewModel
    
    @State private var appears = false
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            if message.isAssistant {
                agentAvatar
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Agent indicator for assistant messages
                if let agent = message.agentModel, message.isAssistant {
                    Text(agent.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.teal.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Message bubble with glass effect
                Text(message.content)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            message.isUser ? Color.teal.opacity(0.9) : Color(.systemGray5).opacity(0.7),
                                            message.isUser ? Color.teal : Color(.systemGray5).opacity(0.5)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            if !message.isUser {
                                // Glass material overlay for assistant
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.3)
                                
                                // Subtle gradient border
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.teal.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .shadow(color: message.isUser ? Color.teal.opacity(0.3) : Color.black.opacity(0.05),
                            radius: isHovering ? 10 : 6, x: 0, y: isHovering ? 5 : 3)
                    .scaleEffect(isHovering ? 1.015 : 1.0)
                
                // Timestamp and metadata
                HStack(spacing: 8) {
                    if let agent = message.agentModel, message.isUser {
                        Text(agent.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.formattedTime)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            
            if message.isUser {
                userAvatar
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0).delay(0.05)) {
                appears = true
            }
        }
        .offset(y: appears ? 0 : 15)
        .opacity(appears ? 1 : 0)
    }
    
    private var agentAvatar: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 32, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.teal, .green]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                }
            )
            .shadow(color: .teal.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(appears ? 1.0 : 0.0)
    }
    
    private var userAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 36, weight: .medium))
            .foregroundColor(.blue)
            .frame(width: 44, height: 44)
            .shadow(color: .blue.opacity(0.2), radius: 6, x: 0, y: 3)
            .scaleEffect(appears ? 1.0 : 0.0)
    }
}

#Preview {
    VStack(spacing: 16) {
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
                content: "I understand work stress can be challenging. Let's explore some wellness strategies that might help you manage this feeling. Would you like to try a quick breathing exercise?",
                agentModel: .llama4
            )
        )
    }
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.05), .teal.opacity(0.05)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
