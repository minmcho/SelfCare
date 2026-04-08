"""
GraphQL Resolvers for VitalPath AI
Implements query, mutation, and subscription resolvers
"""
import asyncio
import time
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone

from ariadne import QueryType, MutationType, SubscriptionType
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.wellness_models import WellnessProfile, WellnessSession, WearableConnection
from app.services.wellness_ai_service import wellness_ai_service
from app.services.safety_validator import safety_validator, SafetyLevel, CrisisResource
from app.core.database import get_db
from app.core.redis_client import redis_client
from app.core.chromadb_client import chroma_client


# Define GraphQL types
query = QueryType()
mutation = MutationType()
subscription = SubscriptionType()


# =============================================================================
# QUERY RESOLVERS
# =============================================================================

@query.field("me")
async def resolve_me(obj, info, **kwargs):
    """Get current authenticated user's profile."""
    # Get user ID from context (set by auth middleware)
    context = info.context
    user_id = context.get("user_id")
    
    if not user_id:
        return None
    
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        profile = result.scalar_one_or_none()
        return profile.to_dict() if profile else None


@query.field("getProfile")
async def resolve_get_profile(obj, info, id: str, **kwargs):
    """Get wellness profile by ID."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.id == id)
        )
        profile = result.scalar_one_or_none()
        return profile.to_dict() if profile else None


@query.field("getSessions")
async def resolve_get_sessions(
    obj, info, limit: int = 20, offset: int = 0, sessionType: Optional[str] = None, **kwargs
):
    """Get wellness sessions with pagination."""
    context = info.context
    user_id = context.get("user_id")
    
    async with AsyncSessionLocal() as session:
        # Get profile first to get profile_id
        profile_result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        profile = profile_result.scalar_one_or_none()
        
        if not profile:
            return []
        
        # Build query
        stmt = select(WellnessSession).where(
            WellnessSession.profile_id == profile.id
        )
        
        if sessionType:
            stmt = stmt.where(WellnessSession.session_type == sessionType.lower())
        
        stmt = stmt.order_by(WellnessSession.created_at.desc())
        stmt = stmt.offset(offset).limit(limit)
        
        result = await session.execute(stmt)
        sessions = result.scalars().all()
        
        return [session.to_dict() for session in sessions]


@query.field("getSession")
async def resolve_get_session(obj, info, id: str, **kwargs):
    """Get specific session by ID."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessSession).where(WellnessSession.id == id)
        )
        session = result.scalar_one_or_none()
        return session.to_dict() if session else None


@query.field("getWearableConnections")
async def resolve_get_wearable_connections(obj, info, **kwargs):
    """Get all wearable connections for current user."""
    context = info.context
    user_id = context.get("user_id")
    
    async with AsyncSessionLocal() as session:
        # Get profile
        profile_result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        profile = profile_result.scalar_one_or_none()
        
        if not profile:
            return []
        
        result = await session.execute(
            select(WearableConnection).where(
                WearableConnection.profile_id == profile.id
            )
        )
        connections = result.scalars().all()
        
        return [conn.to_dict() for conn in connections]


@query.field("getCrisisResources")
async def resolve_get_crisis_resources(obj, info, language: str = "en-US", **kwargs):
    """Get crisis resources for specified language."""
    resources = CrisisResource.get_resources(language)
    return [
        {"type": key, "contact": value, "language": language}
        for key, value in resources.items()
    ]


@query.field("healthCheck")
async def resolve_health_check(obj, info, **kwargs):
    """Health check for all services."""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "services": {},
    }
    
    # Check Redis
    health_status["services"]["redis"] = await redis_client.health_check()
    
    # Check ChromaDB
    health_status["services"]["chromadb"] = await chroma_client.health_check()
    
    # Check AI circuit breaker
    health_status["services"]["aiService"] = \
        wellness_ai_service.circuit_breaker.get_state()
    
    # Check database
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(select(1))
        health_status["services"]["database"] = True
    except Exception:
        health_status["services"]["database"] = False
        health_status["status"] = "degraded"
    
    # Determine overall status
    unhealthy = [
        k for k, v in health_status["services"].items()
        if v is False or v == "open"
    ]
    if unhealthy:
        health_status["status"] = "unhealthy"
    
    return health_status


# =============================================================================
# MUTATION RESOLVERS
# =============================================================================

@mutation.field("createProfile")
async def resolve_create_profile(obj, info, input: Dict[str, Any], **kwargs):
    """Create new wellness profile."""
    context = info.context
    user_id = context.get("user_id")
    
    if not user_id:
        raise Exception("Authentication required")
    
    async with AsyncSessionLocal() as session:
        # Check if profile already exists
        existing = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        if existing.scalar_one_or_none():
            raise Exception("Profile already exists for this user")
        
        # Create new profile
        profile = WellnessProfile(
            id=f"profile_{user_id}",
            user_id=user_id,
            display_name=input.get("displayName"),
            age=input.get("age"),
            gender=input.get("gender"),
            goals=input.get("goals"),
            preferred_language=input.get("preferredLanguage", "en-US"),
            notification_enabled=input.get("notificationEnabled", True),
            reminder_time=input.get("reminderTime"),
        )
        
        session.add(profile)
        await session.commit()
        await session.refresh(profile)
        
        return profile.to_dict()


@mutation.field("updateProfile")
async def resolve_update_profile(obj, info, id: str, input: Dict[str, Any], **kwargs):
    """Update existing wellness profile."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.id == id)
        )
        profile = result.scalar_one_or_none()
        
        if not profile:
            raise Exception("Profile not found")
        
        # Update fields
        update_fields = {
            "display_name": input.get("displayName"),
            "age": input.get("age"),
            "gender": input.get("gender"),
            "goals": input.get("goals"),
            "preferred_language": input.get("preferredLanguage"),
            "notification_enabled": input.get("notificationEnabled"),
            "reminder_time": input.get("reminderTime"),
            "wellness_boundaries_acknowledged": input.get("wellnessBoundariesAcknowledged"),
        }
        
        for field, value in update_fields.items():
            if value is not None:
                setattr(profile, field, value)
        
        await session.commit()
        await session.refresh(profile)
        
        return profile.to_dict()


@mutation.field("deleteProfile")
async def resolve_delete_profile(obj, info, id: str, **kwargs):
    """Soft delete wellness profile."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.id == id)
        )
        profile = result.scalar_one_or_none()
        
        if not profile:
            return False
        
        # Soft delete - mark as deleted or archive
        # For now, we'll hard delete (implement soft delete as needed)
        await session.delete(profile)
        await session.commit()
        
        return True


@mutation.field("sendWellnessQuery")
async def resolve_send_wellness_query(obj, info, input: Dict[str, Any], **kwargs):
    """Send wellness query to AI service."""
    start_time = time.time()
    
    context = info.context
    user_id = context.get("user_id")
    
    if not user_id:
        raise Exception("Authentication required")
    
    # Process through AI service with fallback chain
    result = await wellness_ai_service.process_wellness_request(
        user_id=user_id,
        user_input=input["userInput"],
        session_type=input.get("sessionType", "general").lower(),
        language=input.get("language", "en-US"),
        wearable_context=input.get("wearableContext"),
    )
    
    # Calculate duration
    duration_ms = int((time.time() - start_time) * 1000)
    
    # Map safety level
    safety_level = "SAFE"
    if result.get("crisis_detected"):
        safety_level = "CRISIS"
    
    return {
        "response": result["response"],
        "fallbackLevel": result["fallback_level"],
        "safetyValidated": result.get("safety_validated", True),
        "safetyLevel": safety_level,
        "crisisDetected": result.get("crisis_detected", False),
        "resourcesProvided": result.get("resources_provided", False),
        "cached": result.get("cached", False),
        "similarityScore": result.get("similarity_score"),
        "circuitState": result.get("circuit_state"),
        "durationMs": duration_ms,
    }


@mutation.field("connectWearable")
async def resolve_connect_wearable(obj, info, input: Dict[str, Any], **kwargs):
    """Connect wearable device (OAuth flow placeholder)."""
    context = info.context
    user_id = context.get("user_id")
    
    if not user_id:
        raise Exception("Authentication required")
    
    async with AsyncSessionLocal() as session:
        # Get profile
        profile_result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        profile = profile_result.scalar_one_or_none()
        
        if not profile:
            raise Exception("Profile not found")
        
        # Create wearable connection
        connection = WearableConnection(
            profile_id=profile.id,
            provider=input["provider"].lower(),
            device_name=input.get("deviceName"),
            is_connected=True,
            circuit_state="closed",
        )
        
        session.add(connection)
        await session.commit()
        await session.refresh(connection)
        
        return connection.to_dict()


@mutation.field("disconnectWearable")
async def resolve_disconnect_wearable(obj, info, id: str, **kwargs):
    """Disconnect wearable device."""
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WearableConnection).where(WearableConnection.id == id)
        )
        connection = result.scalar_one_or_none()
        
        if not connection:
            return False
        
        connection.is_connected = False
        connection.circuit_state = "open"
        
        await session.commit()
        return True


@mutation.field("syncWearable")
async def resolve_sync_wearable(obj, info, id: str, **kwargs):
    """Trigger manual wearable sync."""
    from app.tasks.wellness_tasks import sync_wearable_data
    
    # Queue sync task via Celery
    sync_wearable_data.delay(user_id="placeholder", provider="placeholder")
    
    return True


@mutation.field("acknowledgeWellnessBoundaries")
async def resolve_acknowledge_wellness_boundaries(obj, info, **kwargs):
    """User acknowledges wellness boundaries."""
    context = info.context
    user_id = context.get("user_id")
    
    if not user_id:
        raise Exception("Authentication required")
    
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(WellnessProfile).where(WellnessProfile.user_id == user_id)
        )
        profile = result.scalar_one_or_none()
        
        if not profile:
            return False
        
        profile.wellness_boundaries_acknowledged = True
        await session.commit()
        
        return True


# =============================================================================
# SUBSCRIPTION RESOLVERS
# =============================================================================

# In-memory channel for subscriptions (use Redis pub/sub in production)
subscription_channels: Dict[str, List] = {}


@subscription.source("sessionCreated")
async def source_session_created(obj, info, profileId: str, **kwargs):
    """Source for session created subscription."""
    channel = f"session:{profileId}"
    
    if channel not in subscription_channels:
        subscription_channels[channel] = asyncio.Queue()
    
    while True:
        session_data = await subscription_channels[channel].get()
        yield session_data


@subscription.field("sessionCreated")
def resolve_session_created(session_data, info, **kwargs):
    """Resolve session created event."""
    return session_data


@subscription.source("wearableStatusChanged")
async def source_wearable_status_changed(obj, info, profileId: str, **kwargs):
    """Source for wearable status subscription."""
    channel = f"wearable:{profileId}"
    
    if channel not in subscription_channels:
        subscription_channels[channel] = asyncio.Queue()
    
    while True:
        wearable_data = await subscription_channels[channel].get()
        yield wearable_data


@subscription.field("wearableStatusChanged")
def resolve_wearable_status_changed(wearable_data, info, **kwargs):
    """Resolve wearable status change event."""
    return wearable_data


@subscription.source("crisisAlert")
async def source_crisis_alert(obj, info, **kwargs):
    """Source for crisis alert subscription."""
    channel = "crisis:alerts"
    
    if channel not in subscription_channels:
        subscription_channels[channel] = asyncio.Queue()
    
    while True:
        alert_data = await subscription_channels[channel].get()
        yield alert_data


@subscription.field("crisisAlert")
def resolve_crisis_alert(alert_data, info, **kwargs):
    """Resolve crisis alert event."""
    return alert_data


# Helper function to publish subscription events
async def publish_subscription_event(channel: str, data: dict):
    """Publish event to subscription channel."""
    if channel in subscription_channels:
        await subscription_channels[channel].put(data)
