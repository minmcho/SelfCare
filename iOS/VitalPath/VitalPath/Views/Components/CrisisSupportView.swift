//
//  CrisisSupportView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Crisis support modal with immediate resources
//  Displays in user's selected language
//

import SwiftUI

struct CrisisSupportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text(String(localized: "You're Not Alone"))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(String(localized: "Help is available 24/7"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Crisis Resources
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "Immediate Support"))
                        .font(.headline)
                    
                    ForEach(appState.crisisResources) { resource in
                        CrisisResourceCard(resource: resource)
                    }
                    
                    if appState.crisisResources.isEmpty {
                        // Default English resources
                        let defaultResources = SafetyValidator.shared.getCrisisResources(for: "en")
                        ForEach(defaultResources) { resource in
                            CrisisResourceCard(resource: resource)
                        }
                    }
                }
                
                Spacer()
                
                // Wellness Reminder
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.teal)
                        Text(String(localized: "This is not medical advice"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(localized: "For medical emergencies, call your local emergency number immediately."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.teal.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle(String(localized: "Crisis Support"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CrisisResourceCard: View {
    let resource: CrisisResource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(resource.title)
                        .font(.headline)
                    Text(resource.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if resource.available24_7 {
                    Label(String(localized: "24/7"), systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 16) {
                Button(action: callResource) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text(String(localized: "Call"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: visitWebsite) {
                    HStack {
                        Image(systemName: "globe")
                        Text(String(localized: "Visit"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func callResource() {
        if let url = URL(string: "tel:\(resource.phone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func visitWebsite() {
        if let url = URL(string: resource.website) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    CrisisSupportView()
        .environmentObject(AppState())
}
