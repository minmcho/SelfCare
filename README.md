# VitalPath AI - Wellness Coaching Platform

## 🎯 Product Overview

AI-powered wellness coaching platform with safety-first design. Provides personalized lifestyle guidance while maintaining strict wellness boundaries (NO medical advice).

### Core Values
- ✅ **Wellness Support**: Healthy habits, stress management, lifestyle guidance
- ❌ **No Medical Claims**: Never treats, diagnoses, cures, or prevents disease
- ⚠️ **Crisis Escalation**: Immediate resource provision for crisis indicators

## 🛠️ Tech Stack

### Backend
- **FastAPI** - Modern async Python web framework
- **GraphQL (Ariadne)** - Flexible API with subscriptions
- **Supabase** - PostgreSQL + Auth + Storage
- **ChromaDB** - Vector embeddings for semantic search
- **Redis** - Caching + rate limiting + Celery broker
- **Celery** - Distributed task queue with retry logic

### Key Features
- Multi-tier fallback chain for resilience
- Circuit breaker pattern for fault tolerance
- Real-time safety validation
- Multi-language crisis resources (EN, MY, TH, ZH, JA, KO)

## 📁 Project Structure

```
backend/
├── app/
│   ├── api/
│   │   ├── graphql_schema.py      # GraphQL type definitions
│   │   └── graphql_resolvers.py   # Query/Mutation resolvers
│   ├── core/
│   │   ├── config.py              # Settings management
│   │   ├── database.py            # SQLAlchemy async setup
│   │   ├── redis_client.py        # Redis connection
│   │   ├── chromadb_client.py     # Vector store client
│   │   └── celery_config.py       # Celery configuration
│   ├── models/
│   │   └── wellness_models.py     # SQLAlchemy ORM models
│   ├── services/
│   │   ├── safety_validator.py    # Safety boundary enforcement
│   │   └── wellness_ai_service.py # AI service with fallback chain
│   ├── tasks/
│   │   └── wellness_tasks.py      # Celery async tasks
│   └── main.py                    # FastAPI application
├── tests/
│   └── test_safety_and_fallback.py
├── requirements.txt
└── README.md
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Redis server
- PostgreSQL (Supabase)
- ChromaDB

### Installation

```bash
cd backend
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
```

### Environment Setup

Create `.env` file:

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Redis
REDIS_URL=redis://localhost:6379/0

# ChromaDB
CHROMADB_PERSIST_DIR=./chroma_data

# LLM
LLM_API_KEY=sk-your-openai-key
LLM_MODEL=gpt-4o-mini

# App Settings
DEBUG=true
LOG_LEVEL=INFO
```

### Run Services

```bash
# Start Redis (if not running)
redis-server

# Start Celery worker
celery -A app.core.celery_config worker --loglevel=info

# Start Celery Beat (scheduled tasks)
celery -A app.core.celery_config beat --loglevel=info

# Start FastAPI server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 📡 API Endpoints

### GraphQL Endpoint
- **HTTP**: `POST /graphql`
- **WebSocket**: `WS /graphql` (for subscriptions)

### Health Check
- `GET /health`

### Example GraphQL Queries

```graphql
# Get current user profile
query {
  me {
    id
    displayName
    preferredLanguage
    wellnessBoundariesAcknowledged
  }
}

# Send wellness query
mutation {
  sendWellnessQuery(
    input: {
      userInput: "Tips for better sleep"
      sessionType: MINDFULNESS
      language: "en-US"
    }
  ) {
    response
    fallbackLevel
    safetyValidated
    crisisDetected
    durationMs
  }
}

# Get crisis resources
query {
  getCrisisResources(language: "en-US") {
    type
    contact
  }
}
```

## 🛡️ Safety Features

### Wellness Boundaries Enforcement

Every AI response passes through `SafetyValidator`:

```python
from app.services.safety_validator import safety_validator, SafetyLevel

# Validate user input
level, context = safety_validator.validate_input(user_input, language="en-US")
if level == SafetyLevel.CRISIS:
    # Return crisis resources immediately
    return safety_validator.get_crisis_message(language)

# Validate AI response
level, context = safety_validator.validate_response(ai_response)
if level == SafetyLevel.PROHIBITED:
    # Block and regenerate or sanitize
    ai_response = safety_validator.sanitize_response(ai_response)
```

### Fallback Chain

The AI service implements 5-level fallback:

1. **Primary AI** - LLM API call
2. **Redis Cache** - Exact match cache
3. **ChromaDB Similarity** - Semantic cache (>85% similarity)
4. **Static Content** - Pre-approved wellness tips
5. **Error Message** - Graceful degradation with disclaimer

### Circuit Breaker

Prevents cascading failures when AI service is down:

```python
from app.services.wellness_ai_service import wellness_ai_service

# Circuit state: closed (healthy), open (failing), half_open (testing)
state = wellness_ai_service.circuit_breaker.get_state()
```

## 🧪 Testing

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html

# Run specific test class
pytest tests/test_safety_and_fallback.py::TestSafetyValidator -v
```

## 📊 Scalability Targets

| Metric | MVP | Scale |
|--------|-----|-------|
| MAU | 1,000 | 50,000 |
| P95 Latency | <100ms | <150ms |
| AI Workers | 2 | Auto-scaled |
| Database | Single | Read replicas |
| Budget | $100/mo | $500/mo |

## 🔒 Privacy & Compliance

- **No PHI Logging**: User inputs are anonymized before AI calls
- **Input Hashing**: SHA256 hashes for deduplication (raw input never stored)
- **RLS Policies**: Supabase Row Level Security for data isolation
- **Encryption**: OAuth tokens encrypted at rest via Supabase Vault

## 🌍 Localization

Supported languages:
- `en-US` - English (default)
- `my-MM` - Myanmar
- `th-TH` - Thai
- `zh-CN` - Chinese (Simplified)
- `ja-JP` - Japanese
- `ko-KR` - Korean

## 📝 License

Proprietary - VitalPath AI © 2024

---

**⚠️ IMPORTANT**: This platform provides wellness guidance only, NOT medical advice. Always include wellness disclaimers and escalate crisis situations to appropriate resources.
