"""
Celery Tasks for VitalPath AI
Distributed task queue for async processing
"""
from celery import Task
from app.core.celery_config import celery_app, TaskRetry, TaskFailure
from app.core.database import AsyncSessionLocal
from app.services.wellness_ai_service import wellness_ai_service
from app.services.safety_validator import safety_validator
import time


class DatabaseTask(Task):
    """Base task with database session management."""
    
    _db_session = None
    
    @property
    def db_session(self):
        if self._db_session is None:
            self._db_session = AsyncSessionLocal()
        return self._db_session
    
    def after_return(self, *args, **kwargs):
        if self._db_session is not None:
            self._db_session.close()
            self._db_session = None


@celery_app.task(
    base=DatabaseTask,
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
async def process_wellness_session_async(
    self,
    user_id: str,
    user_input: str,
    session_type: str = "general",
    language: str = "en-US",
    wearable_context: dict = None,
):
    """
    Process wellness coaching request asynchronously via Celery.
    Used for non-realtime requests or batch processing.
    """
    try:
        result = await wellness_ai_service.process_wellness_request(
            user_id=user_id,
            user_input=user_input,
            session_type=session_type,
            language=language,
            wearable_context=wearable_context,
        )
        
        # Log structured metrics (no PHI)
        print(f"Wellness session processed: fallback_level={result['fallback_level']}")
        
        return result
        
    except Exception as exc:
        # Retry on transient failures
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(bind=True, max_retries=5, default_retry_delay=300)
async def sync_wearable_data(self, user_id: str, provider: str):
    """
    Sync data from wearable devices.
    Implements exponential backoff for API rate limits.
    """
    try:
        # Placeholder for actual wearable API integration
        print(f"Syncing wearable data for user {user_id} from {provider}")
        
        # Simulate API call
        await asyncio.sleep(1)
        
        return {"status": "success", "records_synced": 0}
        
    except Exception as exc:
        # Exponential backoff
        countdown = self.default_retry_delay * (2 ** self.request.retries)
        raise self.retry(exc=exc, countdown=countdown)


@celery_app.task
async def cleanup_old_sessions():
    """
    Daily cleanup of old wellness sessions.
    Runs via Celery Beat scheduler.
    """
    try:
        from sqlalchemy import delete
        from datetime import datetime, timedelta, timezone
        from app.models.wellness_models import WellnessSession
        
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=90)
        
        async with AsyncSessionLocal() as session:
            # Delete sessions older than 90 days
            stmt = delete(WellnessSession).where(
                WellnessSession.created_at < cutoff_date
            )
            result = await session.execute(stmt)
            await session.commit()
            
            deleted_count = result.rowcount
            print(f"Cleaned up {deleted_count} old wellness sessions")
            
        return {"status": "success", "deleted_count": deleted_count}
        
    except Exception as exc:
        print(f"Cleanup failed: {exc}")
        raise


@celery_app.task
async def health_check_ai_services():
    """
    Periodic health check of AI services.
    Monitors circuit breaker state and external APIs.
    """
    from app.core.redis_client import redis_client
    from app.core.chromadb_client import chroma_client
    
    health_status = {
        "timestamp": time.time(),
        "services": {},
    }
    
    # Check Redis
    health_status["services"]["redis"] = await redis_client.health_check()
    
    # Check ChromaDB
    health_status["services"]["chromadb"] = await chroma_client.health_check()
    
    # Check circuit breaker state
    health_status["services"]["ai_circuit_breaker"] = \
        wellness_ai_service.circuit_breaker.get_state()
    
    # Alert if any service is unhealthy
    unhealthy = [k for k, v in health_status["services"].items() if v is False or v == "open"]
    if unhealthy:
        print(f"ALERT: Unhealthy services: {unhealthy}")
    
    return health_status


@celery_app.task(bind=True, max_retries=3)
async def send_notification(self, user_id: str, notification_type: str, content: dict):
    """
    Send push notification to user.
    Supports multiple notification providers.
    """
    try:
        # Placeholder for actual notification service
        print(f"Sending {notification_type} notification to user {user_id}")
        print(f"Content: {content}")
        
        # Simulate sending
        await asyncio.sleep(0.1)
        
        return {"status": "sent", "user_id": user_id}
        
    except Exception as exc:
        raise self.retry(exc=exc)
