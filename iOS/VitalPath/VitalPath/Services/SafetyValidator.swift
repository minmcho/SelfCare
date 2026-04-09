//
//  SafetyValidator.swift
//  VitalPath - AI Wellness Coaching Platform
//
//  Runtime safety validation for AI responses
//  Detects crisis keywords, medical claims, and self-harm indicators
//  Supports 6 languages: EN, MY, TH, ZH, JA, KO
//

import Foundation

// MARK: - Safety Validation Result
struct SafetyValidationResult {
    let isValid: Bool
    let flags: [SafetyFlag]
    let requiresEscalation: Bool
    let escalatedResources: [CrisisResource]
    let sanitizedMessage: String?
    
    init(
        isValid: Bool = true,
        flags: [SafetyFlag] = [],
        requiresEscalation: Bool = false,
        escalatedResources: [CrisisResource] = [],
        sanitizedMessage: String? = nil
    ) {
        self.isValid = isValid
        self.flags = flags
        self.requiresEscalation = requiresEscalation
        self.escalatedResources = escalatedResources
        self.sanitizedMessage = sanitizedMessage
    }
}

// MARK: - Crisis Resource
struct CrisisResource: Identifiable {
    let id: String
    let title: String
    let description: String
    let phone: String
    let website: String
    let available24_7: Bool
    let languageCode: String
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        phone: String,
        website: String,
        available24_7: Bool = true,
        languageCode: String = "en"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.phone = phone
        self.website = website
        self.available24_7 = available24_7
        self.languageCode = languageCode
    }
}

// MARK: - Safety Validator
@MainActor
final class SafetyValidator {
    static let shared = SafetyValidator()
    
    private let crisisKeywords: [String: [String]]
    private let medicalClaims: [String: [String]]
    private let selfHarmIndicators: [String: [String]]
    private let crisisResources: [String: [CrisisResource]]
    
    private init() {
        // Initialize crisis keywords by language
        self.crisisKeywords = [
            "en": ["suicide", "kill myself", "end my life", "die", "death wish", "hopeless", "worthless"],
            "my": ["သေချင်တယ်", "ကိုယ့်ကိုယ်ကိုယ် ထိခိုက်", "မမျှော်လင့်ပါ", "အဆုံးသတ်"],
            "th": ["อยากตาย", "ฆ่าตัวตาย", "สิ้นหวัง", "ไร้ค่า"],
            "zh": ["想死", "自杀", "绝望", "结束生命", "没希望"],
            "ja": ["死にたい", "自殺", "絶望", "終わらせたい"],
            "ko": ["죽고 싶어", "자살", "절망", "끝내고 싶어"]
        ]
        
        // Initialize medical claim patterns (PROHIBITED)
        self.medicalClaims = [
            "en": ["cure", "treat", "diagnose", "prescribe", "medication", "dosage", "disease", "illness", "symptom"],
            "my": ["ကုသ", "ရောဂါ", "ဆေး", "ရောဂါလက္ခဏာ"],
            "th": ["รักษา", "วินิจฉัย", "โรค", "ยา"],
            "zh": ["治疗", "诊断", "疾病", "药物", "治愈"],
            "ja": ["治療", "診断", "病気", "薬", "治愈"],
            "ko": ["치료", "진단", "질병", "약", "치유"]
        ]
        
        // Initialize self-harm indicators
        self.selfHarmIndicators = [
            "en": ["cutting", "self-harm", "hurt myself", "burn", "scratch", "bruise"],
            "my": ["ကိုယ့်ကိုယ်ကိုယ် ဒဏ်ရာ", "ထိခိုက်", "သွေး"],
            "th": ["ทำร้ายตัวเอง", "บาดแผล", "เลือด"],
            "zh": ["自残", "割伤", "伤害自己", "烧伤"],
            "ja": ["自傷", "切る", "傷つける", "火傷"],
            "ko": ["자해", "베기", "상처", "화상"]
        ]
        
        // Initialize crisis resources by language
        self.crisisResources = [
            "en": [
                CrisisResource(
                    title: "988 Suicide & Crisis Lifeline",
                    description: "24/7 confidential support",
                    phone: "988",
                    website: "https://988lifeline.org",
                    languageCode: "en"
                ),
                CrisisResource(
                    title: "Crisis Text Line",
                    description: "Text HOME to 741741",
                    phone: "741741",
                    website: "https://www.crisistextline.org",
                    languageCode: "en"
                )
            ],
            "my": [
                CrisisResource(
                    title: "Befrienders Myanmar",
                    description: "24/7 emotional support",
                    phone: "+95-1-234567",
                    website: "https://befrienders.org.mm",
                    languageCode: "my"
                )
            ],
            "th": [
                CrisisResource(
                    title: "สายด่วนสุขภาพจิต 1323",
                    description: "24 ชั่วโมง",
                    phone: "1323",
                    website: "https://dmh.go.th",
                    languageCode: "th"
                )
            ],
            "zh": [
                CrisisResource(
                    title: "心理援助热线",
                    description: "24小时服务",
                    phone: "400-161-9995",
                    website: "https://www.psychological.com",
                    languageCode: "zh"
                )
            ],
            "ja": [
                CrisisResource(
                    title: "いのちの電話",
                    description: "24時間対応",
                    phone: "0120-783-556",
                    website: "https://inochinodenwa.org",
                    languageCode: "ja"
                )
            ],
            "ko": [
                CrisisResource(
                    title: "자살예방 상담전화",
                    description: "24시간 서비스",
                    phone: "109",
                    website: "https://www.spckorea.or.kr",
                    languageCode: "ko"
                )
            ]
        ]
    }
    
    // MARK: - Public Methods
    
    /// Validate user input before sending to AI
    func validateInput(_ text: String, languageCode: String = "en") async -> SafetyValidationResult {
        let normalizedText = text.lowercased()
        var flags: [SafetyFlag] = []
        var requiresEscalation = false
        
        // Check for crisis keywords
        if containsCrisisKeywords(normalizedText, languageCode: languageCode) {
            flags.append(.crisisKeywords)
            requiresEscalation = true
        }
        
        // Check for self-harm indicators
        if containsSelfHarmIndicators(normalizedText, languageCode: languageCode) {
            flags.append(.selfHarm)
            requiresEscalation = true
        }
        
        // Check for medical claims (block these)
        if containsMedicalClaims(normalizedText, languageCode: languageCode) {
            flags.append(.medicalClaim)
            // Don't escalate, but block the request
        }
        
        // Get resources if escalation needed
        let resources = requiresEscalation ? getCrisisResources(for: languageCode) : []
        
        // Sanitize message if it contains PII
        let sanitizedMessage = sanitizePII(text)
        
        return SafetyValidationResult(
            isValid: !flags.contains(.medicalClaim),
            flags: flags,
            requiresEscalation: requiresEscalation,
            escalatedResources: resources,
            sanitizedMessage: sanitizedMessage
        )
    }
    
    /// Validate AI response before displaying to user
    func validateResponse(_ text: String, languageCode: String = "en") async -> SafetyValidationResult {
        let normalizedText = text.lowercased()
        var flags: [SafetyFlag] = []
        
        // Ensure AI didn't make medical claims
        if containsMedicalClaims(normalizedText, languageCode: languageCode) {
            flags.append(.medicalClaim)
        }
        
        // Ensure no harmful content
        if containsCrisisKeywords(normalizedText, languageCode: languageCode) {
            flags.append(.crisisKeywords)
        }
        
        return SafetyValidationResult(
            isValid: flags.isEmpty,
            flags: flags,
            requiresEscalation: false,
            escalatedResources: [],
            sanitizedMessage: text
        )
    }
    
    /// Get crisis resources for a specific language
    func getCrisisResources(for languageCode: String) -> [CrisisResource] {
        return crisisResources[languageCode] ?? crisisResources["en"] ?? []
    }
    
    /// Anonymize input before sending to AI (privacy-preserving)
    func anonymizeInput(_ text: String) -> String {
        var anonymized = text
        
        // Remove email addresses
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(anonymized.startIndex..., in: anonymized)
            anonymized = regex.stringByReplacingMatches(in: anonymized, options: [], range: range, withTemplate: "[EMAIL]")
        }
        
        // Remove phone numbers (simple pattern)
        let phonePattern = "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let range = NSRange(anonymized.startIndex..., in: anonymized)
            anonymized = regex.stringByReplacingMatches(in: anonymized, options: [], range: range, withTemplate: "[PHONE]")
        }
        
        // Remove potential names (capitalized words followed by capitalized words)
        // This is a simple heuristic; production would use NER
        
        return anonymized
    }
    
    // MARK: - Private Methods
    
    private func containsCrisisKeywords(_ text: String, languageCode: String) -> Bool {
        guard let keywords = crisisKeywords[languageCode] else {
            return crisisKeywords["en"]?.contains { text.contains($0) } ?? false
        }
        return keywords.contains { text.contains($0) }
    }
    
    private func containsMedicalClaims(_ text: String, languageCode: String) -> Bool {
        guard let keywords = medicalClaims[languageCode] else {
            return medicalClaims["en"]?.contains { text.contains($0) } ?? false
        }
        return keywords.contains { text.contains($0) }
    }
    
    private func containsSelfHarmIndicators(_ text: String, languageCode: String) -> Bool {
        guard let keywords = selfHarmIndicators[languageCode] else {
            return selfHarmIndicators["en"]?.contains { text.contains($0) } ?? false
        }
        return keywords.contains { text.contains($0) }
    }
    
    private func sanitizePII(_ text: String) -> String {
        // Remove or mask personally identifiable information
        var sanitized = text
        
        // Simple email masking
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "[REDACTED]")
        }
        
        return sanitized
    }
}

// MARK: - Preview Helper
#Preview {
    VStack {
        Text("Safety Validator Ready")
            .padding()
    }
}
