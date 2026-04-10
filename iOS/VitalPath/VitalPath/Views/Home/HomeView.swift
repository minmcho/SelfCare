//
//  HomeView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Modern home screen with glass-morphic UI and rich animations
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WellnessProfile.updatedAt, order: .reverse) private var profiles: [WellnessProfile]
    
    @State private var appears = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Sessions
                    recentSessionsSection
                    
                    // Wellness Tips
                    wellnessTipsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(String(localized: "VitalPath"))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSelectorView()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0)) {
                appears = true
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Welcome back"))
                .font(.title3.weight(.medium))
                .foregroundColor(.secondary)
                .offset(y: appears ? 0 : -10)
                .opacity(appears ? 1 : 0)
            
            if let profile = profiles.first {
                Text(profile.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.teal, .green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: appears ? 0 : -10)
                    .opacity(appears ? 1 : 0)
            } else {
                Text(String(localized: "Get Started"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.teal, .green]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: appears ? 0 : -10)
                    .opacity(appears ? 1 : 0)
            }
            
            // Wellness disclaimer - REQUIRED on every screen
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.teal)
                    .font(.body)
                
                Text(String(localized: "Wellness support only. Not medical advice."))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.teal.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .teal.opacity(0.08), radius: 6, x: 0, y: 3)
            .offset(y: appears ? 0 : -10)
            .opacity(appears ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4).delay(0.05), value: appears)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Quick Actions"))
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Recent Sessions"))
                .font(.headline.weight(.semibold))
            
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
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Daily Wellness Tip"))
                .font(.headline.weight(.semibold))
            
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
