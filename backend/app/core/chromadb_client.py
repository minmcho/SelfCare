"""
ChromaDB Vector Store Integration
For semantic search and AI context retrieval
"""
import chromadb
from chromadb.config import Settings as ChromaSettings
from typing import List, Dict, Any, Optional
from app.core.config import get_settings

settings = get_settings()


class ChromaDBClient:
    """
    Thread-safe ChromaDB client for vector embeddings.
    Supports both persistent and in-memory modes.
    """
    
    def __init__(self):
        """Initialize ChromaDB client with configuration."""
        if settings.CHROMADB_PERSIST_DIR:
            # Persistent mode for production
            self.client = chromadb.PersistentClient(
                path=settings.CHROMADB_PERSIST_DIR,
                settings=ChromaSettings(
                    anonymized_telemetry=False,
                    allow_reset=True,
                )
            )
        else:
            # In-memory for testing
            self.client = chromadb.EphemeralClient()
        
        self.collection_name = settings.CHROMADB_COLLECTION
        self.collection = None
    
    def get_collection(self):
        """Get or create the wellness embeddings collection."""
        if self.collection is None:
            self.collection = self.client.get_or_create_collection(
                name=self.collection_name,
                metadata={
                    "description": "Wellness coaching session embeddings",
                    "hnsw:space": "cosine",  # Cosine similarity
                    "hnsw:construction_ef": 128,
                    "hnsw:search_ef": 64,
                    "hnsw:M": 16,
                }
            )
        return self.collection
    
    async def add_embedding(
        self,
        id: str,
        embedding: List[float],
        metadata: Dict[str, Any],
        document: Optional[str] = None,
    ):
        """
        Add embedding to the vector store.
        
        Args:
            id: Unique identifier for the embedding
            embedding: Vector embedding (list of floats)
            metadata: Associated metadata (user_id, session_id, etc.)
            document: Optional text document
        """
        collection = self.get_collection()
        collection.upsert(
            ids=[id],
            embeddings=[embedding],
            metadatas=[metadata],
            documents=[document] if document else None,
        )
    
    async def similarity_search(
        self,
        query_embedding: List[float],
        n_results: int = 5,
        filter_metadata: Optional[Dict[str, Any]] = None,
    ) -> List[Dict[str, Any]]:
        """
        Perform similarity search using vector embedding.
        
        Args:
            query_embedding: Query vector
            n_results: Number of results to return
            filter_metadata: Optional metadata filters
            
        Returns:
            List of matching documents with scores and metadata
        """
        collection = self.get_collection()
        
        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
            where=filter_metadata,
            include=["embeddings", "metadatas", "documents", "distances"],
        )
        
        # Format results
        formatted_results = []
        if results["ids"] and results["ids"][0]:
            for i, id in enumerate(results["ids"][0]):
                formatted_results.append({
                    "id": id,
                    "score": 1 - results["distances"][0][i] if results["distances"] else 0,  # Convert distance to similarity
                    "metadata": results["metadatas"][0][i] if results["metadatas"] else {},
                    "document": results["documents"][0][i] if results["documents"] else None,
                    "embedding": results["embeddings"][0][i] if results["embeddings"] else None,
                })
        
        return formatted_results
    
    async def delete_embedding(self, id: str):
        """Delete an embedding by ID."""
        collection = self.get_collection()
        collection.delete(ids=[id])
    
    async def health_check(self) -> bool:
        """Check if ChromaDB is healthy."""
        try:
            self.get_collection()
            return True
        except Exception:
            return False


# Global singleton instance
chroma_client = ChromaDBClient()
