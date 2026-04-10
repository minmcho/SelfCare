//
//  SessionCardView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Glass-morphic session card with rich animations
//

import SwiftUI
import SwiftData

struct SessionCardView: View {
    let profile: WellnessProfile
    
    @State private var isHovering = false
    @State private var appears = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar with animated gradient ring
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.teal.opacity(0.2), .green.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [.teal, .green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 54, height: 54)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                
                Text(String(profile.name.prefix(1)).uppercased())
                    .foregroundColor(.teal)
                    .fontWeight(.bold)
                    .font(.title3)
                    .scaleEffect(isHovering ? 1.15 : 1.0)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .scaleEffect(isHovering ? 1.02 : 1.0)
                
                HStack(spacing: 8) {
                    Label(profile.activityLevel.displayName, systemImage: "figure.walk")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    if !profile.wellnessGoals.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(profile.wellnessGoals.first ?? "")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Animated chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.teal)
                .font(.caption.weight(.semibold))
                .opacity(isHovering ? 1 : 0.5)
                .offset(x: isHovering ? 6 : 0)
        }
        .padding(16)
        .background(
            Group {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.85),
                                Color(.systemBackground).opacity(0.65)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Glass material overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
                
                // Gradient border
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .teal.opacity(0.35),
                                .green.opacity(0.15),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .teal.opacity(0.12), radius: isHovering ? 14 : 8, x: 0, y: isHovering ? 8 : 4)
        .scaleEffect(isHovering ? 1.025 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0).delay(0.05)) {
                appears = true
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isHovering = hovering
            }
        }
        .offset(y: appears ? 0 : 15)
        .opacity(appears ? 1 : 0)
    }
}

#Preview {
    SessionCardView(
        profile: WellnessProfile(
            name: "John Doe",
            wellnessGoals: ["Improve Sleep"],
            activityLevel: .moderate
        )
    )
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.08), .teal.opacity(0.08)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
