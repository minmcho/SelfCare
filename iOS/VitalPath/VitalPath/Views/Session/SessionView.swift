//
//  SessionView.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  AI chat session with Llama 4 and Qwen 3.5 support
//

import SwiftUI
import SwiftData

struct SessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var messages: [MessageViewModel] = []
    @State private var isRecording = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                Divider()
                
                // Input Area
                inputArea
            }
            .navigationTitle(String(localized: "Wellness Coach"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { appState.triggerCrisisSupport() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text(String(localized: "Help"))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Agent", selection: $appState.selectedAgent) {
                        Text(AgentType.auto.displayName).tag(AgentType.auto)
                        Text(AgentType.llama4.displayName).tag(AgentType.llama4)
                        Text(AgentType.qwen35.displayName).tag(AgentType.qwen35)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            // Attachment button
            Button(action: showAttachmentPicker) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.teal)
            }
            
            // Text field
            TextField(String(localized: "Share how you're feeling..."), text: $messageText)
                .focused($isInputFocused)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            
            // Send/Voice button
            if messageText.isEmpty {
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .teal)
                }
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.title2)
                        .foregroundColor(.teal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userMessage = MessageViewModel(
            id: UUID(),
            role: .user,
            content: messageText,
            timestamp: Date(),
            agentModel: nil
        )
        
        messages.append(userMessage)
        messageText = ""
        
        Task {
            await sendMessageToAgent(content: userMessage.content)
        }
    }
    
    private func sendMessageToAgent(content: String) async {
        // Validate input for safety
        let validation = await SafetyValidator.shared.validateInput(
            content,
            languageCode: appState.currentLanguage.rawValue
        )
        
        if !validation.isValid {
            // Show error for medical claims
            return
        }
        
        if validation.requiresEscalation {
            // Trigger crisis support
            await MainActor.run {
                appState.showCrisisModal = true
                appState.crisisResources = validation.escalatedResources
            }
            return
        }
        
        // Send to GraphQL
        do {
            let response = try await GraphQLClient.shared.sendMessage(
                sessionId: UUID().uuidString,
                content: validation.sanitizedMessage ?? content,
                agentModel: mapAgentType(appState.selectedAgent),
                languageCode: appState.currentLanguage.rawValue
            )
            
            // Add assistant response
            // TODO: Parse response and add message
        } catch {
            // Handle error with fallback
        }
    }
    
    private func mapAgentType(_ type: AgentType) -> AgentModel {
        switch type {
        case .auto: return .auto
        case .llama4: return .llama4
        case .qwen35: return .qwen35
        }
    }
    
    private func showAttachmentPicker() {
        // Show photo/video picker
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        // Handle voice recording
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#Preview {
    SessionView()
        .environmentObject(AppState())
}
