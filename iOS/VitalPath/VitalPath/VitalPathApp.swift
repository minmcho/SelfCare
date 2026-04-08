//
//  VitalPathApp.swift
//  VitalPath - AI Wellness Coaching Platform
//  Modern iOS UI with SwiftData, Async/Await, and Multi-modal Support
//

import SwiftUI
import SwiftData

@main
struct VitalPathApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(for: [
                    WellnessProfile.self,
                    WellnessSession.self,
                    WearableConnection.self,
                    Message.self,
                    MediaResource.self
                ])
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - App State Manager
@MainActor
class AppState: ObservableObject {
    @Published var currentLanguage: AppLanguage = .english
    @Published var isAuthenticated = false
    @Published var showCrisisModal = false
    @Published var crisisResources: [CrisisResource] = []
    
    enum AppLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case myanmar = "my"
        case thai = "th"
        case chinese = "zh"
        case japanese = "ja"
        case korean = "ko"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .myanmar: return "မြန်မာ"
            case .thai: return "ไทย"
            case .chinese: return "中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            }
        }
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .myanmar: return "🇲🇲"
            case .thai: return "🇹🇭"
            case .chinese: return "🇨🇳"
            case .japanese: return "🇯🇵"
            case .korean: return "🇰🇷"
            }
        }
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        // Update localization
    }
    
    func triggerCrisisSupport() {
        showCrisisModal = true
        loadCrisisResources()
    }
    
    private func loadCrisisResources() {
        // Load from GraphQL
        crisisResources = [
            CrisisResource(
                title: String(localized: "Emergency Support"),
                description: String(localized: "24/7 confidential help"),
                phone: "988",
                website: "https://988lifeline.org",
                available24_7: true
            )
        ]
    }
}

// MARK: - Content View
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
        .sheet(isPresented: $appState.showCrisisModal) {
            CrisisSupportView()
        }
    }
}

// MARK: - Home View
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

// MARK: - Session View (AI Chat)
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
                    Picker("Agent", selection: .constant(AgentType.auto)) {
                        Text("Auto").tag(AgentType.auto)
                        Text("Llama 4").tag(AgentType.llama4)
                        Text("Qwen 3.5").tag(AgentType.qwen35)
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
        
        // Call GraphQL mutation
        Task {
            await sendMessageToAgent(content: userMessage.content)
        }
    }
    
    private func sendMessageToAgent(content: String) async {
        // GraphQL call to send_message mutation
        // Handle response and add assistant message
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

// MARK: - Video Analysis View
struct VideoAnalysisView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedVideo: URL?
    @State private var isAnalyzing = false
    @State private var analysisResult: VideoAnalysisResult?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if selectedVideo == nil {
                    VideoUploadPlaceholderView(onSelect: { url in
                        selectedVideo = url
                    })
                } else {
                    VideoPreviewView(videoURL: selectedVideo!)
                    
                    if isAnalyzing {
                        ProgressView("Analyzing your activity...")
                            .padding()
                    } else if let result = analysisResult {
                        AnalysisResultView(result: result)
                    }
                    
                    Button(action: analyzeVideo) {
                        Text(isAnalyzing ? String(localized: "Analyzing...") : String(localized: "Analyze Activity"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isAnalyzing ? Color.gray : Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isAnalyzing || selectedVideo == nil)
                }
            }
            .padding()
            .navigationTitle(String(localized: "Video Analysis"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func analyzeVideo() {
        guard let videoURL = selectedVideo else { return }
        
        isAnalyzing = true
        
        Task {
            // Call GraphQL mutation: upload_video_for_analysis
            // Qwen 3.5 VL will process the video
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Simulate
            
            analysisResult = VideoAnalysisResult(
                sessionId: UUID().uuidString,
                analysisSummary: String(localized: "Great walking activity detected!"),
                detectedActivities: [String(localized: "Walking"), String(localized: "Cardio")],
                wellnessScore: 0.87,
                language: appState.currentLanguage.rawValue,
                frameCount: 30,
                durationSeconds: 15.0
            )
            
            isAnalyzing = false
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \WellnessProfile.updatedAt, order: .reverse) private var profiles: [WellnessProfile]
    
    var body: some View {
        NavigationStack {
            List {
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
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text(String(localized: "Preferences"))) {
                    // Language selector
                    HStack {
                        Text(String(localized: "Language"))
                        Spacer()
                        Menu(appState.currentLanguage.displayName) {
                            ForEach(AppLanguage.allCases) { language in
                                Button(action: {
                                    appState.setLanguage(language)
                                }) {
                                    HStack {
                                        Text(language.flag)
                                        Text(language.displayName)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Wellness goals
                    NavigationLink(destination: WellnessGoalsView()) {
                        HStack {
                            Text(String(localized: "Wellness Goals"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Wearable connections
                    NavigationLink(destination: WearablesView()) {
                        HStack {
                            Text(String(localized: "Connected Devices"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text(String(localized: "Safety"))) {
                    // Wellness disclaimer
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.teal)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Wellness Disclaimer"))
                                .font(.headline)
                            
                            Text(String(localized: "VitalPath provides wellness support only. We do not provide medical advice, diagnosis, or treatment. Always consult healthcare professionals for medical concerns."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(role: .destructive) {
                        // Sign out
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(String(localized: "Sign Out"))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Profile"))
        }
    }
}

// MARK: - Supporting Views & Models

enum AgentType {
    case auto, llama4, qwen35
}

struct MessageViewModel: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let agentModel: String?
    
    enum MessageRole {
        case user, assistant, system
    }
}

struct CrisisResource: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let phone: String
    let website: String
    let available24_7: Bool
}

struct VideoAnalysisResult: Identifiable {
    let id = UUID()
    let sessionId: String
    let analysisSummary: String
    let detectedActivities: [String]
    let wellnessScore: Double
    let language: String
    let frameCount: Int
    let durationSeconds: Double
}

// Placeholder views for brevity
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct MessageBubbleView: View {
    let message: MessageViewModel
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                UserMessageBubble(content: message.content)
            } else {
                AssistantMessageBubble(content: message.content, agentModel: message.agentModel)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct UserMessageBubble: View {
    let content: String
    
    var body: some View {
        Text(content)
            .padding()
            .background(Color.teal)
            .foregroundColor(.white)
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
    }
}

struct AssistantMessageBubble: View {
    let content: String
    let agentModel: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            
            if let model = agentModel {
                Text(model)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct VideoUploadPlaceholderView: View {
    let onSelect: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            Text(String(localized: "Record or Upload Video"))
                .font(.headline)
            
            Text(String(localized: "Analyze your wellness activities with AI"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button(action: { /* Record */ }) {
                    VStack {
                        Image(systemName: "record.circle")
                            .font(.title2)
                        Text(String(localized: "Record"))
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }
                
                Button(action: { /* Upload */ }) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text(String(localized: "Upload"))
                            .font(.caption)
                    }
                    .foregroundColor(.teal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct VideoPreviewView: View {
    let videoURL: URL
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.2))
            .frame(height: 250)
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            )
    }
}

struct AnalysisResultView: View {
    let result: VideoAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(String(localized: "Analysis Complete"))
                    .font(.headline)
            }
            
            Text(result.analysisSummary)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Detected Activities:"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                FlowLayout(items: result.detectedActivities) { activity in
                    Text(activity)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.2))
                        .cornerRadius(16)
                }
            }
            
            HStack {
                Text(String(localized: "Wellness Score:"))
                    .font(.subheadline)
                
                Gauge(value: result.wellnessScore, in: 0...1) {
                    Text(String(format: "%.0f%%", result.wellnessScore * 100))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct FlowLayout<ItemView, Data>: View where ItemView: View, Data: RandomAccessCollection {
    let items: Data
    let itemContent: (Data.Element) -> ItemView
    
    init(items: Data, @ViewBuilder itemContent: @escaping (Data.Element) -> ItemView) {
        self.items = items
        self.itemContent = itemContent
    }
    
    var body: some View {
        FlowLayoutPanel(items: items, itemContent: itemContent)
    }
}

struct FlowLayoutPanel<ItemView, Data>: UIViewRepresentable where ItemView: View, Data: RandomAccessCollection {
    let items: Data
    let itemContent: (Data.Element) -> ItemView
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Implementation for flow layout
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

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
            
            Text(subtext)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct TipCardView: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.orange)
                .frame(width: 50, height: 50)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct SessionCardView: View {
    let profile: WellnessProfile
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.teal)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                Text(String(localized: "Last active: ") + formatDate(profile.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct LanguageSelectorView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button(action: {
                    appState.setLanguage(language)
                }) {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            Text(appState.currentLanguage.flag)
                .font(.title2)
        }
    }
}

struct CrisisSupportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Urgent notice
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Need Immediate Help?"))
                                .font(.headline)
                            
                            Text(String(localized: "If you're in crisis, please reach out to these resources right now."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Resources
                    ForEach(appState.crisisResources) { resource in
                        CrisisResourceCard(resource: resource)
                    }
                    
                    // Additional info
                    Text(String(localized: "These services are confidential and available 24/7."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
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
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                
                Text(resource.title)
                    .font(.headline)
            }
            
            Text(resource.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Link(destination: URL(string: "tel:\(resource.phone)")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                        Text(resource.phone)
                    }
                    .fontWeight(.semibold)
                }
                
                if resource.available24_7 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text(String(localized: "24/7"))
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
                
                Spacer()
            }
            
            Link(destination: URL(string: resource.website)!) {
                Text(String(localized: "Visit Website"))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// Placeholder views for navigation destinations
struct WellnessGoalsView: View {
    var body: some View {
        Text("Wellness Goals")
    }
}

struct WearablesView: View {
    var body: some View {
        Text("Wearables")
    }
}

struct ProfileSettingsView: View {
    var body: some View {
        Text("Settings")
    }
}
