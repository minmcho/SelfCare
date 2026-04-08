"""
Redis Client for Caching and Rate Limiting
Used by Celery broker and application-level caching
"""
import redis.asyncio as redis
from typing import Optional, Any
import json
from app.core.config import get_settings

settings = get_settings()


class RedisClient:
    """
    Async Redis client for caching, rate limiting, and session management.
    """
    
    def __init__(self):
        """Initialize Redis connection pool."""
        self.pool = redis.ConnectionPool.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=50,
        )
        self.client: Optional[redis.Redis] = None
    
    async def connect(self):
        """Establish Redis connection."""
        if not self.client:
            self.client = redis.Redis(connection_pool=self.pool)
    
    async def close(self):
        """Close Redis connection."""
        if self.client:
            await self.client.close()
            self.client = None
    
    async def get(self, key: str) -> Optional[str]:
        """Get value from Redis."""
        if not self.client:
            await self.connect()
        return await self.client.get(key)
    
    async def set(
        self,
        key: str,
        value: Any,
        expire_seconds: Optional[int] = None,
    ):
        """Set value in Redis with optional expiration."""
        if not self.client:
            await self.connect()
        
        # Serialize complex types to JSON
        if isinstance(value, (dict, list)):
            value = json.dumps(value)
        
        await self.client.set(key, value, ex=expire_seconds)
    
    async def delete(self, key: str) -> bool:
        """Delete key from Redis."""
        if not self.client:
            await self.connect()
        return await self.client.delete(key) > 0
    
    async def exists(self, key: str) -> bool:
        """Check if key exists."""
        if not self.client:
            await self.connect()
        return await self.client.exists(key) > 0
    
    async def incr(self, key: str, expire_seconds: Optional[int] = None) -> int:
        """
        Increment counter with optional expiration.
        Used for rate limiting.
        """
        if not self.client:
            await self.connect()
        
        value = await self.client.incr(key)
        
        # Set expiration on first increment
        if value == 1 and expire_seconds:
            await self.client.expire(key, expire_seconds)
        
        return value
    
    async def get_json(self, key: str) -> Optional[Any]:
        """Get and deserialize JSON value."""
        data = await self.get(key)
        if data:
            try:
                return json.loads(data)
            except json.JSONDecodeError:
                return data
        return None
    
    async def set_json(
        self,
        key: str,
        value: Any,
        expire_seconds: Optional[int] = None,
    ):
        """Serialize and set JSON value."""
        await self.set(key, json.dumps(value), expire_seconds)
    
    # Rate limiting helpers
    async def check_rate_limit(
        self,
        identifier: str,
        limit: int,
        window_seconds: int,
    ) -> tuple[bool, int]:
        """
        Check if request is within rate limit.
        
        Args:
            identifier: User ID or IP address
            limit: Maximum requests per window
            window_seconds: Time window in seconds
            
        Returns:
            (allowed: bool, remaining: int)
        """
        key = f"rate_limit:{identifier}:{window_seconds}"
        current = await self.incr(key, window_seconds)
        remaining = max(0, limit - current)
        allowed = current <= limit
        return allowed, remaining
    
    async def health_check(self) -> bool:
        """Check Redis connectivity."""
        try:
            if not self.client:
                await self.connect()
            await self.client.ping()
            return True
        except Exception:
            return False


# Global singleton instance
redis_client = RedisClient()
