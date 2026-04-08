--
--  pgvector_setup.sql
--  VitalPath - Wellness Coaching Platform
--
--  PostgreSQL setup for vector similarity search using pgvector
--  Enables semantic caching and personalized wellness recommendations
--

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- TABLES
-- ============================================================================

-- Wellness sessions table with vector embedding for semantic search
CREATE TABLE IF NOT EXISTS wellness_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES wellness_profiles(id) ON DELETE CASCADE,
    
    -- Content (anonymized)
    user_input TEXT NOT NULL,
    ai_response TEXT NOT NULL,
    anonymized_context TEXT,
    
    -- Safety metadata
    safety_validated BOOLEAN NOT NULL DEFAULT false,
    detected_categories TEXT[] DEFAULT '{}',
    crisis_keywords_detected TEXT[] DEFAULT '{}',
    crisis_resources_shown BOOLEAN NOT NULL DEFAULT false,
    
    -- AI service metadata
    ai_provider TEXT NOT NULL,
    is_fallback_response BOOLEAN NOT NULL DEFAULT false,
    fallback_reason TEXT,
    response_latency_ms INTEGER,
    
    -- Vector embedding for semantic search (768 dimensions for common models)
    -- Using 384 for smaller footprint, adjust based on your embedding model
    input_embedding vector(384),
    response_embedding vector(384),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Indexes will be added separately for performance
    CONSTRAINT valid_latency CHECK (response_latency_ms IS NULL OR response_latency_ms >= 0)
);

-- Wellness profiles table
CREATE TABLE IF NOT EXISTS wellness_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    anonymized_user_id TEXT NOT NULL UNIQUE,
    
    -- Wellness data
    wellness_goals TEXT[] DEFAULT '{}',
    activity_level TEXT NOT NULL DEFAULT 'moderate',
    dietary_preferences TEXT[] DEFAULT '{}',
    excluded_topics TEXT[] DEFAULT '{}',
    crisis_resource_locale TEXT NOT NULL DEFAULT 'US',
    
    -- Wearable connection
    wearable_connection_id UUID REFERENCES wearable_connections(id),
    
    -- Sync tracking
    last_synced_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Wearable connections table
CREATE TABLE IF NOT EXISTS wearable_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES wellness_profiles(id) ON DELETE CASCADE,
    device_type TEXT NOT NULL,
    device_id TEXT NOT NULL,
    is_connected BOOLEAN NOT NULL DEFAULT false,
    last_sync_at TIMESTAMPTZ,
    
    -- Permissions
    steps_permission BOOLEAN NOT NULL DEFAULT false,
    heart_rate_permission BOOLEAN NOT NULL DEFAULT false,
    sleep_permission BOOLEAN NOT NULL DEFAULT false,
    activity_minutes_permission BOOLEAN NOT NULL DEFAULT false,
    
    -- Aggregated metrics
    avg_daily_steps INTEGER,
    avg_weekly_active_minutes INTEGER,
    sleep_quality_score INTEGER CHECK (sleep_quality_score IS NULL OR (sleep_quality_score >= 1 AND sleep_quality_score <= 10)),
    
    -- Sync status
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT true,
    sync_interval_minutes INTEGER NOT NULL DEFAULT 30,
    last_sync_error TEXT,
    consecutive_sync_failures INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- HNSW index for fast vector similarity search (pgvector 0.5+)
-- This provides O(log n) search performance for semantic caching
CREATE INDEX IF NOT EXISTS wellness_sessions_input_embedding_idx 
ON wellness_sessions 
USING hnsw (input_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Secondary index for response embeddings
CREATE INDEX IF NOT EXISTS wellness_sessions_response_embedding_idx 
ON wellness_sessions 
USING hnsw (response_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Standard indexes for common queries
CREATE INDEX IF NOT EXISTS wellness_sessions_profile_id_idx ON wellness_sessions(profile_id);
CREATE INDEX IF NOT EXISTS wellness_sessions_created_at_idx ON wellness_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS wellness_sessions_safety_validated_idx ON wellness_sessions(safety_validated);
CREATE INDEX IF NOT EXISTS wellness_sessions_crisis_shown_idx ON wellness_sessions(crisis_resources_shown);

-- Composite index for user session history
CREATE INDEX IF NOT EXISTS wellness_sessions_profile_created_idx 
ON wellness_sessions(profile_id, created_at DESC);

-- GIN index for array columns (categories, crisis keywords)
CREATE INDEX IF NOT EXISTS wellness_sessions_detected_categories_idx 
ON wellness_sessions USING GIN (detected_categories);

CREATE INDEX IF NOT EXISTS wellness_sessions_crisis_keywords_idx 
ON wellness_sessions USING GIN (crisis_keywords_detected);

-- Profile indexes
CREATE INDEX IF NOT EXISTS wellness_profiles_user_id_idx ON wellness_profiles(user_id);
CREATE INDEX IF NOT EXISTS wellness_profiles_anonymized_id_idx ON wellness_profiles(anonymized_user_id);

-- Wearable connection indexes
CREATE INDEX IF NOT EXISTS wearable_connections_profile_id_idx ON wearable_connections(profile_id);
CREATE INDEX IF NOT EXISTS wearable_connections_device_type_idx ON wearable_connections(device_type);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to find similar sessions by input embedding
-- Returns top K semantically similar sessions for caching
CREATE OR REPLACE FUNCTION find_similar_sessions(
    query_embedding vector(384),
    match_threshold FLOAT DEFAULT 0.8,
    match_count INT DEFAULT 5,
    filter_profile_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_input TEXT,
    ai_response TEXT,
    similarity FLOAT,
    detected_categories TEXT[],
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ws.id,
        ws.user_input,
        ws.ai_response,
        1 - (ws.input_embedding <=> query_embedding) AS similarity,
        ws.detected_categories,
        ws.created_at
    FROM wellness_sessions ws
    WHERE 
        -- Apply profile filter if provided
        (filter_profile_id IS NULL OR ws.profile_id = filter_profile_id)
        -- Only include validated sessions
        AND ws.safety_validated = true
        -- Exclude crisis sessions from cache
        AND ws.crisis_resources_shown = false
        -- Similarity threshold
        AND 1 - (ws.input_embedding <=> query_embedding) > match_threshold
    ORDER BY ws.input_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to find similar sessions by text (with automatic embedding generation)
-- Note: In production, generate embeddings in your application or via Edge Function
CREATE OR REPLACE FUNCTION find_similar_sessions_by_text(
    query_text TEXT,
    match_threshold FLOAT DEFAULT 0.8,
    match_count INT DEFAULT 5,
    filter_profile_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_input TEXT,
    ai_response TEXT,
    similarity FLOAT,
    detected_categories TEXT[],
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    query_emb vector(384);
BEGIN
    -- Generate embedding for query text
    -- In production, call your embedding service (OpenAI, Cohere, etc.)
    -- This is a placeholder - replace with actual embedding generation
    query_emb := NULL; -- TODO: Call embedding API
    
    RETURN QUERY
    SELECT * FROM find_similar_sessions(
        query_emb,
        match_threshold,
        match_count,
        filter_profile_id
    );
END;
$$;

-- Function to get wellness session statistics for a profile
CREATE OR REPLACE FUNCTION get_wellness_stats(profile_uuid UUID)
RETURNS TABLE (
    total_sessions BIGINT,
    validated_sessions BIGINT,
    crisis_sessions BIGINT,
    fallback_sessions BIGINT,
    avg_response_latency_ms DOUBLE PRECISION,
    most_common_categories TEXT[],
    last_session_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) AS total_sessions,
        COUNT(*) FILTER (WHERE safety_validated = true) AS validated_sessions,
        COUNT(*) FILTER (WHERE crisis_resources_shown = true) AS crisis_sessions,
        COUNT(*) FILTER (WHERE is_fallback_response = true) AS fallback_sessions,
        AVG(response_latency_ms)::DOUBLE PRECISION AS avg_response_latency_ms,
        -- Get top 5 most common categories
        (
            SELECT ARRAY_AGG(category ORDER BY cnt DESC LIMIT 5)
            FROM (
                SELECT UNNEST(detected_categories) AS category, COUNT(*) AS cnt
                FROM wellness_sessions
                WHERE profile_id = profile_uuid
                GROUP BY UNNEST(detected_categories)
            ) subq
        ) AS most_common_categories,
        MAX(created_at) AS last_session_at
    FROM wellness_sessions
    WHERE profile_id = profile_uuid;
END;
$$;

-- Function to clean up old sessions (for data retention policy)
CREATE OR REPLACE FUNCTION cleanup_old_sessions(
    older_than_days INT DEFAULT 90,
    keep_min_sessions INT DEFAULT 50
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete sessions older than specified days, but keep minimum per profile
    WITH sessions_to_delete AS (
        SELECT id
        FROM wellness_sessions
        WHERE created_at < NOW() - (older_than_days || ' days')::INTERVAL
        AND profile_id IN (
            SELECT profile_id
            FROM wellness_sessions
            GROUP BY profile_id
            HAVING COUNT(*) > keep_min_sessions
        )
    )
    DELETE FROM wellness_sessions
    WHERE id IN (SELECT id FROM sessions_to_delete)
    RETURNING 1
    INTO deleted_count;
    
    RETURN COALESCE(deleted_count, 0);
END;
$$;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE wellness_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wellness_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wearable_connections ENABLE ROW LEVEL SECURITY;

-- Wellness sessions policies
CREATE POLICY "Users can view their own sessions"
ON wellness_sessions FOR SELECT
USING (
    profile_id IN (
        SELECT id FROM wellness_profiles 
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can insert their own sessions"
ON wellness_sessions FOR INSERT
WITH CHECK (
    profile_id IN (
        SELECT id FROM wellness_profiles 
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Service role can manage all sessions"
ON wellness_sessions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Wellness profiles policies
CREATE POLICY "Users can view their own profile"
ON wellness_profiles FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Users can update their own profile"
ON wellness_profiles FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Service role can manage all profiles"
ON wellness_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Wearable connections policies
CREATE POLICY "Users can view their own wearable connections"
ON wearable_connections FOR SELECT
USING (
    profile_id IN (
        SELECT id FROM wellness_profiles 
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can manage their own wearable connections"
ON wearable_connections FOR ALL
USING (
    profile_id IN (
        SELECT id FROM wellness_profiles 
        WHERE user_id = auth.uid()
    )
)
WITH CHECK (
    profile_id IN (
        SELECT id FROM wellness_profiles 
        WHERE user_id = auth.uid()
    )
);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wellness_sessions_updated_at
    BEFORE UPDATE ON wellness_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER wellness_profiles_updated_at
    BEFORE UPDATE ON wellness_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER wearable_connections_updated_at
    BEFORE UPDATE ON wearable_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SEED DATA (Development Only)
-- ============================================================================

-- Uncomment for development/testing
-- INSERT INTO wellness_profiles (user_id, anonymized_user_id, wellness_goals, activity_level)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000001', 'anon_user_1', '{"Better Sleep", "Stress Management"}', 'moderate'),
--     ('00000000-0000-0000-0000-000000000002', 'anon_user_2', '{"Nutrition", "Exercise"}', 'active');
