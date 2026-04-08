"""
Unit Tests for Safety Validator and Fallback Logic
VitalPath AI - Wellness Coaching Platform
"""
import pytest
from app.services.safety_validator import (
    SafetyValidator,
    SafetyLevel,
    CrisisResource,
)
from app.services.wellness_ai_service import (
    CircuitBreaker,
    CircuitState,
    FallbackLevel,
)


# =============================================================================
# SAFETY VALIDATOR TESTS
# =============================================================================

class TestSafetyValidator:
    """Test suite for safety validation logic."""
    
    @pytest.fixture
    def validator(self):
        """Create a fresh safety validator instance."""
        return SafetyValidator()
    
    # Crisis Detection Tests
    
    def test_detects_suicide_keywords(self, validator):
        """Test that suicide-related keywords trigger crisis detection."""
        test_inputs = [
            "I want to end my life",
            "Thinking about suicide",
            "No reason to live anymore",
            "I want to die",
        ]
        
        for user_input in test_inputs:
            level, context = validator.validate_input(user_input)
            assert level == SafetyLevel.CRISIS
            assert context is not None
            assert "action" in context
            assert context["action"] == "escalate_immediately"
    
    def test_detects_self_harm_keywords(self, validator):
        """Test that self-harm keywords trigger crisis detection."""
        test_inputs = [
            "I keep cutting myself",
            "Want to hurt myself",
            "Self harm is my only outlet",
        ]
        
        for user_input in test_inputs:
            level, context = validator.validate_input(user_input)
            assert level == SafetyLevel.CRISIS
    
    def test_detects_eating_disorder_keywords(self, validator):
        """Test that eating disorder indicators are detected."""
        test_inputs = [
            "I've been starving myself",
            "Binge and purge cycle",
            "Think I'm anorexic",
        ]
        
        for user_input in test_inputs:
            level, context = validator.validate_input(user_input)
            assert level == SafetyLevel.CRISIS
    
    def test_safe_input_passes(self, validator):
        """Test that normal wellness queries pass as safe."""
        safe_inputs = [
            "How can I eat healthier?",
            "Tips for better sleep",
            "Want to start exercising more",
            "Stress management techniques",
        ]
        
        for user_input in safe_inputs:
            level, context = validator.validate_input(user_input)
            assert level == SafetyLevel.SAFE
    
    # Medical Claim Prevention Tests
    
    def test_blocks_medical_claims_treat(self, validator):
        """Test that 'treat' claims are blocked."""
        problematic_responses = [
            "This will treat your anxiety",
            "Use this to treat depression",
            "Known to treat insomnia effectively",
        ]
        
        for response in problematic_responses:
            level, context = validator.validate_response(response)
            assert level == SafetyLevel.PROHIBITED
    
    def test_blocks_medical_claims_diagnose(self, validator):
        """Test that 'diagnose' claims are blocked."""
        response = "I can diagnose your condition based on symptoms"
        level, context = validator.validate_response(response)
        assert level == SafetyLevel.PROHIBITED
    
    def test_blocks_medical_claims_cure(self, validator):
        """Test that 'cure' claims are blocked."""
        response = "This supplement can cure diabetes"
        level, context = validator.validate_response(response)
        assert level == SafetyLevel.PROHIBITED
    
    def test_blocks_medical_claims_prevent_disease(self, validator):
        """Test that disease prevention claims are blocked."""
        response = "This diet will prevent heart disease"
        level, context = validator.validate_response(response)
        assert level == SafetyLevel.PROHIBITED
    
    def test_allows_wellness_language(self, validator):
        """Test that wellness-appropriate language passes."""
        safe_responses = [
            "Support your healthy habits by staying hydrated",
            "Promote wellness through regular exercise",
            "Here's personalized lifestyle guidance for your goals",
            "This can help support your wellness journey",
        ]
        
        for response in safe_responses:
            level, context = validator.validate_response(response)
            assert level == SafetyLevel.SAFE
            assert context is not None
            assert "wellness_score" in context
    
    # Sanitization Tests
    
    def test_sanitizes_medical_terms(self, validator):
        """Test that medical terms are replaced with wellness alternatives."""
        original = "This treatment can cure your symptoms"
        sanitized = validator.sanitize_response(original)
        
        assert "cure" not in sanitized.lower()
        assert "symptoms" not in sanitized.lower()
        assert "help manage" in sanitized.lower()
    
    # Crisis Resource Tests
    
    def test_gets_crisis_resources_english(self):
        """Test crisis resources for English."""
        resources = CrisisResource.get_resources("en-US")
        assert "suicide_prevention" in resources
        assert "988" in resources["suicide_prevention"]
    
    def test_gets_crisis_resources_multilingual(self):
        """Test crisis resources for different languages."""
        languages = ["my-MM", "th-TH", "zh-CN", "ja-JP", "ko-KR"]
        
        for lang in languages:
            resources = CrisisResource.get_resources(lang)
            assert isinstance(resources, dict)
            assert len(resources) > 0
    
    def test_generates_crisis_message(self, validator):
        """Test crisis message generation."""
        message = validator.get_crisis_message("en-US")
        
        assert "Important" in message
        assert "988" in message
        assert "confidential" in message.lower()


# =============================================================================
# CIRCUIT BREAKER TESTS
# =============================================================================

class TestCircuitBreaker:
    """Test suite for circuit breaker pattern."""
    
    @pytest.fixture
    def breaker(self):
        """Create circuit breaker with low threshold for testing."""
        return CircuitBreaker(
            failure_threshold=3,
            recovery_timeout=1,
            half_open_max_calls=2,
        )
    
    @pytest.mark.asyncio
    async def test_starts_closed(self, breaker):
        """Test that circuit breaker starts in closed state."""
        assert breaker.state == CircuitState.CLOSED
        assert breaker.get_state() == "closed"
    
    @pytest.mark.asyncio
    async def test_opens_after_failures(self, breaker):
        """Test that circuit opens after threshold failures."""
        async def failing_func():
            raise Exception("Service unavailable")
        
        # Trigger failures
        for i in range(3):
            try:
                await breaker.call(failing_func)
            except Exception:
                pass
        
        assert breaker.state == CircuitState.OPEN
        assert breaker.get_state() == "open"
    
    @pytest.mark.asyncio
    async def test_rejects_when_open(self, breaker):
        """Test that open circuit rejects calls immediately."""
        async def failing_func():
            raise Exception("Service unavailable")
        
        # Open the circuit
        for i in range(3):
            try:
                await breaker.call(failing_func)
            except Exception:
                pass
        
        # Next call should fail immediately
        with pytest.raises(Exception, match="Circuit breaker is OPEN"):
            await breaker.call(failing_func)
    
    @pytest.mark.asyncio
    async def test_recovers_after_timeout(self, breaker):
        """Test that circuit transitions to half-open after timeout."""
        async def failing_func():
            raise Exception("Service unavailable")
        
        # Open the circuit
        for i in range(3):
            try:
                await breaker.call(failing_func)
            except Exception:
                pass
        
        assert breaker.state == CircuitState.OPEN
        
        # Wait for recovery timeout
        import asyncio
        await asyncio.sleep(1.1)
        
        # Next call attempt should transition to half-open
        async def success_func():
            return "success"
        
        result = await breaker.call(success_func)
        assert result == "success"
        assert breaker.state == CircuitState.HALF_OPEN
    
    @pytest.mark.asyncio
    async def test_closes_after_successful_half_open(self, breaker):
        """Test that circuit closes after successful calls in half-open."""
        async def failing_func():
            raise Exception("Service unavailable")
        
        async def success_func():
            return "success"
        
        # Open the circuit
        for i in range(3):
            try:
                await breaker.call(failing_func)
            except Exception:
                pass
        
        # Wait for recovery
        import asyncio
        await asyncio.sleep(1.1)
        
        # Make successful calls
        for i in range(2):
            await breaker.call(success_func)
        
        assert breaker.state == CircuitState.CLOSED
        assert breaker.failure_count == 0


# =============================================================================
# FALLBACK LOGIC TESTS
# =============================================================================

class TestFallbackLevels:
    """Test fallback level enum values."""
    
    def test_fallback_levels_exist(self):
        """Test that all fallback levels are defined."""
        assert FallbackLevel.AI_SUCCESS.value == 0
        assert FallbackLevel.CACHE_HIT.value == 1
        assert FallbackLevel.SIMILARITY_CACHE.value == 2
        assert FallbackLevel.STATIC_CONTENT.value == 3
        assert FallbackLevel.ERROR_MESSAGE.value == 4


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestSafetyAndFallbackIntegration:
    """Integration tests for safety + fallback chain."""
    
    @pytest.fixture
    def validator(self):
        return SafetyValidator()
    
    def test_crisis_bypasses_normal_flow(self, validator):
        """Test that crisis detection short-circuits normal processing."""
        crisis_input = "I'm thinking about ending my life"
        
        level, context = validator.validate_input(crisis_input)
        
        assert level == SafetyLevel.CRISIS
        assert context["action"] == "escalate_immediately"
        assert "resources" in context
        # In full integration, this would skip AI and return crisis resources
    
    def test_medical_claim_triggers_regeneration(self, validator):
        """Test that medical claims trigger sanitization or regeneration."""
        bad_response = "This treatment can cure your disease"
        
        level, context = validator.validate_response(bad_response)
        
        assert level == SafetyLevel.PROHIBITED
        assert context["action"] == "block_and_regenerate"
        
        # Verify sanitization works
        sanitized = validator.sanitize_response(bad_response)
        assert "cure" not in sanitized.lower()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
