# VitalPath AI - iOS Wellness Coaching App

A production-ready iOS wellness coaching application with AI-powered guidance, multi-modal analysis, and comprehensive safety features.

## 📱 Features

### Core Capabilities
- **AI Chat Sessions** - Powered by Llama 4 (text) and Qwen 3.5 VL (multi-modal)
- **Video Analysis** - Real-time activity analysis using Qwen 3.5 Vision-Language model
- **Wearable Integration** - Apple Watch, Fitbit, Garmin, Oura, WHOOP support
- **Multi-language Support** - English, Myanmar (မြန်မာ), Thai (ไทย), Chinese (中文), Japanese (日本語), Korean (한국어)
- **Crisis Support** - Immediate escalation with localized resources

### Safety First
- Runtime safety validation for all AI interactions
- Medical claim detection and blocking
- Crisis keyword detection with immediate resource escalation
- Self-harm indicator monitoring
- PII/PHI anonymization before AI processing

### Modern iOS Architecture
- SwiftUI with SwiftData for local persistence
- Async/await throughout (no completion handlers)
- @Observable pattern (iOS 17+)
- Modular feature-based architecture
- Full accessibility support (Dynamic Type, VoiceOver)

## 🏗️ Project Structure

```
iOS/VitalPath/
├── VitalPath/
│   ├── Models/
│   │   ├── WellnessProfile.swift      # User profile with SwiftData
│   │   ├── WellnessSession.swift      # Session tracking with safety metadata
│   │   └── WearableConnection.swift   # Wearable integration models
│   ├── Services/
│   │   ├── GraphQLClient.swift        # Apollo iOS client with auth/retry
│   │   └── SafetyValidator.swift      # Runtime safety validation
│   ├── ViewModels/
│   │   └── MessageViewModel.swift     # Chat message view models
│   ├── Views/
│   │   ├── ContentView.swift          # Main tab navigation
│   │   ├── Home/
│   │   │   └── HomeView.swift         # Dashboard with quick actions
│   │   ├── Session/
│   │   │   └── SessionView.swift      # AI chat interface
│   │   ├── Video/
│   │   │   ├── VideoAnalysisView.swift    # Video upload & analysis
│   │   │   └── VideoPlaceholderViews.swift # Preview & result views
│   │   ├── Profile/
│   │   │   └── ProfileView.swift      # User settings & wearables
│   │   └── Components/
│   │       ├── CrisisSupportView.swift    # Crisis modal (REQUIRED)
│   │       ├── LanguageSelectorView.swift # 6-language picker
│   │       ├── MessageBubbleView.swift    # Chat bubbles
│   │       ├── QuickActionButton.swift    # Home action buttons
│   │       ├── EmptyStateView.swift       # Empty state placeholders
│   │       ├── TipCardView.swift          # Wellness tip cards
│   │       ├── SessionCardView.swift      # Recent session cards
│   │       └── WearableRowView.swift      # Wearable connection rows
│   └── VitalPathApp.swift             # App entry point
└── README.md
```

## 🚀 Getting Started

### Requirements
- Xcode 16+
- iOS 17.0+ deployment target
- Swift 5.10+

### Installation

1. Open the project in Xcode:
```bash
open iOS/VitalPath/VitalPath.xcodeproj
```

2. Install Apollo iOS dependencies (if using CocoaPods):
```bash
cd iOS/VitalPath
pod install
```

3. Configure the GraphQL endpoint in `GraphQLClient.swift`:
```swift
GraphQLClient.shared.configure(
    baseURL: "https://your-api.vitalpath.ai/graphql",
    authToken: userToken
)
```

4. Build and run on iOS Simulator or device

## 🔐 Safety & Compliance

### Wellness Boundaries
Every screen displays the required wellness disclaimer:
> "Wellness support only. Not medical advice."

### Crisis Escalation
When crisis keywords are detected:
1. Immediate modal display with local resources
2. One-tap calling to crisis hotlines
3. Resources available in all 6 supported languages

### Privacy
- All inputs anonymized before AI processing
- No PHI logged or transmitted
- SHA256 hashing for sensitive data
- Supabase RLS for data isolation

## 🌍 Localization

Supported languages with native scripts:
| Code | Language | Native Name |
|------|----------|-------------|
| en | English | English |
| my | Myanmar | မြန်မာ |
| th | Thai | ไทย |
| zh | Chinese | 中文 |
| ja | Japanese | 日本語 |
| ko | Korean | 한국어 |

## 🤖 AI Agents

| Agent | Capability | Context |
|-------|-----------|---------|
| Auto | Best agent selection | - |
| Llama 4 | Advanced text reasoning | 128K tokens |
| Qwen 3.5 VL | Multi-modal (video/images) | 256K tokens |

## 📡 Backend Integration

The app connects to a FastAPI + GraphQL backend with:
- **FastAPI** - High-performance async API
- **Strawberry GraphQL** - Schema-first GraphQL with WebSocket subscriptions
- **ChromaDB** - Vector similarity search for wellness content
- **Supabase** - PostgreSQL database with Row Level Security
- **Redis** - Caching and rate limiting
- **Celery** - Distributed task queue for AI processing

## 🎨 UI/UX Highlights

- **Modern Design** - SF Symbols, gradients, shadows
- **Accessibility** - Dynamic Type, VoiceOver labels, color contrast
- **Responsive** - Adapts to all iPhone sizes
- **Dark Mode Ready** - Semantic colors throughout
- **Haptic Feedback** - Subtle vibrations for key interactions

## 🧪 Testing

Run unit tests for safety validation:
```bash
xcodebuild test \
  -scheme VitalPath \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📄 License

Proprietary - VitalPath AI

---

**Built with ❤️ for wellness seekers worldwide**
