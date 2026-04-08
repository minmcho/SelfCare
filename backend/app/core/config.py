"""
VitalPath AI - Backend Configuration
FastAPI + GraphQL + ChromaDB + Supabase + Redis + Celery
"""
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    # Application
    APP_NAME: str = "VitalPath AI"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    API_PREFIX: str = "/api/v1"
    
    # Supabase Configuration
    SUPABASE_URL: str
    SUPABASE_KEY: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    
    # PostgreSQL (Supabase)
    DATABASE_URL: str  # postgresql://user:pass@host:5432/dbname
    
    # Redis Configuration (for Celery broker & cache)
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    
    # ChromaDB Configuration (Vector Store)
    CHROMADB_HOST: str = "localhost"
    CHROMADB_PORT: int = 8000
    CHROMADB_COLLECTION: str = "wellness_embeddings"
    CHROMADB_PERSIST_DIR: Optional[str] = "./chroma_data"
    
    # Celery Configuration
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"
    CELERY_TASK_SERIALIZER: str = "json"
    CELERY_RESULT_SERIALIZER: str = "json"
    CELERY_ACCEPT_CONTENT: list = ["json"]
    CELERY_TIMEZONE: str = "UTC"
    CELERY_TASK_TRACK_STARTED: bool = True
    CELERY_TASK_TIME_LIMIT: int = 30 * 60  # 30 minutes max
    
    # AI/LLM Configuration
    LLM_PROVIDER: str = "openai"  # openai, anthropic, etc.
    LLM_API_KEY: str
    LLM_MODEL: str = "gpt-4o-mini"
    LLM_TEMPERATURE: float = 0.7
    LLM_MAX_TOKENS: int = 1024
    
    # Safety & Compliance
    SAFETY_MODEL_PATH: Optional[str] = None
    CRISIS_KEYWORDS_FILE: str = "./core/data/crisis_keywords.json"
    WELLNESS_BOUNDARIES_FILE: str = "./core/data/wellness_boundaries.json"
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_PER_HOUR: int = 1000
    
    # Monitoring
    SENTRY_DSN: Optional[str] = None
    LOG_LEVEL: str = "INFO"
    
    # File Storage (Supabase Storage)
    STORAGE_BUCKET: str = "wellness-content"
    MAX_FILE_SIZE_MB: int = 10
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
