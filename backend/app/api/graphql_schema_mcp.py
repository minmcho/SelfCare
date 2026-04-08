"""
GraphQL Schema with MCP Agent Integration
Extends previous schema with multi-modal capabilities and agent selection
"""
import strawberry
from typing import List, Optional, AsyncGenerator
from datetime import datetime
from enum import Enum

# Import from models and services
# from app.models.wellness_models import WellnessProfile, WellnessSession
# from app.agents.mcp_agents import MCPServer

class AgentType(Enum):
    LLAMA_4 = "llama-4"
    QWEN_3_5 = "qwen-3-5"
    AUTO = "auto"

class WellnessGoalCategory(Enum):
    NUTRITION = "nutrition"
    FITNESS = "fitness"
    MINDFULNESS = "mindfulness"
    SLEEP = "sleep"
    STRESS_MANAGEMENT = "stress_management"

@strawberry.type
class WellnessProfileType:
    id: strawberry.ID
    user_id: str
    name: str
    age: int
    wellness_goals: List[str]
    preferred_language: str
    created_at: datetime
    updated_at: datetime

@strawberry.type
class WellnessSessionType:
    id: strawberry.ID
    profile_id: str
    messages: List["MessageType"]
    agent_used: str
    safety_validated: bool
    crisis_detected: bool
    created_at: datetime
    ended_at: Optional[datetime] = None

@strawberry.type
class MessageType:
    id: strawberry.ID
    role: str
    content: str
    timestamp: datetime
    agent_model: Optional[str] = None
    resources: List["ResourceType"] = None

@strawberry.type
class ResourceType:
    uri: str
    mime_type: str
    description: str
    thumbnail_url: Optional[str] = None

@strawberry.type
class VideoAnalysisResult:
    session_id: str
    analysis_summary: str
    detected_activities: List[str]
    wellness_score: float
    language: str
    frame_count: int
    duration_seconds: float

@strawberry.type
class ImageAnalysisResult:
    session_id: str
    analysis: str
    detected_objects: List[str]
    wellness_relevance: float
    language: str

@strawberry.type
class CrisisResource:
    title: str
    description: str
    phone: str
    website: str
    language: str
    available_24_7: bool

@strawberry.input
class SendMessageInput:
    session_id: str
    content: str
    agent_type: Optional[AgentType] = None
    resource_uris: Optional[List[str]] = None

@strawberry.input
class UploadVideoInput:
    session_id: str
    video_url: str
    analysis_type: str = "wellness_activity"
    language: str = "en"

@strawberry.input
class UploadImageInput:
    session_id: str
    image_url: str
    prompt: str = "Analyze this wellness-related image"
    language: str = "en"

@strawberry.input
class CreateProfileInput:
    name: str
    age: int
    wellness_goals: List[str]
    preferred_language: str = "en"

@strawberry.type
class Query:
    @strawberry.field
    async def get_profile(self, profile_id: str) -> Optional[WellnessProfileType]:
        """Get wellness profile by ID"""
        # Resolver implementation
        return None
    
    @strawberry.field
    async def get_session(self, session_id: str) -> Optional[WellnessSessionType]:
        """Get wellness session by ID"""
        # Resolver implementation
        return None
    
    @strawberry.field
    async def get_active_sessions(self, profile_id: str) -> List[WellnessSessionType]:
        """Get all active sessions for a profile"""
        # Resolver implementation
        return []
    
    @strawberry.field
    async def get_crisis_resources(self, language: str = "en") -> List[CrisisResource]:
        """Get crisis resources for specified language"""
        resources = {
            "en": [
                CrisisResource(
                    title="National Suicide Prevention Lifeline",
                    description="24/7 crisis support",
                    phone="988",
                    website="https://988lifeline.org",
                    language="en",
                    available_24_7=True
                )
            ],
            "my": [
                CrisisResource(
                    title="Myanmar Mental Health Support",
                    description="အရေးပေါ် ကျန်းမာရေး အကူအညီ",
                    phone="+95-1-234-567",
                    website="https://mentalhealth.gov.mm",
                    language="my",
                    available_24_7=True
                )
            ],
            "th": [
                CrisisResource(
                    title="Thai Mental Health Hotline",
                    description="สายด่วนสุขภาพจิต",
                    phone="1323",
                    website="https://dmh.go.th",
                    language="th",
                    available_24_7=True
                )
            ],
            "zh": [
                CrisisResource(
                    title="中国心理援助热线",
                    description="24小时心理危机干预",
                    phone="400-161-9995",
                    website="https://www.psychline.cn",
                    language="zh",
                    available_24_7=True
                )
            ],
            "ja": [
                CrisisResource(
                    title="いのちの電話",
                    description="24時間対応のメンタルヘルスサポート",
                    phone="0120-783-556",
                    website="https://inochinodenwa.org",
                    language="ja",
                    available_24_7=True
                )
            ],
            "ko": [
                CrisisResource(
                    title="자살예방 상담전화",
                    description="24 시간 정신건강 상담",
                    phone="109",
                    website="https://spckorea.or.kr",
                    language="ko",
                    available_24_7=True
                )
            ]
        }
        return resources.get(language, resources["en"])

@strawberry.type
class Mutation:
    @strawberry.mutation
    async def create_wellness_profile(self, input: CreateProfileInput) -> WellnessProfileType:
        """Create a new wellness profile"""
        # Resolver implementation
        return WellnessProfileType(
            id="profile_123",
            user_id="user_456",
            name=input.name,
            age=input.age,
            wellness_goals=input.wellness_goals,
            preferred_language=input.preferred_language,
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
    
    @strawberry.mutation
    async def send_message(self, input: SendMessageInput) -> MessageType:
        """Send a message to the wellness AI agent"""
        # Route to appropriate agent (Llama 4 or Qwen 3.5)
        # Validate safety boundaries
        # Return response
        return MessageType(
            id="msg_789",
            role="assistant",
            content="Wellness response generated",
            timestamp=datetime.now(),
            agent_model="llama-4-70b-instruct"
        )
    
    @strawberry.mutation
    async def upload_video_for_analysis(self, input: UploadVideoInput) -> VideoAnalysisResult:
        """Upload video for AI-powered wellness activity analysis"""
        # Process through Qwen 3.5 VL agent
        # Extract frames and analyze
        return VideoAnalysisResult(
            session_id=input.session_id,
            analysis_summary="Video analysis complete",
            detected_activities=["walking", "stretching"],
            wellness_score=0.85,
            language=input.language,
            frame_count=30,
            duration_seconds=10.0
        )
    
    @strawberry.mutation
    async def upload_image_for_analysis(self, input: UploadImageInput) -> ImageAnalysisResult:
        """Upload image for AI-powered wellness analysis"""
        # Process through Qwen 3.5 VL agent
        return ImageAnalysisResult(
            session_id=input.session_id,
            analysis="Healthy meal detected",
            detected_objects=["vegetables", "protein", "grains"],
            wellness_relevance=0.92,
            language=input.language
        )
    
    @strawberry.mutation
    async def end_session(self, session_id: str) -> WellnessSessionType:
        """End a wellness coaching session"""
        # Mark session as ended
        # Save to database
        return WellnessSessionType(
            id=session_id,
            profile_id="profile_123",
            messages=[],
            agent_used="llama-4",
            safety_validated=True,
            crisis_detected=False,
            created_at=datetime.now(),
            ended_at=datetime.now()
        )

@strawberry.type
class Subscription:
    @strawberry.subscription
    async def session_updates(
        self, 
        session_id: str
    ) -> AsyncGenerator[MessageType, None]:
        """Subscribe to real-time session message updates"""
        # WebSocket subscription for live messages
        yield MessageType(
            id="msg_stream_1",
            role="assistant",
            content="Streaming response...",
            timestamp=datetime.now()
        )
    
    @strawberry.subscription
    async def crisis_alerts(
        self,
        profile_id: str
    ) -> AsyncGenerator[CrisisResource, None]:
        """Subscribe to crisis alert notifications"""
        # Push crisis resources if detected
        yield CrisisResource(
            title="Emergency Support",
            description="Immediate help available",
            phone="988",
            website="https://988lifeline.org",
            language="en",
            available_24_7=True
        )

# Schema definition
schema = strawberry.Schema(
    query=Query,
    mutation=Mutation,
    subscription=Subscription,
    extensions=[
        # Add authentication, logging extensions
    ]
)
