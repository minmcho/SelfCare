//
//  EmptyStateView.swift
//  VitalPath - AI Wellness Coaching Platform
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let message: String
    let subtext: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtext)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    EmptyStateView(
        icon: "bubble.left.and.bubble.right",
        message: "No sessions yet",
        subtext: "Start your first wellness conversation"
    )
    .padding()
}
