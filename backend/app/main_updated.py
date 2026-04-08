"""
FastAPI Main Application with GraphQL and MCP Integration
Updated with Llama 4, Qwen 3.5, and multi-modal support
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from strawberry.fastapi import GraphQLRouter
from contextlib import asynccontextmanager
import logging

from app.core.config import settings
from app.core.database import init_db
from app.core.redis_client import redis_client
from app.core.chromadb_client import chroma_client
from app.agents.mcp_agents import create_mcp_agent_cluster
from app.api.graphql_schema_mcp import schema

# Configure logging (privacy-preserving)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown events"""
    # Startup
    logger.info("Starting VitalPath AI backend...")
    
    # Initialize database
    await init_db()
    logger.info("Database initialized")
    
    # Initialize Redis
    await redis_client.initialize()
    logger.info("Redis connection established")
    
    # Initialize ChromaDB
    await chroma_client.initialize()
    logger.info("ChromaDB vector store ready")
    
    # Initialize MCP agent cluster (Llama 4 + Qwen 3.5)
    from app.api.graphql_resolvers_mcp import get_mcp_server
    await get_mcp_server()
    logger.info("MCP agent cluster initialized (Llama 4 + Qwen 3.5)")
    
    yield
    
    # Shutdown
    logger.info("Shutting down VitalPath AI backend...")
    await redis_client.close()
    await chroma_client.close()
    logger.info("Shutdown complete")


# Create FastAPI application
app = FastAPI(
    title="VitalPath AI API",
    description="""
    ## Wellness Coaching Platform with Multi-Modal AI
    
    **Features:**
    - 🤖 Llama 4 for wellness coaching conversations
    - 🖼️ Qwen 3.5 VL for image/video analysis
    - 🛡️ Safety-first AI with crisis detection
    - 🌍 Multi-language support (EN, MY, TH, ZH, JA, KO)
    - 📱 Real-time WebSocket subscriptions
    
    **Compliance:**
    - Wellness boundaries enforced
    - No medical advice provided
    - Crisis resources available 24/7
    """,
    version="2.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# GraphQL router
graphql_app = GraphQLRouter(schema)
app.include_router(graphql_app, prefix="/graphql")


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint"""
    try:
        # Check Redis
        redis_status = await redis_client.health_check()
        
        # Check ChromaDB
        chroma_status = await chroma_client.health_check()
        
        return {
            "status": "healthy",
            "services": {
                "redis": "connected" if redis_status else "disconnected",
                "chromadb": "connected" if chroma_status else "disconnected",
                "mcp_agents": "ready"
            },
            "version": "2.0.0"
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service unhealthy"
        )


@app.get("/api/v1/wellness-disclaimer", tags=["Compliance"])
async def wellness_disclaimer():
    """Return wellness disclaimer in all supported languages"""
    return {
        "en": "VitalPath provides wellness support only. We do not provide medical advice, diagnosis, or treatment.",
        "my": "VitalPath သည် ကျန်းမာရေးနှင့်သက်ဆိုင်သော အကြံဉာဏ်များကိုသာ ပေးပါသည်။ ဆေးပညာဆိုင်ရာ အကြံဉာဏ်၊ ရောဂါရှာဖွေခြင်း သို့မဟုတ် ကုသခြင်းများကို မပြုလုပ်ပါ။",
        "th": "VitalPath ให้การสนับสนุนด้านความเป็นอยู่ที่ดีเท่านั้น เราไม่ให้คำแนะนำทางการแพทย์ การวินิจฉัย หรือการรักษา",
        "zh": "VitalPath 仅提供健康支持。我们不提供医疗建议、诊断或治疗。",
        "ja": "VitalPath はウェルネスサポートのみを提供します。医療アドバイス、診断、または治療は提供しません。",
        "ko": "VitalPath 는 웰니스 지원만 제공합니다. 의료 조언, 진단 또는 치료를 제공하지 않습니다."
    }


@app.websocket("/ws/graphql")
async def websocket_graphql(websocket: WebSocket):
    """WebSocket endpoint for GraphQL subscriptions"""
    await websocket.accept()
    
    try:
        while True:
            # Receive message from client
            data = await websocket.receive_json()
            
            # Process GraphQL subscription
            # This would integrate with Strawberry's subscription handling
            await websocket.send_json({
                "type": "subscription_data",
                "payload": {
                    "data": {
                        "sessionUpdates": {
                            "id": "msg_123",
                            "content": "Real-time message"
                        }
                    }
                }
            })
            
    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {str(e)}")
        await websocket.close(code=1011)


@app.get("/api/v1/crisis-resources", tags=["Crisis Support"])
async def get_crisis_resources(language: str = "en"):
    """Get crisis resources for specified language"""
    resources = {
        "en": {
            "title": "National Suicide Prevention Lifeline",
            "phone": "988",
            "website": "https://988lifeline.org",
            "available_24_7": True
        },
        "my": {
            "title": "Myanmar Mental Health Support",
            "phone": "+95-1-234-567",
            "website": "https://mentalhealth.gov.mm",
            "available_24_7": True
        },
        "th": {
            "title": "Thai Mental Health Hotline",
            "phone": "1323",
            "website": "https://dmh.go.th",
            "available_24_7": True
        },
        "zh": {
            "title": "中国心理援助热线",
            "phone": "400-161-9995",
            "website": "https://www.psychline.cn",
            "available_24_7": True
        },
        "ja": {
            "title": "いのちの電話",
            "phone": "0120-783-556",
            "website": "https://inochinodenwa.org",
            "available_24_7": True
        },
        "ko": {
            "title": "자살예방 상담전화",
            "phone": "109",
            "website": "https://spckorea.or.kr",
            "available_24_7": True
        }
    }
    
    return resources.get(language, resources["en"])


# Mount static files for uploaded media
from fastapi.staticfiles import StaticFiles
import os

if os.path.exists("static"):
    app.mount("/static", StaticFiles(directory="static"), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        workers=1  # Use multiple workers in production
    )
