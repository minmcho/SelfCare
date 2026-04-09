# 📱 VitalPath Xcode Project Setup Guide

## ✅ Project Generated Successfully!

The Xcode project file has been created at:
```
/workspace/iOS/VitalPath/VitalPath.xcodeproj
```

## 🚀 Quick Start

### Option 1: Open Directly (Recommended)
```bash
cd /workspace/iOS/VitalPath
open VitalPath.xcodeproj
```

### Option 2: From Finder
1. Navigate to `/workspace/iOS/VitalPath/`
2. Double-click `VitalPath.xcodeproj`

## ⚙️ Post-Open Configuration

### 1. Select Your Development Team
Once Xcode opens:
1. Click on the **VitalPath** project in the navigator (left sidebar)
2. Select the **VitalPath** target
3. Go to **Signing & Capabilities** tab
4. Select your **Team** from the dropdown (or add your Apple ID)

### 2. Verify Bundle Identifier
- Bundle ID: `com.vitalpath.ai`
- Change if needed for your organization

### 3. Configure Signing
- **Debug**: Automatic signing
- **Release**: Automatic signing (enable for App Store distribution)

## 📋 Project Structure

The project includes **21 Swift files** organized into:

```
VitalPath/
├── VitalPathApp.swift          # App entry point
├── Models/
│   ├── WellnessProfile.swift   # User profile model
│   ├── WellnessSession.swift   # Session tracking
│   └── WearableConnection.swift # Wearable integration
├── ViewModels/
│   └── MessageViewModel.swift  # Chat message state
├── Services/
│   ├── GraphQLClient.swift     # API client with retry logic
│   └── SafetyValidator.swift   # Safety boundary checks
├── Views/
│   ├── ContentView.swift       # Main tab view
│   ├── Home/
│   │   └── HomeView.swift      # Dashboard
│   ├── Session/
│   │   └── SessionView.swift   # Chat interface
│   ├── Video/
│   │   ├── VideoAnalysisView.swift
│   │   └── VideoPlaceholderViews.swift
│   ├── Profile/
│   │   └── ProfileView.swift   # User settings
│   └── Components/
│       ├── CrisisSupportView.swift
│       ├── EmptyStateView.swift
│       ├── LanguageSelectorView.swift
│       ├── MessageBubbleView.swift
│       ├── QuickActionButton.swift
│       ├── SessionCardView.swift
│       ├── TipCardView.swift
│       └── WearableRowView.swift
```

## 🔧 Build Settings

| Setting | Value |
|---------|-------|
| **Deployment Target** | iOS 17.0+ |
| **Swift Version** | 5.10 |
| **Bundle ID** | com.vitalpath.ai |
| **Development Team** | Your Team |
| **Code Sign Style** | Automatic |

## 🧪 Running the App

### Simulator
1. Select a simulator (iPhone 15 Pro recommended)
2. Press `Cmd + R` or click ▶️ Run

### Physical Device
1. Connect your iPhone/iPad via USB
2. Trust the device when prompted
3. Select your device from the scheme menu
4. Press `Cmd + R`

## 🔗 Backend Configuration

Before running, configure the backend URL in `GraphQLClient.swift`:

```swift
class GraphQLClient {
    static let shared = GraphQLClient(
        baseURL: "https://your-backend-url.com/graphql"
    )
    // ...
}
```

## 🌐 Localization

The app supports 6 languages:
- English (en-US)
- Myanmar (my-MM)
- Thai (th-TH)
- Chinese (zh-CN)
- Japanese (ja-JP)
- Korean (ko-KR)

## ⚠️ Important Notes

1. **First Build**: May take longer as Swift packages resolve
2. **Team Selection**: Required for running on physical devices
3. **Backend**: The app requires a running backend server (FastAPI + GraphQL)
4. **Privacy**: No user data is logged; all inputs are anonymized before AI calls

## 🛠 Troubleshooting

### "No Provisioning Profiles Found"
- Go to Xcode → Settings → Accounts
- Add your Apple ID
- Select your team in project settings

### "Module Not Found" Errors
- Clean build folder: `Shift + Cmd + K`
- Delete Derived Data: `~/Library/Developer/Xcode/DerivedData`
- Rebuild project

### Simulator Issues
- Reset simulator: Device → Erase All Content and Settings
- Try a different simulator version

## 📚 Next Steps

1. ✅ Open project in Xcode
2. ✅ Select development team
3. ✅ Configure backend URL
4. ✅ Build and run on simulator
5. ✅ Test wellness chat features
6. ✅ Verify safety validation
7. ✅ Test crisis escalation flow

---

**Generated**: Auto-generated Xcode project
**Version**: 1.0.0
**Platform**: iOS 17.0+
