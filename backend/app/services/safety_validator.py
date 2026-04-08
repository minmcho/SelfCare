"""
Safety Validator for Wellness Boundary Enforcement
CRITICAL: Every AI response must pass validation before being shown to users.

Wellness Boundaries (ALLOWED):
✅ "Support healthy habits"
✅ "Promote wellness"
✅ "Personalized lifestyle guidance"

Prohibited (NEVER ALLOWED):
❌ "Treat", "Diagnose", "Cure", "Prevent disease"
❌ Any medical claims or advice
"""
import re
import json
from typing import List, Dict, Tuple, Optional
from enum import Enum
from pathlib import Path


class SafetyLevel(Enum):
    """Safety classification levels."""
    SAFE = "safe"
    CAUTION = "caution"  # Needs human review
    CRISIS = "crisis"  # Immediate escalation required
    PROHIBITED = "prohibited"  # Violates wellness boundaries


class CrisisResource:
    """Crisis resource information for escalation."""
    
    RESOURCES = {
        "en-US": {
            "suicide_prevention": "988 Suicide & Crisis Lifeline: Call/Text 988",
            "domestic_violence": "National Domestic Violence Hotline: 1-800-799-7233",
            "eating_disorders": "NEDA Helpline: 1-800-931-2237",
            "crisis_text": "Crisis Text Line: Text HOME to 741741",
        },
        "my-MM": {
            "general": "Befrienders Myanmar: 01-302345",
        },
        "th-TH": {
            "suicide_prevention": "Thai Suicide Prevention: 1323",
        },
        "zh-CN": {
            "suicide_prevention": "北京心理危机干预中心：010-82951332",
        },
        "ja-JP": {
            "suicide_prevention": "いのちの電話：0120-783-556",
        },
        "ko-KR": {
            "suicide_prevention": "자살예방상담전화: 109",
        },
    }
    
    @classmethod
    def get_resources(cls, language: str = "en-US") -> Dict[str, str]:
        """Get crisis resources for specific language."""
        return cls.RESOURCES.get(language, cls.RESOURCES["en-US"])


class SafetyValidator:
    """
    Runtime safety validator for AI wellness coaching.
    
    Features:
    - Crisis keyword detection with immediate escalation
    - Medical claim prevention
    - Wellness boundary enforcement
    - Multi-language support
    """
    
    # Crisis keywords that trigger immediate escalation
    CRISIS_KEYWORDS = [
        # English
        "suicide", "kill myself", "end my life", "want to die", "no reason to live",
        "self harm", "cutting", "hurt myself", "suicidal", "hopeless",
        "overdose", "pills", "gun", "weapon",
        
        # Eating disorder indicators
        "starving", "binge", "purge", "anorexic", "bulimic",
        
        # Abuse indicators
        "abuse", "hit me", "hurts me", "afraid of", "domestic",
        
        # Severe mental health
        "psychotic", "hallucinating", "hearing voices", "delusional",
    ]
    
    # Medical claim patterns (PROHIBITED)
    MEDICAL_CLAIM_PATTERNS = [
        r"\b(treat|treats|treating|treated)\b",
        r"\b(diagnose|diagnoses|diagnosed|diagnosing)\b",
        r"\b(cure|cures|cured|curing)\b",
        r"\b(prevent disease|prevents disease|disease prevention)\b",
        r"\b(medical advice|medical condition|medical treatment)\b",
        r"\b(prescribe|prescribes|prescribed|prescription)\b",
        r"\b(therapy|therapeutic|therapist)\b.*\b(for|with)\b",
        r"\b(clinical|clinically)\b.*\b(proven|tested|studied)\b",
        r"\b(fda approved|fda cleared)\b",
        r"\b(doctor|physician|nurse|healthcare provider)\b.*\b(recommend|advise)\b",
    ]
    
    # Wellness-appropriate language patterns (ALLOWED)
    WELLNESS_PATTERNS = [
        r"\b(support|supports|supporting)\b.*\b(healthy|wellness|habits)\b",
        r"\b(promote|promotes|promoting)\b.*\b(wellness|health|balance)\b",
        r"\b(lifestyle|lifestyle)\b.*\b(guidance|support|tips)\b",
        r"\b(personalized|personalised)\b.*\b(wellness|goals|journey)\b",
    ]
    
    def __init__(self, crisis_keywords_file: Optional[str] = None):
        """
        Initialize safety validator.
        
        Args:
            crisis_keywords_file: Optional path to custom crisis keywords JSON
        """
        self.crisis_keywords = set(self.CRISIS_KEYWORDS)
        self.medical_patterns = [
            re.compile(pattern, re.IGNORECASE)
            for pattern in self.MEDICAL_CLAIM_PATTERNS
        ]
        
        # Load custom crisis keywords if provided
        if crisis_keywords_file and Path(crisis_keywords_file).exists():
            try:
                with open(crisis_keywords_file, 'r') as f:
                    custom_keywords = json.load(f)
                    self.crisis_keywords.update(custom_keywords.get("keywords", []))
            except Exception:
                pass  # Use defaults if file load fails
    
    def validate_input(self, user_input: str, language: str = "en-US") -> Tuple[SafetyLevel, Optional[Dict]]:
        """
        Validate user input for crisis indicators.
        
        Args:
            user_input: Raw user message
            language: User's preferred language code
            
        Returns:
            (SafetyLevel, optional context dict)
        """
        input_lower = user_input.lower()
        
        # Check for crisis keywords
        detected_keywords = []
        for keyword in self.crisis_keywords:
            if keyword in input_lower:
                detected_keywords.append(keyword)
        
        if detected_keywords:
            return SafetyLevel.CRISIS, {
                "detected_keywords": detected_keywords,
                "resources": CrisisResource.get_resources(language),
                "action": "escalate_immediately",
            }
        
        return SafetyLevel.SAFE, None
    
    def validate_response(self, ai_response: str) -> Tuple[SafetyLevel, Optional[Dict]]:
        """
        Validate AI response for medical claims and boundary violations.
        MUST be called before showing any AI response to users.
        
        Args:
            ai_response: Raw AI-generated response
            
        Returns:
            (SafetyLevel, optional context dict)
        """
        issues = []
        
        # Check for medical claim patterns
        for pattern in self.medical_patterns:
            matches = pattern.findall(ai_response)
            if matches:
                issues.append({
                    "type": "medical_claim",
                    "pattern": pattern.pattern,
                    "matches": matches,
                })
        
        if issues:
            return SafetyLevel.PROHIBITED, {
                "issues": issues,
                "action": "block_and_regenerate",
            }
        
        # Optional: Check for wellness-appropriate language
        wellness_score = 0
        for pattern in self.WELLNESS_PATTERNS:
            if pattern.search(ai_response):
                wellness_score += 1
        
        if wellness_score == 0:
            # No wellness language detected - flag for review
            return SafetyLevel.CAUTION, {
                "warning": "No wellness-appropriate language detected",
                "action": "human_review_recommended",
            }
        
        return SafetyLevel.SAFE, {"wellness_score": wellness_score}
    
    def sanitize_response(self, ai_response: str) -> str:
        """
        Remove or replace problematic phrases from AI response.
        Used as a fallback when regeneration isn't possible.
        
        Args:
            ai_response: Raw AI response
            
        Returns:
            Sanitized response safe for display
        """
        sanitized = ai_response
        
        # Replace medical claim phrases with wellness-appropriate alternatives
        replacements = {
            "treat": "support",
            "cure": "help manage",
            "diagnose": "identify patterns in",
            "prevent disease": "promote wellness",
            "medical advice": "wellness guidance",
            "prescribe": "suggest",
            "therapy": "wellness practice",
            "patient": "individual",
            "symptom": "experience",
        }
        
        for medical_term, wellness_term in replacements.items():
            # Case-insensitive replacement preserving case
            pattern = re.compile(re.escape(medical_term), re.IGNORECASE)
            sanitized = pattern.sub(wellness_term, sanitized)
        
        return sanitized
    
    def get_crisis_message(self, language: str = "en-US") -> str:
        """
        Generate crisis escalation message.
        
        Args:
            language: User's preferred language
            
        Returns:
            Formatted crisis resource message
        """
        resources = CrisisResource.get_resources(language)
        
        message = "⚠️ **Important: We're here to support your wellness journey**\n\n"
        message += "It sounds like you're going through something difficult. "
        message += "While I'm here to provide wellness guidance, I want to make sure you get the right support.\n\n"
        message += "**Please reach out to these free, confidential resources:**\n\n"
        
        for resource_type, contact in resources.items():
            message += f"• {contact}\n"
        
        message += "\n💙 You matter. Help is available. Please reach out."
        
        return message


# Global singleton instance
safety_validator = SafetyValidator()
