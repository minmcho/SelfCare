# VitalPath AI - Wellness Coaching Platform

A production-ready iOS wellness coaching app with a resilient, scalable backend.

## 🎯 Product Overview

**Core Value**: AI-powered wellness guidance for preventive health (NOT medical advice)  
**Target Users**: Health-conscious adults 25-55 seeking lifestyle support  
**Key Differentiator**: Safety-first AI with explicit wellness boundaries + wearable integration

### Critical Compliance Boundary

| ✅ ALLOWED | ❌ PROHIBITED |
|------------|---------------|
| Support healthy habits | Treat, Diagnose, Cure |
| Promote wellness | Prevent disease |
| Personalized lifestyle guidance | Medical claims |

**Required**: Wellness disclaimer on every screen + crisis resource escalation

---

## 📁 Project Structure

```
VitalPathAI/
├── iOS/VitalPath/
│   └── Sources/
│       ├── Models/
│       │   ├── WellnessProfile.swift      # User wellness profile (SwiftData)
│       │   ├── WellnessSession.swift      # AI coaching sessions
│       │   └── WearableConnection.swift   # Wearable device integration
│       ├── Network/
│       │   ├── APIError.swift             # Custom error types with retry logic
│       │   └── GraphQLClient.swift        # Apollo iOS client with auth
│       ├── Services/
│       │   └── WellnessAIService.swift    # AI service with fallback chain
│       ├── Safety/
│       │   └── SafetyValidator.swift      # Runtime safety validation
│       └── Features/
│           ├── Nutrition/
│           ├── Habits/
│           └── Mindfulness/
├── backend/
│   └── supabase/
│       ├── functions/
│       │   └── ai-wellness-session/
│       │       └── index.ts               # Edge function for AI sessions
│       └── sql/
│           └── pgvector_setup.sql         # Database schema + vector search
└── tests/
    └── SafetyValidatorTests.swift         # Unit tests for safety logic
```

---

## 🛠️ Tech Stack

### iOS Frontend
- **SwiftUI 18** with iOS 17+ deployment target
- **SwiftData** for local persistence
- **Async/await** throughout (no completion handlers)
- **@Observable** for dependency injection
- **Apollo iOS** for GraphQL

### Backend
- **Supabase**: PostgreSQL + Auth + Realtime + Edge Functions
- **GraphQL**: Hasura/Apollo Server
- **pgvector**: Vector similarity search for semantic caching
- **CrewAI/OpenClaw**: AI orchestration on Cloud Run/Fly.io
- **Redis (Upstash)**: Rate limiting + session cache
- **Sentry**: Error tracking

---

## 🚀 Key Features

### 1. Safety-First AI (`SafetyValidator.swift`)
- Runtime validation against medical claims
- Crisis keyword detection with immediate resource escalation
- User-configurable excluded topics
- PHI redaction before AI processing

### 2. Resilient Service Architecture (`WellnessAIService.swift`)
- **Fallback Chain**:
  1. Primary AI (CrewAI/OpenClaw)
  2. Fallback AI (simplified model)
  3. Semantic cache (pgvector)
  4. Local safe responses
- Circuit breaker pattern
- Automatic retry with exponential backoff

### 3. Privacy-Preserving Design
- Input anonymization before network calls
- No PHI in logs or storage
- Row-level security (RLS) in database
- Anonymized user IDs for backend sync

### 4. Scalable Backend (`pgvector_setup.sql`)
- HNSW indexing for O(log n) vector search
- Connection pooling ready
- Auto-scaling AI workers
- Read replica support

---

## 📦 SwiftData Models

### WellnessProfile
```swift
@Model
class WellnessProfile {
    var id: String                    // Unique identifier
    var anonymizedUserId: String      // Hashed auth ID
    var wellnessGoals: [String]       // User goals
    var activityLevel: ActivityLevel  // Lifestyle classification
    var excludedTopics: [String]      // Topics to avoid
    var sessions: [WellnessSession]   // Relationship
}
```

### WellnessSession
```swift
@Model
class WellnessSession {
    var userInput: String             // Anonymized input
    var aiResponse: String            // Validated response
    var safetyValidated: Bool         // Safety check status
    var crisisKeywordsDetected: [String]
    var isFallbackResponse: Bool      // Fallback chain tracking
    var aiProvider: AIProvider        // Service used
}
```

### WearableConnection
```swift
@Model
class WearableConnection {
    var deviceType: WearableDeviceType
    var isConnected: Bool
    var stepsPermission: Bool
    var consecutiveSyncFailures: Int  // Circuit breaker
}
```

---

## 🔒 Safety Validation

### Prohibited Medical Claims
- Diagnosis/treatment/cure claims
- Disease prevention claims
- Medical condition management
- Symptom treatment claims

### Crisis Keywords (Triggers Escalation)
- Self-harm indicators
- Severe depression signals
- Violence indicators
- Emergency situations

### Crisis Resources by Locale
| Locale | Hotline | Website |
|--------|---------|---------|
| US | 988 | 988lifeline.org |
| UK | 116 123 | samaritans.org |
| Myanmar | - | befrienders.org |
| Thailand | 1323 | thailifeline.org |
| China | 400-161-9995 | beijinglifeline.org.cn |
| Japan | 0120-783-556 | inochinowa.or.jp |
| Korea | 109 | selfharm.or.kr |

---

## 🧪 Testing

Run unit tests:
```bash
xcodebuild test \
  -scheme VitalPath \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Key test coverage:
- Medical claim detection
- Crisis keyword recognition
- PHI sanitization
- Fallback chain activation
- Circuit breaker behavior

---

## 📈 Scalability Targets

| Metric | MVP | Scale |
|--------|-----|-------|
| MAU | 1,000 | 50,000 |
| P95 Latency | <100ms | <150ms |
| AI Workers | 1 | Auto-scaled |
| Database | Single | Read replicas |
| Budget Alert | $100/mo | $500/mo increments |

---

## 🔧 Setup Instructions

### 1. Database Setup
```sql
-- Run in Supabase SQL Editor
\i backend/supabase/sql/pgvector_setup.sql
```

### 2. Environment Variables
```bash
# Supabase
SUPABASE_URL=your-project-url
SUPABASE_SERVICE_ROLE_KEY=your-service-key

# AI Services
AI_SERVICE_URL=https://ai.your-app.com
AI_SERVICE_API_KEY=your-api-key
FALLBACK_AI_URL=https://fallback.your-app.com
```

### 3. Deploy Edge Function
```bash
supabase functions deploy ai-wellness-session
```

### 4. iOS Configuration
1. Add Supabase URL to `Info.plist`
2. Configure Apollo code generation
3. Set up entitlements for HealthKit (if using wearables)

---

## 📝 License

Proprietary - VitalPath AI © 2024

---

## ⚠️ Important Disclaimers

**This application provides wellness guidance only and does not:**
- Diagnose medical conditions
- Treat diseases
- Prescribe medications
- Replace professional medical advice

**Users should:**
- Consult healthcare providers for medical concerns
- Call emergency services for crises
- Use this app as a supplement to, not replacement for, professional care
