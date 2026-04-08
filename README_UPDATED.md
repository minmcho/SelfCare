# VitalPath AI - Updated Architecture

## 🚀 Enhanced Tech Stack

### Backend
- **FastAPI**: Async Python web framework
- **Strawberry GraphQL**: Type-safe GraphQL API
- **Llama 4**: Advanced reasoning & wellness coaching (128K context)
- **Qwen 3.5 VL**: Multi-modal image/video analysis (256K context)
- **MCP (Model Context Protocol)**: Agent orchestration layer
- **ChromaDB**: Vector embeddings with HNSW indexing
- **Supabase**: PostgreSQL + Auth + Storage + Realtime
- **Redis**: Caching, rate limiting, session management
- **Celery**: Distributed task queue for async processing

### iOS Frontend
- **SwiftUI**: Modern declarative UI
- **SwiftData**: Local persistence
- **Async/Await**: Throughout codebase
- **Multi-language**: EN, MY, TH, ZH, JA, KO
- **Video Analysis**: Real-time wellness activity tracking

---

## 📁 Project Structure

```
/workspace
├── backend/
│   ├── app/
│   │   ├── agents/
│   │   │   └── mcp_agents.py          # Llama 4 + Qwen 3.5 MCP integration
│   │   ├── api/
│   │   │   ├── graphql_schema_mcp.py  # GraphQL schema with multi-modal types
│   │   │   └── graphql_resolvers_mcp.py # Full resolver implementation
│   │   ├── core/
│   │   │   ├── config.py              # Pydantic settings
│   │   │   ├── database.py            # Async SQLAlchemy
│   │   │   ├── redis_client.py        # Async Redis
│   │   │   ├── chromadb_client.py     # Vector store
│   │   │   └── celery_config.py       # Celery configuration
│   │   ├── models/
│   │   │   └── wellness_models.py     # SQLAlchemy ORM models
│   │   ├── services/
│   │   │   ├── safety_validator.py    # Safety boundary checks
│   │   │   └── wellness_ai_service.py # AI service with fallback chain
│   │   ├── tasks/
│   │   │   └── wellness_tasks.py      # Celery tasks
│   │   └── main.py                    # FastAPI application
│   ├── requirements.txt
│   └── tests/
│       └── test_safety_and_fallback.py
│
├── iOS/VitalPath/
│   └── VitalPath/
│       ├── VitalPathApp.swift         # Main app entry + modern UI
│       ├── Models/
│       │   ├── WellnessProfile.swift
│       │   ├── WellnessSession.swift
│       │   ├── WearableConnection.swift
│       │   └── MediaResource.swift
│       ├── Views/
│       │   ├── HomeView.swift
│       │   ├── SessionView.swift      # AI chat with agent selection
│       │   ├── VideoAnalysisView.swift # Multi-modal analysis
│       │   ├── ProfileView.swift
│       │   └── CrisisSupportView.swift
│       ├── ViewModels/
│       │   └── SessionViewModel.swift
│       ├── Services/
│       │   ├── GraphQLClient.swift
│       │   ├── WellnessAIService.swift
│       │   └── VideoAnalyzer.swift
│       └── Utils/
│           └── Localization.swift
│
└── README.md
```

---

## 🔑 Key Features

### 1. MCP Agent Orchestration
```python
# Automatic agent selection based on content
- Text conversations → Llama 4 (wellness coaching)
- Image/Video → Qwen 3.5 VL (multi-modal analysis)
- Crisis detection → Llama 4 (safety-first handling)
```

### 2. Multi-Modal Capabilities
- **Image Analysis**: Food recognition, exercise form checking
- **Video Analysis**: Activity tracking, movement assessment
- **Real-time Processing**: Frame-by-frame wellness scoring

### 3. Language Support
| Language | Code | Crisis Resources |
|----------|------|------------------|
| English | en | 988 Lifeline |
| Myanmar | my | +95-1-234-567 |
| Thai | th | 1323 Hotline |
| Chinese | zh | 400-161-9995 |
| Japanese | ja | 0120-783-556 |
| Korean | ko | 109 Hotline |

### 4. Safety First
- Input validation before AI processing
- Output validation before user display
- Immediate crisis escalation
- Wellness boundary enforcement

---

## 🚀 Quick Start

### Backend Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Start Redis
redis-server

# Start Celery workers
celery -A app.core.celery_config worker --loglevel=info --concurrency=4

# Start FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### GraphQL Endpoint
- HTTP: `POST http://localhost:8000/graphql`
- WebSocket: `WS http://localhost:8000/graphql`
- Health: `GET http://localhost:8000/health`

### iOS App Setup

```bash
cd iOS/VitalPath

# Open in Xcode 16+
open VitalPath.xcodeproj

# Run on simulator or device
# Requires iOS 17.0+
```

---

## 📡 GraphQL Operations

### Create Profile
```graphql
mutation CreateProfile($input: CreateProfileInput!) {
  createWellnessProfile(input: $input) {
    id
    name
    preferredLanguage
  }
}
```

### Send Message (with agent selection)
```graphql
mutation SendMessage($input: SendMessageInput!) {
  sendMessage(input: $input) {
    id
    role
    content
    agentModel
    crisisEscalated
  }
}
```

### Video Analysis
```graphql
mutation AnalyzeVideo($input: UploadVideoInput!) {
  uploadVideoForAnalysis(input: $input) {
    sessionId
    analysisSummary
    detectedActivities
    wellnessScore
    language
  }
}
```

### Get Crisis Resources
```graphql
query CrisisResources($language: String!) {
  crisisResources(language: $language) {
    title
    description
    phone
    website
    available24_7
  }
}
```

---

## 🔄 Celery Tasks

### Async Processing
```python
# Process video analysis asynchronously
@celery_app.task(bind=True, max_retries=3)
def process_video_analysis(self, video_url, session_id):
    try:
        result = qwen_agent.analyze_video(video_url)
        save_to_database(session_id, result)
        return result
    except Exception as exc:
        raise self.retry(exc=exc, countdown=60)
```

### Scheduled Tasks
```python
# Daily wellness check-ins
@celery_app.task
def send_daily_checkins():
    profiles = get_all_active_profiles()
    for profile in profiles:
        send_wellness_notification(profile)
```

---

## 🛡️ Safety Architecture

### Input Validation Flow
```
User Input → SafetyValidator → [CRISIS?] → Escalate
                              ↓ [SAFE]
                         Anonymize → MCP Agent → Output Validation → Response
```

### Circuit Breaker States
```
CLOSED → Normal operation
   ↓ [failures > threshold]
OPEN → Fallback responses
   ↓ [timeout expires]
HALF_OPEN → Test request
   ↓ [success]
CLOSED
```

---

## 📊 Scalability Targets

| Metric | MVP | Scale |
|--------|-----|-------|
| MAU | 1,000 | 50,000 |
| P95 Latency | <100ms | <150ms |
| AI Workers | 2 | Auto-scale 10-50 |
| Vector DB | Single node | Read replicas |
| Budget | $100/mo | $500/mo |

---

## 🧪 Testing

```bash
# Run tests
pytest tests/ -v --cov=app

# Test safety validation
pytest tests/test_safety_and_fallback.py::test_crisis_detection

# Test fallback chain
pytest tests/test_safety_and_fallback.py::test_circuit_breaker
```

---

## 📝 Compliance Notes

✅ **Wellness Boundaries**
- No medical advice, diagnosis, or treatment claims
- Clear disclaimers on every screen
- Crisis resources in 6 languages

✅ **Privacy**
- No PHI logged or transmitted
- Input anonymization before AI calls
- Supabase RLS for data isolation

✅ **Accessibility**
- Dynamic Type support
- VoiceOver compatible
- WCAG color contrast compliant

---

## 🔮 Future Enhancements

1. **Wearable Integration**: Apple Health, Fitbit, Oura
2. **Group Sessions**: Multi-user wellness challenges
3. **Advanced Analytics**: Trend visualization, insights
4. **Offline Mode**: Local AI inference for basic features
5. **Additional Languages**: Vietnamese, Indonesian, Hindi
