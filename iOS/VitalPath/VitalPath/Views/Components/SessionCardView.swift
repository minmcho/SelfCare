//
//  SessionCardView.swift
//  VitalPath - AI Wellness Coaching Platform
//

import SwiftUI
import SwiftData

struct SessionCardView: View {
    let profile: WellnessProfile
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.teal.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .foregroundColor(.teal)
                        .fontWeight(.bold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(profile.activityLevel.displayName, systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !profile.wellnessGoals.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(profile.wellnessGoals.first ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
}
