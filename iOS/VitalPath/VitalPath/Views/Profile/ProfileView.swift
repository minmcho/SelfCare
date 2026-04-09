//
//  ProfileView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  User profile with settings and wearable connections
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \WellnessProfile.updatedAt, order: .reverse) private var profiles: [WellnessProfile]
    @Query(sort: \WearableConnection.createdAt, order: .reverse) private var wearables: [WearableConnection]
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section(header: Text(String(localized: "Account"))) {
                    if let profile = profiles.first {
                        HStack {
                            Circle()
                                .fill(Color.teal)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(String(profile.name.prefix(1)).uppercased())
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Language Settings
                Section(header: Text(String(localized: "Language"))) {
                    Picker(String(localized: "Language"), selection: $appState.currentLanguage) {
                        ForEach(AppState.AppLanguage.allCases) { language in
                            Text("\(language.flag) \(language.displayName)").tag(language)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // AI Agent Preference
                Section(header: Text(String(localized: "AI Preferences"))) {
                    Picker(String(localized: "Default Agent"), selection: $appState.selectedAgent) {
                        ForEach(AppState.AIAgent.allCases) { agent in
                            VStack(alignment: .leading) {
                                Text(agent.displayName)
                                Text(agent.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(agent)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.teal)
                        VStack(alignment: .leading) {
                            Text(String(localized: "Safety First"))
                                .font(.subheadline)
                            Text(String(localized: "All messages are validated for wellness boundaries"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Wearable Connections
                Section(header: Text(String(localized: "Wearables"))) {
                    ForEach(wearables) { wearable in
                        WearableRowView(wearable: wearable)
                    }
                    
                    Button(action: addWearable) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.teal)
                            Text(String(localized: "Connect New Device"))
                        }
                    }
                }
                
                // Wellness Disclaimer
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(String(localized: "Wellness Disclaimer"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text(String(localized: "VitalPath provides wellness guidance only. It does not diagnose, treat, cure, or prevent any disease. Always consult healthcare professionals for medical advice."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // App Info
                Section(header: Text(String(localized: "About"))) {
                    HStack {
                        Text(String(localized: "Version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(String(localized: "Privacy Policy"), destination: URL(string: "https://vitalpath.ai/privacy")!)
                    Link(String(localized: "Terms of Service"), destination: URL(string: "https://vitalpath.ai/terms")!)
                }
                
                // Sign Out
                Section {
                    Button(role: .destructive) {
                        signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Sign Out"))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Profile"))
        }
    }
    
    private func addWearable() {
        // Show wearable connection sheet
    }
    
    private func signOut() {
        // Handle sign out
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
