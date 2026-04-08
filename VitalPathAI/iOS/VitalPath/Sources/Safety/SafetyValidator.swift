//
//  SafetyValidator.swift
//  VitalPath - Wellness Coaching Platform
//
//  Runtime safety validation for AI responses
//  Enforces wellness boundaries and crisis detection
//

import Foundation

// MARK: - Safety Validator Protocol
@MainActor
public protocol SafetyValidatorProtocol {
    func validateResponse(_ response: String) async -> ValidationResult
    func detectCrisisKeywords(_ input: String) async -> [String]
    func requiresCrisisResources(_ input: String) async -> Bool
}

// MARK: - Validation Result
public struct ValidationResult {
    public let isValid: Bool
    public let reason: String
    public let requiresCrisisResources: Bool
    public let detectedCategories: [String]
    public let blockedTopics: [String]
    
    public static let valid = ValidationResult(
        isValid: true,
        reason: "",
        requiresCrisisResources: false,
        detectedCategories: [],
        blockedTopics: []
    )
    
    public static func invalid(_ reason: String) -> ValidationResult {
        ValidationResult(
            isValid: false,
            reason: reason,
            requiresCrisisResources: false,
            detectedCategories: [],
            blockedTopics: []
        )
    }
    
    public static func crisis(_ categories: [String] = []) -> ValidationResult {
        ValidationResult(
            isValid: true, // Response is valid but needs crisis resources
            reason: "Crisis resources recommended",
            requiresCrisisResources: true,
            detectedCategories: categories,
            blockedTopics: []
        )
    }
}

// MARK: - Wellness Boundary Rules
/// CRITICAL: These rules enforce the wellness vs medical boundary
struct WellnessBoundaryRules {
    
    // MARK: - Prohibited Medical Claims
    /// Terms that indicate medical advice (must be blocked)
    static let prohibitedMedicalTerms = [
        // Diagnosis/Treatment claims
        "diagnose", "diagnosis", "diagnosed",
        "treat", "treatment", "treating",
        "cure", "cures", "curing", "cured",
        "prescribe", "prescription", "prescribed",
        "medicate", "medication", "medications",
        
        // Disease prevention claims
        "prevent disease", "prevents disease", "disease prevention",
        "prevent cancer", "prevents cancer",
        "prevent diabetes", "prevents diabetes",
        "prevent heart disease", "prevents heart disease",
        
        // Medical condition management
        "manage your condition", "manage your disease",
        "control your diabetes", "control your hypertension",
        "lower your blood pressure", "reduce your cholesterol",
        
        // Symptom treatment claims
        "relieve symptoms of", "treat symptoms of",
        "alleviate pain", "pain relief", "painkiller",
        
        // Medical testing
        "get tested for", "medical test", "lab test",
        "blood work", "biopsy", "scan results"
    ]
    
    // MARK: - Allowed Wellness Language
    /// Acceptable wellness-focused terminology
    static let allowedWellnessTerms = [
        "support", "promote", "encourage",
        "healthy habits", "wellness", "wellbeing",
        "lifestyle", "balance", "mindful",
        "nutrition", "movement", "activity",
        "rest", "recovery", "relaxation",
        "stress management", "coping strategies",
        "self-care", "healthy routine",
        "energy", "vitality", "resilience"
    ]
    
    // MARK: - Crisis Keywords
    /// Keywords that trigger crisis resource escalation
    static let crisisKeywords = [
        // Self-harm
        "suicide", "suicidal", "kill myself", "end my life",
        "self harm", "self-harm", "cutting", "hurt myself",
        
        // Severe depression
        "want to die", "better off dead", "no reason to live",
        "hopeless", "desperate", "can't go on",
        
        // Violence
        "hurt someone", "harm someone", "violent",
        "attack", "assault", "weapon",
        
        // Emergency situations
        "emergency", "urgent", "immediate help",
        "crisis", "breakdown", "overdose",
        
        // Eating disorders (severe)
        "starving", "purge", "binge and purge",
        "haven't eaten", "refusing to eat"
    ]
    
    // MARK: - Excluded Topics (User-Configurable)
    /// Topics that users can choose to avoid
    static let defaultExcludedTopics = [
        "politics", "religion", "controversial",
        "weight loss", "dieting", "calories",
        "supplements", "drugs", "substances"
    ]
}

// MARK: - Safety Validator Implementation
@MainActor
public final class SafetyValidator: SafetyValidatorProtocol {
    
    private let userExcludedTopics: Set<String>
    private let crisisResourceLocale: String
    
    public init(
        userExcludedTopics: [String] = [],
        crisisResourceLocale: String = "US"
    ) {
        self.userExcludedTopics = Set(userExcludedTopics.map { $0.lowercased() })
        self.crisisResourceLocale = crisisResourceLocale
    }
    
    // MARK: - Primary Validation Method
    
    public func validateResponse(_ response: String) async -> ValidationResult {
        let lowercasedResponse = response.lowercased()
        
        // Check 1: Prohibited medical claims
        if containsProhibitedMedicalClaims(lowercasedResponse) {
            return .invalid("Response contains prohibited medical claims. VitalPath provides wellness guidance only, not medical advice.")
        }
        
        // Check 2: User-excluded topics
        if let excludedTopic = containsExcludedTopic(lowercasedResponse) {
            return .invalid("Response touches on excluded topic: \(excludedTopic)")
        }
        
        // Check 3: Crisis keyword detection
        let crisisKeywords = await detectCrisisKeywords(response)
        if !crisisKeywords.isEmpty {
            return .crisis(crisisKeywords)
        }
        
        // Check 4: Wellness boundary compliance
        if !isWellnessFocused(lowercasedResponse) {
            return .invalid("Response does not maintain appropriate wellness focus")
        }
        
        // All checks passed
        return .valid
    }
    
    // MARK: - Crisis Detection
    
    public func detectCrisisKeywords(_ input: String) async -> [String] {
        let lowercased = input.lowercased()
        var detected: [String] = []
        
        for keyword in WellnessBoundaryRules.crisisKeywords {
            if lowercased.contains(keyword) {
                detected.append(keyword)
            }
        }
        
        return detected
    }
    
    public func requiresCrisisResources(_ input: String) async -> Bool {
        let keywords = await detectCrisisKeywords(input)
        return !keywords.isEmpty
    }
    
    // MARK: - Medical Claim Detection
    
    private func containsProhibitedMedicalClaims(_ response: String) -> Bool {
        for term in WellnessBoundaryRules.prohibitedMedicalTerms {
            if response.contains(term) {
                // Additional context check to avoid false positives
                if isMedicalContext(term, in: response) {
                    return true
                }
            }
        }
        return false
    }
    
    private func isMedicalContext(_ term: String, in response: String) -> Bool {
        // Check if term is used in medical advice context vs general discussion
        let medicalContextPatterns = [
            "you should \(term)",
            "you need to \(term)",
            "this will \(term)",
            "I recommend \(term)",
            "try to \(term)",
            "helps \(term)",
            "can \(term)"
        ]
        
        for pattern in medicalContextPatterns {
            if response.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Excluded Topic Detection
    
    private func containsExcludedTopic(_ response: String) -> String? {
        for topic in userExcludedTopics {
            if response.contains(topic) {
                return topic
            }
        }
        return nil
    }
    
    // MARK: - Wellness Focus Validation
    
    private func isWellnessFocused(_ response: String) -> Bool {
        // Check if response uses wellness-appropriate language
        let hasWellnessLanguage = WellnessBoundaryRules.allowedWellnessTerms.contains {
            response.contains($0)
        }
        
        // Check for imperative medical commands
        let medicalCommands = [
            "you must", "you should see a doctor", "you need medication",
            "prescription required", "medical attention", "seek medical"
        ]
        
        let hasMedicalCommand = medicalCommands.contains {
            response.contains($0)
        }
        
        // Valid if has wellness language and no medical commands
        return hasWellnessLanguage && !hasMedicalCommand
    }
    
    // MARK: - Crisis Resource URLs
    
    public func getCrisisResourceURL() -> URL? {
        switch crisisResourceLocale {
        case "US":
            return URL(string: "https://988lifeline.org")
        case "UK":
            return URL(string: "https://www.samaritans.org")
        case "CA":
            return URL(string: "https://www.crisisservicescanada.ca")
        case "AU":
            return URL(string: "https://www.lifeline.org.au")
        case "MM": // Myanmar
            return URL(string: "https://www.befrienders.org")
        case "TH": // Thailand
            return URL(string: "https://www.thailifeline.org")
        case "CN": // China
            return URL(string: "https://www.beijinglifeline.org.cn")
        case "JP": // Japan
            return URL(string: "https://www.inochinowa.or.jp")
        case "KR": // Korea
            return URL(string: "https://www.selfharm.or.kr")
        default:
            return URL(string: "https://www.befrienders.org")
        }
    }
    
    // MARK: - Crisis Resources by Locale
    
    public func getCrisisResources() -> CrisisResources {
        switch crisisResourceLocale {
        case "US":
            return CrisisResources(
                hotline: "988",
                textLine: "Text HOME to 741741",
                website: "https://988lifeline.org",
                description: "Suicide & Crisis Lifeline - Available 24/7"
            )
        case "UK":
            return CrisisResources(
                hotline: "116 123",
                textLine: "Text SHOUT to 85258",
                website: "https://www.samaritans.org",
                description: "Samaritans - Available 24/7"
            )
        case "MM":
            return CrisisResources(
                hotline: "Available via website",
                textLine: "",
                website: "https://www.befrienders.org",
                description: "Befrienders Worldwide - Myanmar services"
            )
        case "TH":
            return CrisisResources(
                hotline: "1323",
                textLine: "",
                website: "https://www.thailifeline.org",
                description: "Thai Lifeline - Available 24/7"
            )
        case "CN":
            return CrisisResources(
                hotline: "400-161-9995",
                textLine: "",
                website: "https://www.beijinglifeline.org.cn",
                description: "Beijing Lifeline - Mandarin support"
            )
        case "JP":
            return CrisisResources(
                hotline: "0120-783-556",
                textLine: "",
                website: "https://www.inochinowa.or.jp",
                description: "Inochi no Wa - Japanese support"
            )
        case "KR":
            return CrisisResources(
                hotline: "109",
                textLine: "",
                website: "https://www.selfharm.or.kr",
                description: "Korea Suicide Prevention Center"
            )
        default:
            return CrisisResources(
                hotline: "See website",
                textLine: "",
                website: "https://www.befrienders.org",
                description: "International suicide prevention helplines"
            )
        }
    }
}

// MARK: - Crisis Resources Model
public struct CrisisResources {
    public let hotline: String
    public let textLine: String
    public let website: String
    public let description: String
}

// MARK: - Input Sanitizer
/// Additional layer for sanitizing user input before AI processing
public struct InputSanitizer {
    
    /// Remove PHI from user input before sending to AI
    public static func sanitize(_ input: String) -> String {
        var sanitized = input
        
        // Remove phone numbers
        sanitized = sanitized.replacingOccurrences(
            of: #"(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#,
            with: "[PHONE]",
            options: .regularExpression
        )
        
        // Remove email addresses
        sanitized = sanitized.replacingOccurrences(
            of: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            with: "[EMAIL]",
            options: .regularExpression
        )
        
        // Remove potential medical record numbers
        sanitized = sanitized.replacingOccurrences(
            of: #"\b(MRN|MRN#|Patient ID)\s*[:\-]?\s*[A-Z0-9]{6,}\b"#,
            with: "[MEDICAL_ID]",
            options: .caseInsensitive
        )
        
        // Remove specific dates (potential DOB)
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{1,2}/\d{1,2}/\d{2,4}\b"#,
            with: "[DATE]",
            options: .regularExpression
        )
        
        return sanitized
    }
    
    /// Detect if input contains potential PHI
    public static func containsPHI(_ input: String) -> Bool {
        let patterns = [
            #"(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, // Phone
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, // Email
            #"\b\d{3}-\d{2}-\d{4}\b"#, // SSN
            #"\b[A-Z]{2,}\d{4,}\b"#, // Medical IDs
        ]
        
        for pattern in patterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
}
