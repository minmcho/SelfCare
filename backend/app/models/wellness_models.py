"""
SQLAlchemy Database Models for VitalPath AI
WellnessProfile, WellnessSession, WearableConnection
"""
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import String, Text, Boolean, DateTime, Float, ForeignKey, JSON, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class WellnessProfile(Base):
    """
    User wellness profile with preferences and goals.
    Stored in Supabase PostgreSQL with RLS policies.
    """
    __tablename__ = "wellness_profiles"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)  # UUID from Supabase Auth
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("auth.users.id"), unique=True, nullable=False)
    
    # Profile Information
    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    age: Mapped[Optional[int]] = mapped_column(nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    # Wellness Goals (structured data)
    goals: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    """
    Example:
    {
        "nutrition": ["balanced_diet", "hydration"],
        "fitness": ["daily_steps", "strength_training"],
        "mindfulness": ["meditation", "stress_management"]
    }
    """
    
    # Preferences
    preferred_language: Mapped[str] = mapped_column(String(10), default="en-US")
    """Supports: en-US, my-MM, th-TH, zh-CN, ja-JP, ko-KR"""
    
    notification_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    reminder_time: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)  # HH:MM format
    
    # Safety Settings
    crisis_contacts: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    wellness_boundaries_acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    
    # Relationships
    sessions: Mapped[List["WellnessSession"]] = relationship(
        back_populates="profile", cascade="all, delete-orphan"
    )
    wearable_connections: Mapped[List["WearableConnection"]] = relationship(
        back_populates="profile", cascade="all, delete-orphan"
    )
    
    __table_args__ = (
        Index("idx_wellness_profiles_user_id", "user_id"),
        Index("idx_wellness_profiles_language", "preferred_language"),
    )
    
    def to_dict(self) -> dict:
        """Convert to dictionary (excluding sensitive data)."""
        return {
            "id": self.id,
            "display_name": self.display_name,
            "age": self.age,
            "gender": self.gender,
            "goals": self.goals,
            "preferred_language": self.preferred_language,
            "notification_enabled": self.notification_enabled,
            "reminder_time": self.reminder_time,
            "wellness_boundaries_acknowledged": self.wellness_boundaries_acknowledged,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }


class WellnessSession(Base):
    """
    AI wellness coaching session record.
    Tracks interactions, safety validations, and outcomes.
    """
    __tablename__ = "wellness_sessions"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    profile_id: Mapped[str] = mapped_column(String(36), ForeignKey("wellness_profiles.id"), nullable=False)
    
    # Session Context
    session_type: Mapped[str] = mapped_column(String(50), default="general")
    """Types: general, nutrition, fitness, mindfulness, habit_coaching"""
    
    # Input/Output (anonymized - no PHI)
    user_input_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    """SHA256 hash of input for deduplication (original input never stored)"""
    
    ai_response_summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    """Sanitized summary of AI response (no medical claims)"""
    
    # Safety Validation
    safety_validated: Mapped[bool] = mapped_column(Boolean, default=False)
    safety_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    """0.0-1.0 confidence score from safety validator"""
    
    crisis_detected: Mapped[bool] = mapped_column(Boolean, default=False)
    crisis_resources_provided: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Fallback Chain Status
    fallback_level: Mapped[int] = mapped_column(default=0)
    """0=AI success, 1=cache hit, 2=static content, 3=error message"""
    
    # Vector Embedding Reference
    embedding_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    """Reference to ChromaDB embedding ID"""
    
    # Wearable Data Context (aggregated, no raw data)
    wearable_context: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    """
    Example:
    {
        "steps_avg": 8500,
        "sleep_hours": 7.2,
        "heart_rate_avg": 72
    }
    """
    
    # Metadata
    duration_seconds: Mapped[Optional[int]] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    
    # Relationships
    profile: Mapped["WellnessProfile"] = relationship(back_populates="sessions")
    
    __table_args__ = (
        Index("idx_wellness_sessions_profile_id", "profile_id"),
        Index("idx_wellness_sessions_created_at", "created_at"),
        Index("idx_wellness_sessions_safety", "safety_validated", "crisis_detected"),
    )
    
    def to_dict(self) -> dict:
        """Convert to dictionary."""
        return {
            "id": self.id,
            "profile_id": self.profile_id,
            "session_type": self.session_type,
            "safety_validated": self.safety_validated,
            "safety_score": self.safety_score,
            "crisis_detected": self.crisis_detected,
            "crisis_resources_provided": self.crisis_resources_provided,
            "fallback_level": self.fallback_level,
            "duration_seconds": self.duration_seconds,
            "created_at": self.created_at.isoformat(),
        }


class WearableConnection(Base):
    """
    Wearable device integration with circuit breaker pattern.
    Supports Apple Health, Fitbit, Garmin, Oura, etc.
    """
    __tablename__ = "wearable_connections"
    
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    profile_id: Mapped[str] = mapped_column(String(36), ForeignKey("wellness_profiles.id"), nullable=False)
    
    # Device Information
    provider: Mapped[str] = mapped_column(String(50), nullable=False)
    """Providers: apple_health, fitbit, garmin, oura, whoop"""
    
    device_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    external_device_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    
    # Connection Status
    is_connected: Mapped[bool] = mapped_column(Boolean, default=False)
    last_sync_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Circuit Breaker State
    circuit_state: Mapped[str] = mapped_column(String(20), default="closed")
    """States: closed (healthy), open (failing), half-open (testing)"""
    
    failure_count: Mapped[int] = mapped_column(default=0)
    last_failure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    next_retry_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Permissions (what data we can access)
    permissions: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    """
    Example:
    {
        "steps": true,
        "heart_rate": true,
        "sleep": true,
        "workouts": false
    }
    """
    
    # OAuth Tokens (encrypted at rest by Supabase Vault)
    access_token_encrypted: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    refresh_token_encrypted: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    token_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Metadata
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    
    # Relationships
    profile: Mapped["WellnessProfile"] = relationship(back_populates="wearable_connections")
    
    __table_args__ = (
        Index("idx_wearable_connections_profile_id", "profile_id"),
        Index("idx_wearable_connections_provider", "provider"),
        Index("idx_wearable_connections_status", "is_connected", "circuit_state"),
    )
    
    def to_dict(self) -> dict:
        """Convert to dictionary (excluding tokens)."""
        return {
            "id": self.id,
            "profile_id": self.profile_id,
            "provider": self.provider,
            "device_name": self.device_name,
            "is_connected": self.is_connected,
            "last_sync_at": self.last_sync_at.isoformat() if self.last_sync_at else None,
            "circuit_state": self.circuit_state,
            "failure_count": self.failure_count,
            "permissions": self.permissions,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }
