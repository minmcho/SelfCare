//
//  index.ts - AI Wellness Session Edge Function
//  VitalPath - Wellness Coaching Platform
//
//  Supabase Edge Function for AI-powered wellness coaching
//  Implements safety validation, crisis detection, and fallback logic
//

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// MARK: - Types

interface WellnessRequest {
  input: string
  context?: string
  profileId: string
  provider?: 'primary' | 'fallback'
}

interface WellnessResponse {
  response: string
  categories: string[]
  crisisKeywords: string[]
  requiresCrisisResources: boolean
  confidenceScore: number
  provider: string
  latencyMs: number
  metadata?: Record<string, string>
}

interface SafetyValidation {
  isValid: boolean
  reason: string
  requiresCrisisResources: boolean
  detectedCategories: string[]
  blockedTopics: string[]
}

// MARK: - Wellness Boundary Rules (Server-Side)

const PROHIBITED_MEDICAL_TERMS = [
  // Diagnosis/Treatment claims
  'diagnose', 'diagnosis', 'diagnosed',
  'treat', 'treatment', 'treating',
  'cure', 'cures', 'curing', 'cured',
  'prescribe', 'prescription', 'prescribed',
  'medicate', 'medication', 'medications',
  
  // Disease prevention claims
  'prevent disease', 'prevents disease', 'disease prevention',
  'prevent cancer', 'prevents cancer',
  'prevent diabetes', 'prevents diabetes',
  'prevent heart disease', 'prevents heart disease',
  
  // Medical condition management
  'manage your condition', 'manage your disease',
  'control your diabetes', 'control your hypertension',
  'lower your blood pressure', 'reduce your cholesterol',
  
  // Symptom treatment claims
  'relieve symptoms of', 'treat symptoms of',
  'alleviate pain', 'pain relief', 'painkiller',
]

const CRISIS_KEYWORDS = [
  // Self-harm
  'suicide', 'suicidal', 'kill myself', 'end my life',
  'self harm', 'self-harm', 'cutting', 'hurt myself',
  
  // Severe depression
  'want to die', 'better off dead', 'no reason to live',
  'hopeless', 'desperate', "can't go on",
  
  // Violence
  'hurt someone', 'harm someone', 'violent',
  'attack', 'assault', 'weapon',
  
  // Emergency situations
  'emergency', 'urgent', 'immediate help',
  'crisis', 'breakdown', 'overdose',
]

const WELLNESS_TERMS = [
  'support', 'promote', 'encourage',
  'healthy habits', 'wellness', 'wellbeing',
  'lifestyle', 'balance', 'mindful',
  'nutrition', 'movement', 'activity',
  'rest', 'recovery', 'relaxation',
  'stress management', 'coping strategies',
  'self-care', 'healthy routine',
]

// MARK: - CORS Headers

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// MARK: - Safety Validation

function validateResponse(response: string): SafetyValidation {
  const lowercased = response.toLowerCase()
  
  // Check for prohibited medical claims
  for (const term of PROHIBITED_MEDICAL_TERMS) {
    if (lowercased.includes(term)) {
      // Check context to avoid false positives
      const medicalPatterns = [
        `you should ${term}`,
        `you need to ${term}`,
        `this will ${term}`,
        `i recommend ${term}`,
        `try to ${term}`,
      ]
      
      for (const pattern of medicalPatterns) {
        if (lowercased.includes(pattern)) {
          return {
            isValid: false,
            reason: 'Response contains prohibited medical claims',
            requiresCrisisResources: false,
            detectedCategories: [],
            blockedTopics: [],
          }
        }
      }
    }
  }
  
  // Check for crisis keywords
  const detectedCrisisKeywords: string[] = []
  for (const keyword of CRISIS_KEYWORDS) {
    if (lowercased.includes(keyword)) {
      detectedCrisisKeywords.push(keyword)
    }
  }
  
  if (detectedCrisisKeywords.length > 0) {
    return {
      isValid: true,
      reason: 'Crisis resources recommended',
      requiresCrisisResources: true,
      detectedCategories: ['crisis'],
      blockedTopics: [],
    }
  }
  
  // Check for wellness focus
  const hasWellnessLanguage = WELLNESS_TERMS.some(term => lowercased.includes(term))
  const medicalCommands = [
    'you must', 'you should see a doctor', 'you need medication',
    'prescription required', 'medical attention', 'seek medical',
  ]
  const hasMedicalCommand = medicalCommands.some(cmd => lowercased.includes(cmd))
  
  if (!hasWellnessLanguage && hasMedicalCommand) {
    return {
      isValid: false,
      reason: 'Response does not maintain appropriate wellness focus',
      requiresCrisisResources: false,
      detectedCategories: [],
      blockedTopics: [],
    }
  }
  
  return {
    isValid: true,
    reason: '',
    requiresCrisisResources: false,
    detectedCategories: [],
    blockedTopics: [],
  }
}

function detectCrisisKeywords(input: string): string[] {
  const lowercased = input.toLowerCase()
  const detected: string[] = []
  
  for (const keyword of CRISIS_KEYWORDS) {
    if (lowercased.includes(keyword)) {
      detected.push(keyword)
    }
  }
  
  return detected
}

function detectCategories(input: string): string[] {
  const lowercased = input.toLowerCase()
  const categories: string[] = []
  
  if (lowercased.includes('stress') || lowercased.includes('anxious') || lowercased.includes('overwhelmed')) {
    categories.push('stress')
  }
  if (lowercased.includes('sleep') || lowercased.includes('tired') || lowercased.includes('insomnia')) {
    categories.push('sleep')
  }
  if (lowercased.includes('eat') || lowercased.includes('food') || lowercased.includes('nutrition')) {
    categories.push('nutrition')
  }
  if (lowercased.includes('exercise') || lowercased.includes('workout') || lowercased.includes('activity')) {
    categories.push('exercise')
  }
  if (lowercased.includes('mindful') || lowercased.includes('meditate') || lowercased.includes('breathe')) {
    categories.push('mindfulness')
  }
  
  return categories.length > 0 ? categories : ['general']
}

// MARK: - AI Service Calls

async function callPrimaryAI(input: string, context?: string): Promise<string> {
  // Call CrewAI/OpenClaw agent hosted on Cloud Run/Fly.io
  // This is a placeholder - replace with actual AI service endpoint
  
  const aiEndpoint = Deno.env.get('AI_SERVICE_URL') || 'https://ai.vitalpath.app/wellness'
  const apiKey = Deno.env.get('AI_SERVICE_API_KEY')
  
  try {
    const response = await fetch(aiEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        input,
        context,
        max_tokens: 500,
        temperature: 0.7,
      }),
    })
    
    if (!response.ok) {
      throw new Error(`AI service error: ${response.status}`)
    }
    
    const data = await response.json()
    return data.response || data.message || data.text
  } catch (error) {
    console.error('Primary AI service failed:', error)
    throw error
  }
}

async function callFallbackAI(input: string): Promise<string> {
  // Simplified fallback AI (smaller model, faster response)
  const fallbackEndpoint = Deno.env.get('FALLBACK_AI_URL') || 'https://fallback.vitalpath.app/wellness'
  
  try {
    const response = await fetch(fallbackEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ input }),
    })
    
    if (!response.ok) {
      throw new Error(`Fallback AI error: ${response.status}`)
    }
    
    const data = await response.json()
    return data.response
  } catch {
    throw new Error('Fallback AI unavailable')
  }
}

function generateLocalResponse(input: string): string {
  // Pre-defined safe wellness responses based on intent
  const lowercased = input.toLowerCase()
  
  const safeResponses: Record<string, string> = {
    stress: 'Consider trying deep breathing exercises or a short walk. Small steps toward relaxation can make a big difference in your day.',
    sleep: 'Creating a consistent sleep schedule and limiting screen time before bed can support better rest. What\'s your current bedtime routine like?',
    nutrition: 'Balanced meals with plenty of vegetables and whole foods support overall wellness. Have you explored any new healthy recipes lately?',
    exercise: 'Regular movement, even just 10 minutes a day, can boost energy and mood. What types of activities do you enjoy?',
    mindfulness: 'Taking a few moments each day for mindful breathing can help center your thoughts. Would you like to try a quick breathing exercise?',
  }
  
  // Detect intent
  if (lowercased.includes('stress') || lowercased.includes('anxious')) {
    return safeResponses.stress
  }
  if (lowercased.includes('sleep') || lowercased.includes('tired')) {
    return safeResponses.sleep
  }
  if (lowercased.includes('eat') || lowercased.includes('food')) {
    return safeResponses.nutrition
  }
  if (lowercased.includes('exercise') || lowercased.includes('workout')) {
    return safeResponses.exercise
  }
  if (lowercased.includes('mindful') || lowercased.includes('meditate')) {
    return safeResponses.mindfulness
  }
  
  return 'Small, consistent steps toward wellness can make a meaningful difference. What area of wellness feels most important to you right now?'
}

// MARK: - Anonymization

function anonymizeInput(input: string): string {
  let anonymized = input
  
  // Remove phone numbers
  const phoneRegex = /(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g
  anonymized = anonymized.replace(phoneRegex, '[PHONE_REDACTED]')
  
  // Remove email addresses
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g
  anonymized = anonymized.replace(emailRegex, '[EMAIL_REDACTED]')
  
  // Remove medical IDs
  const medicalIdRegex = /\b[A-Z]{2,}\d{4,}\b/g
  anonymized = anonymized.replace(medicalIdRegex, '[ID_REDACTED]')
  
  return anonymized
}

// MARK: - Main Handler

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }
  
  // Only accept POST
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
  
  const startTime = Date.now()
  
  try {
    // Parse request
    const body: WellnessRequest = await req.json()
    const { input, context, profileId, provider = 'primary' } = body
    
    if (!input || !profileId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: input, profileId' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Verify auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Anonymize input (PRIVACY FIRST)
    const anonymizedInput = anonymizeInput(input)
    const anonymizedContext = context ? anonymizeInput(context) : undefined
    
    // Detect crisis keywords in input
    const crisisKeywords = detectCrisisKeywords(input)
    
    // If crisis detected, return resources immediately
    if (crisisKeywords.length > 0) {
      const latencyMs = Date.now() - startTime
      
      // Log crisis detection (minimal data for privacy)
      await supabase.from('wellness_sessions').insert({
        profile_id: profileId,
        user_input: '[CRISIS_DETECTED]',
        ai_response: '[CRISIS_RESOURCES_PROVIDED]',
        safety_validated: true,
        crisis_keywords_detected: crisisKeywords,
        crisis_resources_shown: true,
        ai_provider: 'crisis_escalation',
        is_fallback_response: false,
        response_latency_ms: latencyMs,
      })
      
      return new Response(
        JSON.stringify({
          response: 'It sounds like you\'re going through a difficult time. Please know that support is available.',
          categories: ['crisis'],
          crisisKeywords,
          requiresCrisisResources: true,
          confidenceScore: 1.0,
          provider: 'crisis_escalation',
          latencyMs,
          metadata: { action: 'show_crisis_resources' },
        } as WellnessResponse),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Execute fallback chain
    let aiResponse: string
    let usedProvider: string
    let isFallback = false
    let fallbackReason: string | undefined
    
    try {
      if (provider === 'primary') {
        aiResponse = await callPrimaryAI(anonymizedInput, anonymizedContext)
        usedProvider = 'primary'
      } else {
        aiResponse = await callFallbackAI(anonymizedInput)
        usedProvider = 'fallback'
        isFallback = true
      }
    } catch (primaryError) {
      console.error('Primary AI failed, trying fallback:', primaryError)
      
      try {
        aiResponse = await callFallbackAI(anonymizedInput)
        usedProvider = 'fallback'
        isFallback = true
        fallbackReason = 'primary_unavailable'
      } catch (fallbackError) {
        console.error('Fallback AI also failed, using local response:', fallbackError)
        aiResponse = generateLocalResponse(anonymizedInput)
        usedProvider = 'local'
        isFallback = true
        fallbackReason = 'all_services_unavailable'
      }
    }
    
    // Validate response (SAFETY FIRST)
    const validation = validateResponse(aiResponse)
    
    if (!validation.isValid) {
      // Generate safe fallback response
      aiResponse = generateLocalResponse(anonymizedInput)
      usedProvider = 'safety_override'
      isFallback = true
      fallbackReason = validation.reason
    }
    
    // Detect categories
    const categories = detectCategories(input)
    const latencyMs = Date.now() - startTime
    
    // Store session in database
    const { error: insertError } = await supabase.from('wellness_sessions').insert({
      profile_id: profileId,
      user_input: anonymizedInput,
      ai_response: aiResponse,
      anonymized_context: anonymizedContext,
      safety_validated: validation.isValid,
      detected_categories: categories,
      crisis_keywords_detected: crisisKeywords,
      crisis_resources_shown: validation.requiresCrisisResources,
      ai_provider: usedProvider,
      is_fallback_response: isFallback,
      fallback_reason: fallbackReason,
      response_latency_ms: latencyMs,
    })
    
    if (insertError) {
      console.error('Failed to store session:', insertError)
      // Don't fail the request, just log
    }
    
    // Build response
    const response: WellnessResponse = {
      response: aiResponse,
      categories,
      crisisKeywords,
      requiresCrisisResources: validation.requiresCrisisResources,
      confidenceScore: usedProvider === 'primary' ? 0.9 : 0.6,
      provider: usedProvider,
      latencyMs,
      metadata: fallbackReason ? { fallback_reason: fallbackReason } : undefined,
    }
    
    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('Edge function error:', error)
    
    // Return safe error response
    return new Response(
      JSON.stringify({
        error: 'Wellness service temporarily unavailable',
        response: generateLocalResponse(''),
        categories: ['general'],
        crisisKeywords: [],
        requiresCrisisResources: false,
        confidenceScore: 0.5,
        provider: 'error_fallback',
        latencyMs: 0,
      } as WellnessResponse),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
