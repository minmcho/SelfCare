//
//  LanguageSelectorView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Language selection with native script display
//

import SwiftUI

struct LanguageSelectorView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Menu {
            ForEach(AppState.AppLanguage.allCases) { language in
                Button(action: {
                    withAnimation {
                        appState.currentLanguage = language
                    }
                }) {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        if appState.currentLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(appState.currentLanguage.flag)
                .font(.title3)
        }
    }
}

#Preview {
    LanguageSelectorView()
        .environmentObject(AppState())
}
