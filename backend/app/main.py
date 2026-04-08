"""
VitalPath AI - Main FastAPI Application
Wellness Coaching Platform with GraphQL API
"""
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from ariadne.asgi import GraphQL

from app.core.config import get_settings
from app.core.database import init_db, close_db
from app.core.redis_client import redis_client
from app.core.chromadb_client import chroma_client
from app.services.wellness_ai_service import wellness_ai_service
from app.api.graphql_schema import graphql_schema
from app.api.graphql_resolvers import query, mutation, subscription


settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown events."""
    # Startup
    print(f"🚀 Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    
    try:
        # Initialize database (development only)
        if settings.DEBUG:
            await init_db()
        
        # Connect to Redis
        await redis_client.connect()
        print("✅ Redis connected")
        
        # Verify ChromaDB
        if await chroma_client.health_check():
            print("✅ ChromaDB ready")
        
        print("✅ Application startup complete")
        
    except Exception as e:
        print(f"❌ Startup error: {e}")
        raise
    
    yield  # Application runs here
    
    # Shutdown
    print("🛑 Shutting down application...")
    
    await wellness_ai_service.close()
    await redis_client.close()
    await close_db()
    
    print("✅ Shutdown complete")


# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="AI-powered wellness coaching platform with safety-first design",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "ios://vitalpath",  # iOS app
        "http://localhost:3000",  # Local development
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Custom exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for unhandled errors."""
    # Log error (structured, no PHI)
    print(f"ERROR [{request.method} {request.url.path}]: {type(exc).__name__}")
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": "An unexpected error occurred. Please try again." if not settings.DEBUG else str(exc),
        },
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """Simple health check endpoint."""
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
    }


# GraphQL endpoint
graphql_app = GraphQL(
    schema=graphql_schema,
    root_value={"query": query, "mutation": mutation, "subscription": subscription},
    context_value=lambda request: {
        "user_id": request.headers.get("X-User-ID"),  # From Supabase Auth
        "request": request,
    },
)

app.add_route("/graphql", graphql_app)
app.add_websocket_route("/graphql", graphql_app)


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "description": "AI-powered wellness coaching platform",
        "endpoints": {
            "graphql": "/graphql",
            "health": "/health",
        },
        "safety_first": True,
        "wellness_boundaries": True,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
    )
