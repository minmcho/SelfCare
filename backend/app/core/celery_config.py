"""
Celery Configuration for Distributed Task Queue
Integrates with Redis as broker and result backend
"""
from celery import Celery
from celery.schedules import crontab
from app.core.config import get_settings

settings = get_settings()

# Initialize Celery app
celery_app = Celery(
    "vitalpath",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=[
        "app.tasks.wellness_tasks",
        "app.tasks.ai_tasks",
        "app.tasks.notification_tasks",
    ],
)

# Configure Celery from settings
celery_app.conf.update(
    task_serializer=settings.CELERY_TASK_SERIALIZER,
    result_serializer=settings.CELERY_RESULT_SERIALIZER,
    accept_content=settings.CELERY_ACCEPT_CONTENT,
    timezone=settings.CELERY_TIMEZONE,
    task_track_started=settings.CELERY_TASK_TRACK_STARTED,
    task_time_limit=settings.CELERY_TASK_TIME_LIMIT,
    
    # Reliability settings
    task_acks_late=True,  # Acknowledge tasks after completion
    task_reject_on_worker_lost=True,  # Re-queue on worker failure
    worker_prefetch_multiplier=1,  # Fair task distribution
    
    # Rate limiting
    worker_max_tasks_per_child=1000,  # Recycle workers periodically
    
    # Result expiration
    result_expires=3600,  # Expire results after 1 hour
)

# Periodic tasks schedule (optional)
celery_app.conf.beat_schedule = {
    "cleanup-old-sessions": {
        "task": "app.tasks.wellness_tasks.cleanup_old_sessions",
        "schedule": crontab(hour=3, minute=0),  # Daily at 3 AM UTC
    },
    "health-check-services": {
        "task": "app.tasks.ai_tasks.health_check_ai_services",
        "schedule": crontab(minute="*/5"),  # Every 5 minutes
    },
}


class TaskRetry(Exception):
    """Custom exception to trigger task retry."""
    pass


class TaskFailure(Exception):
    """Custom exception for permanent task failure."""
    pass
