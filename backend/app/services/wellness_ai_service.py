"""
Wellness AI Service with Resilient Fallback Chain
Implements circuit breaker pattern and graceful degradation.

Fallback Levels:
0. Primary AI (LLM via API)
1. Cached response (Redis + ChromaDB similarity)
2. Static wellness content (pre-approved library)
3. Error message with wellness disclaimer
"""
import asyncio
import hashlib
import json
import time
from typing import Optional, Dict, Any, List
from enum import Enum
import httpx

from app.core.config import get_settings
from app.core.redis_client import redis_client
from app.core.chromadb_client import chroma_client
from app.services.safety_validator import safety_validator, SafetyLevel


settings = get_settings()


class FallbackLevel(Enum):
    """AI service fallback levels."""
    AI_SUCCESS = 0
    CACHE_HIT = 1
    SIMILARITY_CACHE = 2
    STATIC_CONTENT = 3
    ERROR_MESSAGE = 4


class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Failing, skip primary
    HALF_OPEN = "half_open"  # Testing recovery


class CircuitBreaker:
    """
    Circuit breaker for AI service resilience.
    Prevents cascading failures when AI service is down.
    """
    
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        half_open_max_calls: int = 3,
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_max_calls = half_open_max_calls
        
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.last_failure_time: Optional[float] = None
        self.half_open_calls = 0
    
    async def call(self, func, *args, **kwargs):
        """Execute function with circuit breaker protection."""
        if self.state == CircuitState.OPEN:
            # Check if recovery timeout has passed
            if self.last_failure_time and \
               time.time() - self.last_failure_time > self.recovery_timeout:
                self.state = CircuitState.HALF_OPEN
                self.half_open_calls = 0
            else:
                raise Exception("Circuit breaker is OPEN")
        
        try:
            result = await func(*args, **kwargs)
            
            # Success - reset counter
            if self.state == CircuitState.HALF_OPEN:
                self.half_open_calls += 1
                if self.half_open_calls >= self.half_open_max_calls:
                    self.state = CircuitState.CLOSED
                    self.failure_count = 0
            
            return result
            
        except Exception as e:
            self.failure_count += 1
            self.last_failure_time = time.time()
            
            if self.failure_count >= self.failure_threshold:
                self.state = CircuitState.OPEN
            
            raise e
    
    def get_state(self) -> str:
        """Get current circuit state as string."""
        return self.state.value


class WellnessAIService:
    """
    AI wellness coaching service with resilient fallback chain.
    
    Features:
    - Multi-tier fallback for maximum availability
    - Vector-based semantic caching
    - Circuit breaker for fault tolerance
    - Privacy-preserving input anonymization
    """
    
    def __init__(self):
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=5,
            recovery_timeout=60,
            half_open_max_calls=3,
        )
        self.http_client: Optional[httpx.AsyncClient] = None
    
    async def _get_http_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client for LLM API calls."""
        if not self.http_client or self.http_client.is_closed:
            self.http_client = httpx.AsyncClient(
                timeout=httpx.Timeout(30.0, connect=10.0),
                limits=httpx.Limits(max_keepalive_connections=10),
            )
        return self.http_client
    
    async def close(self):
        """Close HTTP client on shutdown."""
        if self.http_client and not self.http_client.is_closed:
            await self.http_client.aclose()
    
    def _anonymize_input(self, user_input: str) -> str:
        """
        Remove PII and PHI from input before AI processing.
        CRITICAL: Never log or transmit raw user input.
        """
        # Simple anonymization patterns (expand for production)
        anonymized = user_input
        
        # Remove phone numbers
        import re
        anonymized = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE]', anonymized)
        
        # Remove email addresses
        anonymized = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL]', anonymized)
        
        # Remove potential medical IDs (simple pattern)
        anonymized = re.sub(r'\b[A-Z]{2,}\d{6,}\b', '[ID]', anonymized)
        
        return anonymized
    
    def _generate_cache_key(self, user_input: str) -> str:
        """Generate cache key from input hash."""
        return f"wellness_cache:{hashlib.sha256(user_input.encode()).hexdigest()}"
    
    async def _get_embedding(self, text: str) -> List[float]:
        """
        Generate embedding vector for text.
        Uses OpenAI embeddings or compatible API.
        """
        client = await self._get_http_client()
        
        try:
            response = await client.post(
                "https://api.openai.com/v1/embeddings",
                headers={
                    "Authorization": f"Bearer {settings.LLM_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "text-embedding-3-small",
                    "input": text[:8191],  # Token limit
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["data"][0]["embedding"]
        except Exception:
            # Return zero vector as fallback
            return [0.0] * 1536
    
    async def _call_llm_api(
        self,
        user_input: str,
        context: Optional[Dict[str, Any]] = None,
        language: str = "en-US",
    ) -> str:
        """
        Call primary LLM API for wellness coaching.
        
        Args:
            user_input: Anonymized user message
            context: Optional context (wearable data, history)
            language: Response language code
            
        Returns:
            AI-generated wellness response
        """
        client = await self._get_http_client()
        
        # Build system prompt with wellness boundaries
        system_prompt = f"""You are VitalPath AI, a wellness coaching assistant.

WELLNESS BOUNDARIES (CRITICAL):
✅ ALLOWED: Support healthy habits, promote wellness, personalized lifestyle guidance
❌ PROHIBITED: Treat, diagnose, cure, prevent disease, medical advice, medical claims

LANGUAGE: Respond in {language}

Always include a wellness disclaimer. Never provide medical advice.
If the user mentions crisis indicators, provide crisis resources instead of coaching."""

        # Build user message with context
        user_message = user_input
        if context:
            wearable_info = ""
            if context.get("steps_avg"):
                wearable_info += f"Average daily steps: {context['steps_avg']}\n"
            if context.get("sleep_hours"):
                wearable_info += f"Average sleep: {context['sleep_hours']} hours\n"
            
            if wearable_info:
                user_message = f"Context:\n{wearable_info}\n\nUser question: {user_input}"
        
        try:
            response = await client.post(
                f"https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.LLM_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.LLM_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_message},
                    ],
                    "temperature": settings.LLM_TEMPERATURE,
                    "max_tokens": settings.LLM_MAX_TOKENS,
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
            
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:  # Rate limit
                raise Exception("AI service rate limited")
            raise
        except Exception as e:
            raise Exception(f"LLM API error: {str(e)}")
    
    async def _get_static_content(self, session_type: str) -> str:
        """Return pre-approved static wellness content."""
        static_responses = {
            "nutrition": """🥗 **Wellness Tip: Balanced Nutrition**

Support your healthy habits by focusing on whole foods and balanced meals.

• Include colorful vegetables and fruits
• Stay hydrated with water throughout the day
• Practice mindful eating

*Remember: This is wellness guidance, not medical advice. Consult healthcare professionals for specific dietary needs.*""",
            
            "fitness": """🏃 **Wellness Tip: Active Lifestyle**

Promote wellness through regular movement that you enjoy!

• Aim for consistent daily activity
• Listen to your body's signals
• Celebrate progress, not perfection

*This is lifestyle guidance to support your wellness journey.*""",
            
            "mindfulness": """🧘 **Wellness Tip: Mindful Moments**

Support mental wellness through mindfulness practices.

• Take 5 minutes for deep breathing
• Notice thoughts without judgment
• Create moments of calm in your day

*Wellness guidance for stress management and balance.*""",
            
            "general": """💙 **Welcome to Your Wellness Journey**

I'm here to support your healthy habits and personal wellness goals.

What would you like to focus on today?
• Nutrition & hydration
• Physical activity
• Sleep & rest
• Stress management
• Building positive habits

*Note: I provide wellness guidance, not medical advice.*""",
        }
        
        return static_responses.get(session_type, static_responses["general"])
    
    async def process_wellness_request(
        self,
        user_id: str,
        user_input: str,
        session_type: str = "general",
        language: str = "en-US",
        wearable_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Process wellness coaching request with full fallback chain.
        
        Args:
            user_id: User identifier
            user_input: Raw user message
            session_type: Type of wellness session
            language: Preferred language
            wearable_context: Optional aggregated wearable data
            
        Returns:
            Response dict with response, fallback_level, safety info
        """
        start_time = time.time()
        fallback_level = FallbackLevel.AI_SUCCESS
        
        # Step 1: Validate input for crisis indicators
        safety_level, safety_context = safety_validator.validate_input(user_input, language)
        
        if safety_level == SafetyLevel.CRISIS:
            # Immediate crisis escalation
            return {
                "response": safety_validator.get_crisis_message(language),
                "fallback_level": FallbackLevel.STATIC_CONTENT.value,
                "crisis_detected": True,
                "safety_validated": True,
                "resources_provided": True,
            }
        
        # Anonymize input (never use raw input for AI/cache)
        anonymized_input = self._anonymize_input(user_input)
        cache_key = self._generate_cache_key(anonymized_input)
        
        # Step 2: Try Redis cache first
        try:
            cached = await redis_client.get_json(cache_key)
            if cached:
                return {
                    "response": cached["response"],
                    "fallback_level": FallbackLevel.CACHE_HIT.value,
                    "cached": True,
                    "safety_validated": True,
                }
        except Exception:
            pass  # Cache miss or error, continue
        
        # Step 3: Try ChromaDB similarity search
        try:
            query_embedding = await self._get_embedding(anonymized_input)
            similar = await chroma_client.similarity_search(
                query_embedding=query_embedding,
                n_results=1,
                filter_metadata={"session_type": session_type},
            )
            
            if similar and similar[0]["score"] > 0.85:  # High similarity threshold
                return {
                    "response": similar[0]["document"],
                    "fallback_level": FallbackLevel.SIMILARITY_CACHE.value,
                    "similarity_score": similar[0]["score"],
                    "safety_validated": True,
                }
        except Exception:
            pass  # Similarity search failed, continue
        
        # Step 4: Try primary AI with circuit breaker
        try:
            ai_response = await self.circuit_breaker.call(
                self._call_llm_api,
                anonymized_input,
                wearable_context,
                language,
            )
            
            # Validate AI response
            response_safety, response_context = safety_validator.validate_response(ai_response)
            
            if response_safety == SafetyLevel.PROHIBITED:
                # Sanitize and retry or use static content
                ai_response = safety_validator.sanitize_response(ai_response)
                fallback_level = FallbackLevel.STATIC_CONTENT
            
            # Cache the response
            try:
                await redis_client.set_json(
                    cache_key,
                    {"response": ai_response, "timestamp": time.time()},
                    expire_seconds=3600,  # 1 hour cache
                )
                
                # Store embedding in ChromaDB
                embedding = await self._get_embedding(anonymized_input)
                await chroma_client.add_embedding(
                    id=cache_key,
                    embedding=embedding,
                    metadata={"session_type": session_type, "user_id_hash": hashlib.sha256(user_id.encode()).hexdigest()},
                    document=ai_response,
                )
            except Exception:
                pass  # Non-critical caching failure
            
            return {
                "response": ai_response,
                "fallback_level": fallback_level.value,
                "safety_validated": True,
                "circuit_state": self.circuit_breaker.get_state(),
            }
            
        except Exception as e:
            # Circuit breaker open or AI failure
            pass
        
        # Step 5: Fallback to static content
        try:
            static_response = await self._get_static_content(session_type)
            return {
                "response": static_response,
                "fallback_level": FallbackLevel.STATIC_CONTENT.value,
                "static_content": True,
                "safety_validated": True,
            }
        except Exception:
            pass
        
        # Step 6: Last resort error message
        return {
            "response": f"""💙 **Wellness Disclaimer**

I'm temporarily unable to provide personalized guidance. Please try again in a moment.

In the meantime, remember:
• Small steps lead to big changes
• You're doing great on your wellness journey
• Consistency matters more than perfection

*VitalPath provides wellness support, not medical advice.*""",
            "fallback_level": FallbackLevel.ERROR_MESSAGE.value,
            "error": True,
        }


# Global singleton instance
wellness_ai_service = WellnessAIService()
