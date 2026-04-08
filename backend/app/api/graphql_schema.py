"""
GraphQL Schema for VitalPath AI Wellness Platform
Defines types, queries, mutations, and subscriptions
"""

graphql_schema = """
# VitalPath AI GraphQL Schema
# Wellness Coaching Platform with Safety-First AI

scalar DateTime
scalar JSON

# =============================================================================
# USER & PROFILE TYPES
# =============================================================================

type WellnessProfile {
  id: ID!
  userId: ID!
  displayName: String
  age: Int
  gender: String
  goals: JSON
  preferredLanguage: String!
  notificationEnabled: Boolean!
  reminderTime: String
  wellnessBoundariesAcknowledged: Boolean!
  createdAt: DateTime!
  updatedAt: DateTime!
  sessions(limit: Int = 10, offset: Int = 0): [WellnessSession!]!
  wearableConnections: [WearableConnection!]!
}

type WellnessSession {
  id: ID!
  profileId: ID!
  sessionType: String!
  safetyValidated: Boolean!
  safetyScore: Float
  crisisDetected: Boolean!
  crisisResourcesProvided: Boolean!
  fallbackLevel: Int!
  durationSeconds: Int
  createdAt: DateTime!
  profile: WellnessProfile!
}

type WearableConnection {
  id: ID!
  profileId: ID!
  provider: String!
  deviceName: String
  isConnected: Boolean!
  lastSyncAt: DateTime
  circuitState: String!
  failureCount: Int!
  permissions: JSON
  createdAt: DateTime!
  updatedAt: DateTime!
  profile: WellnessProfile!
}

# =============================================================================
# AI SESSION TYPES
# =============================================================================

enum SessionType {
  GENERAL
  NUTRITION
  FITNESS
  MINDFULNESS
  HABIT_COACHING
}

enum SafetyLevel {
  SAFE
  CAUTION
  CRISIS
  PROHIBITED
}

type WellnessResponse {
  response: String!
  fallbackLevel: Int!
  safetyValidated: Boolean!
  safetyLevel: SafetyLevel
  crisisDetected: Boolean!
  resourcesProvided: Boolean!
  cached: Boolean
  similarityScore: Float
  circuitState: String
  durationMs: Int
}

type CrisisResource {
  type: String!
  contact: String!
  language: String!
}

# =============================================================================
# WEARABLE DATA TYPES
# =============================================================================

enum WearableProvider {
  APPLE_HEALTH
  FITBIT
  GARMIN
  OURA
  WHOOP
}

input WearableContextInput {
  stepsAvg: Int
  sleepHours: Float
  heartRateAvg: Int
  activeMinutes: Int
}

# =============================================================================
# QUERY TYPE
# =============================================================================

type Query {
  # Get current user's wellness profile
  me: WellnessProfile
  
  # Get wellness profile by ID
  getProfile(id: ID!): WellnessProfile
  
  # Get wellness sessions with pagination
  getSessions(
    limit: Int = 20
    offset: Int = 0
    sessionType: SessionType
  ): [WellnessSession!]!
  
  # Get specific session by ID
  getSession(id: ID!): WellnessSession
  
  # Get wearable connections
  getWearableConnections: [WearableConnection!]!
  
  # Get crisis resources for language
  getCrisisResources(language: String = "en-US"): [CrisisResource!]!
  
  # Health check endpoint
  healthCheck: HealthStatus!
}

# =============================================================================
# MUTATION TYPE
# =============================================================================

input CreateProfileInput {
  displayName: String
  age: Int
  gender: String
  goals: JSON
  preferredLanguage: String = "en-US"
  notificationEnabled: Boolean = true
  reminderTime: String
}

input UpdateProfileInput {
  displayName: String
  age: Int
  gender: String
  goals: JSON
  preferredLanguage: String
  notificationEnabled: Boolean
  reminderTime: String
  wellnessBoundariesAcknowledged: Boolean
}

input WellnessQueryInput {
  userInput: String!
  sessionType: SessionType = GENERAL
  language: String = "en-US"
  wearableContext: WearableContextInput
}

input ConnectWearableInput {
  provider: WearableProvider!
  authCode: String!
  deviceName: String
}

type Mutation {
  # Create new wellness profile
  createProfile(input: CreateProfileInput!): WellnessProfile!
  
  # Update existing profile
  updateProfile(id: ID!, input: UpdateProfileInput!): WellnessProfile!
  
  # Delete profile (soft delete)
  deleteProfile(id: ID!): Boolean!
  
  # Send wellness query to AI
  sendWellnessQuery(input: WellnessQueryInput!): WellnessResponse!
  
  # Connect wearable device
  connectWearable(input: ConnectWearableInput!): WearableConnection!
  
  # Disconnect wearable device
  disconnectWearable(id: ID!): Boolean!
  
  # Trigger manual wearable sync
  syncWearable(id: ID!): Boolean!
  
  # Acknowledge wellness boundaries
  acknowledgeWellnessBoundaries: Boolean!
}

# =============================================================================
# SUBSCRIPTION TYPE
# =============================================================================

type Subscription {
  # Real-time wellness session updates
  sessionCreated(profileId: ID!): WellnessSession!
  
  # Wearable connection status changes
  wearableStatusChanged(profileId: ID!): WearableConnection!
  
  # Crisis alert notifications (for monitoring)
  crisisAlert: CrisisAlert!
}

type CrisisAlert {
  alertId: ID!
  timestamp: DateTime!
  resources: [CrisisResource!]!
  language: String!
}

# =============================================================================
# HEALTH CHECK TYPE
# =============================================================================

type HealthStatus {
  status: String!
  timestamp: DateTime!
  services: ServiceHealth!
}

type ServiceHealth {
  database: Boolean!
  redis: Boolean!
  chromadb: Boolean!
  aiService: String!  # closed, open, half_open
}

# =============================================================================
# FRAGMENTS (for efficient queries)
# =============================================================================

fragment ProfileFragment on WellnessProfile {
  id
  userId
  displayName
  age
  gender
  preferredLanguage
  notificationEnabled
  reminderTime
  wellnessBoundariesAcknowledged
  createdAt
  updatedAt
}

fragment SessionFragment on WellnessSession {
  id
  profileId
  sessionType
  safetyValidated
  safetyScore
  crisisDetected
  crisisResourcesProvided
  fallbackLevel
  createdAt
}

fragment WearableFragment on WearableConnection {
  id
  profileId
  provider
  deviceName
  isConnected
  lastSyncAt
  circuitState
  failureCount
  permissions
  createdAt
  updatedAt
}
"""
