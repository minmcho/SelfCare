//
//  ContentView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Main tab-based navigation with modern glass-morphic UI
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(String(localized: "Home"), systemImage: "house.fill")
                }
            
            SessionView()
                .tabItem {
                    Label(String(localized: "Sessions"), systemImage: "bubble.left.and.bubble.right.fill")
                }
            
            VideoAnalysisView()
                .tabItem {
                    Label(String(localized: "Video Analysis"), systemImage: "video.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label(String(localized: "Profile"), systemImage: "person.crop.circle.fill")
                }
        }
        .accentColor(.teal)
        .tint(.teal)
        .sheet(isPresented: $appState.showCrisisModal) {
            CrisisSupportView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
