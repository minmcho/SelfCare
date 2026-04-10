//
//  TipCardView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Glass-morphic wellness tip card with rich animations
//

import SwiftUI

struct TipCardView: View {
    let title: String
    let description: String
    let icon: String
    
    @State private var isHovering = false
    @State private var appears = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon container with animated gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.teal, .green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .teal.opacity(0.4), radius: isHovering ? 12 : 8, x: 0, y: isHovering ? 6 : 4)
                
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isHovering ? 1.15 : 1.0)
                    .rotationEffect(.degrees(isHovering ? 10 : 0))
            }
            .frame(width: 60, height: 60)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .scaleEffect(isHovering ? 1.02 : 1.0)
                
                Text(description)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Decorative chevron with animation
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.teal.opacity(0.6))
                .opacity(isHovering ? 1 : 0.5)
                .offset(x: isHovering ? 4 : 0)
        }
        .padding(18)
        .background(
            Group {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.8),
                                Color(.systemBackground).opacity(0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Glass material overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
                
                // Gradient border
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .teal.opacity(0.4),
                                .green.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .shadow(color: .teal.opacity(0.15), radius: isHovering ? 16 : 10, x: 0, y: isHovering ? 10 : 5)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: isHovering)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0).delay(0.1)) {
                appears = true
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovering = hovering
            }
        }
        .offset(y: appears ? 0 : 20)
        .opacity(appears ? 1 : 0)
    }
}

#Preview {
    TipCardView(
        title: "Stay Hydrated",
        description: "Drink 8 glasses of water daily for optimal wellness",
        icon: "drop.fill"
    )
    .padding()
    .background(
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.1), .green.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
