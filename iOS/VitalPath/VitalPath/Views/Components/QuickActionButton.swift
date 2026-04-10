//
//  QuickActionButton.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Modern glass-morphic action button with rich animations
//

import SwiftUI

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon container with glass effect
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.8),
                                    color
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: color.opacity(0.3), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                .frame(width: 60, height: 60)
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: isPressed)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .scaleEffect(isHovering ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.7),
                                Color(.systemBackground).opacity(0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color.opacity(0.3),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.5)
                    )
                    .shadow(color: color.opacity(0.1), radius: isHovering ? 12 : 6, x: 0, y: isHovering ? 8 : 3)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    QuickActionButton(
        icon: "message.fill",
        title: "Chat",
        color: .blue
    ) {}
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
