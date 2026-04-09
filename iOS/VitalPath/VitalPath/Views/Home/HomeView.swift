//
//  HomeView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Modern home screen with quick actions and wellness tips
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WellnessProfile.updatedAt, order: .reverse) private var profiles: [WellnessProfile]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Sessions
                    recentSessionsSection
                    
                    // Wellness Tips
                    wellnessTipsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "VitalPath"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSelectorView()
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Welcome back"))
                .font(.title2)
                .foregroundColor(.secondary)
            
            if let profile = profiles.first {
                Text(profile.name)
                    .font(.title)
                    .fontWeight(.bold)
            } else {
                Text(String(localized: "Get Started"))
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // Wellness disclaimer - REQUIRED on every screen
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.teal)
                Text(String(localized: "Wellness support only. Not medical advice."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.teal.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Quick Actions"))
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(
                    icon: "message.fill",
                    title: String(localized: "Chat"),
                    color: .blue
                ) {
                    // Navigate to chat
                }
                
                QuickActionButton(
                    icon: "video.fill",
                    title: String(localized: "Video Analysis"),
                    color: .purple
                ) {
                    // Navigate to video
                }
                
                QuickActionButton(
                    icon: "heart.fill",
                    title: String(localized: "Check-in"),
                    color: .red
                ) {
                    // Mood check-in
                }
                
                QuickActionButton(
                    icon: "brain.head.profile",
                    title: String(localized: "Mindfulness"),
                    color: .green
                ) {
                    // Mindfulness exercise
                }
            }
        }
    }
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Recent Sessions"))
                .font(.headline)
            
            if profiles.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    message: String(localized: "No sessions yet"),
                    subtext: String(localized: "Start your first wellness conversation")
                )
            } else {
                ForEach(profiles.prefix(3)) { profile in
                    SessionCardView(profile: profile)
                }
            }
        }
    }
    
    private var wellnessTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Daily Wellness Tip"))
                .font(.headline)
            
            TipCardView(
                title: String(localized: "Stay Hydrated"),
                description: String(localized: "Drink 8 glasses of water daily for optimal wellness"),
                icon: "drop.fill"
            )
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
