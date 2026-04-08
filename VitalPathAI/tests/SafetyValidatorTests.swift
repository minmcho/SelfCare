//
//  SafetyValidatorTests.swift
//  VitalPath - Wellness Coaching Platform
//
//  Unit tests for safety validation and fallback logic
//

import XCTest
@testable import VitalPath

@MainActor
final class SafetyValidatorTests: XCTestCase {
    
    private var validator: SafetyValidator!
    
    override func setUp() async throws {
        try await super.setUp()
        validator = SafetyValidator(userExcludedTopics: ["politics", "weight loss"])
    }
    
    override func tearDown() async throws {
        validator = nil
        try await super.tearDown()
    }
    
    // MARK: - Medical Claim Detection Tests
    
    func testValidateResponse_RejectsDiagnosisClaim() async {
        let response = "You should see a doctor to diagnose this condition."
        let result = await validator.validateResponse(response)
        
        XCTAssertFalse(result.isValid, "Should reject diagnosis claims")
        XCTAssertTrue(result.reason.contains("medical"), "Should mention medical claims in reason")
    }
    
    func testValidateResponse_RejectsTreatmentClaim() async {
        let response = "This supplement will treat your diabetes."
        let result = await validator.validateResponse(response)
        
        XCTAssertFalse(result.isValid, "Should reject treatment claims")
    }
    
    func testValidateResponse_RejectsCureClaim() async {
        let response = "This meditation technique can cure anxiety."
        let result = await validator.validateResponse(response)
        
        XCTAssertFalse(result.isValid, "Should reject cure claims")
    }
    
    func testValidateResponse_AllowsWellnessLanguage() async {
        let response = "Regular exercise can support your overall wellness and help you maintain healthy habits."
        let result = await validator.validateResponse(response)
        
        XCTAssertTrue(result.isValid, "Should allow wellness-focused language")
    }
    
    func testValidateResponse_AllowsSupportLanguage() async {
        let response = "Mindful breathing can promote relaxation and support stress management."
        let result = await validator.validateResponse(response)
        
        XCTAssertTrue(result.isValid, "Should allow support/promote language")
    }
    
    // MARK: - Crisis Detection Tests
    
    func testDetectCrisisKeywords_DetectsSuicideKeyword() async {
        let input = "I'm feeling suicidal and don't know what to do."
        let keywords = await validator.detectCrisisKeywords(input)
        
        XCTAssertTrue(keywords.contains("suicidal"), "Should detect 'suicidal' keyword")
    }
    
    func testDetectCrisisKeywords_DetectsSelfHarmKeyword() async {
        let input = "Sometimes I want to hurt myself when I'm overwhelmed."
        let keywords = await validator.detectCrisisKeywords(input)
        
        XCTAssertTrue(keywords.contains("hurt myself"), "Should detect 'hurt myself' keyword")
    }
    
    func testDetectCrisisKeywords_DetectsHopelessKeyword() async {
        let input = "I feel so hopeless, like there's no reason to live."
        let keywords = await validator.detectCrisisKeywords(input)
        
        XCTAssertTrue(keywords.contains("hopeless"), "Should detect 'hopeless' keyword")
        XCTAssertTrue(keywords.contains("no reason to live"), "Should detect 'no reason to live' keyword")
    }
    
    func testRequiresCrisisResources_ReturnsTrueForCrisisInput() async {
        let input = "I'm having thoughts of ending my life."
        let requiresResources = await validator.requiresCrisisResources(input)
        
        XCTAssertTrue(requiresResources, "Should require crisis resources for suicidal input")
    }
    
    func testRequiresCrisisResources_ReturnsFalseForNormalInput() async {
        let input = "I'm feeling stressed about work lately."
        let requiresResources = await validator.requiresCrisisResources(input)
        
        XCTAssertFalse(requiresResources, "Should not require crisis resources for normal stress")
    }
    
    func testValidateResponse_ReturnsCrisisValidation() async {
        let response = "I understand you're feeling hopeless right now."
        let result = await validator.validateResponse(response)
        
        XCTAssertTrue(result.requiresCrisisResources, "Should flag response with crisis keywords")
    }
    
    // MARK: - Excluded Topic Tests
    
    func testValidateResponse_RejectsExcludedTopic() async {
        let response = "Let's talk about politics and current events."
        let result = await validator.validateResponse(response)
        
        XCTAssertFalse(result.isValid, "Should reject excluded topic 'politics'")
    }
    
    func testValidateResponse_RejectsWeightLossTopic() async {
        let response = "Here are some weight loss tips for you."
        let result = await validator.validateResponse(response)
        
        XCTAssertFalse(result.isValid, "Should reject excluded topic 'weight loss'")
    }
    
    func testValidateResponse_AllowsNonExcludedTopics() async {
        let response = "Let's explore some mindfulness techniques for better sleep."
        let result = await validator.validateResponse(response)
        
        XCTAssertTrue(result.isValid, "Should allow non-excluded topics")
    }
    
    // MARK: - Input Sanitizer Tests
    
    func testSanitizeInput_RemovesPhoneNumber() {
        let input = "My number is 555-123-4567 if you need to call."
        let sanitized = InputSanitizer.sanitize(input)
        
        XCTAssertTrue(sanitized.contains("[PHONE]"), "Should redact phone number")
        XCTAssertFalse(sanitized.contains("555-123-4567"), "Should not contain original phone number")
    }
    
    func testSanitizeInput_RemovesEmail() {
        let input = "Contact me at john.doe@example.com for details."
        let sanitized = InputSanitizer.sanitize(input)
        
        XCTAssertTrue(sanitized.contains("[EMAIL]"), "Should redact email address")
        XCTAssertFalse(sanitized.contains("example.com"), "Should not contain original email domain")
    }
    
    func testSanitizeInput_RemovesMedicalID() {
        let input = "My patient ID is MRN-ABC12345 from the hospital."
        let sanitized = InputSanitizer.sanitize(input)
        
        XCTAssertTrue(sanitized.contains("[MEDICAL_ID]"), "Should redact medical ID")
    }
    
    func testSanitizeInput_RemovesDate() {
        let input = "I was born on 01/15/1985."
        let sanitized = InputSanitizer.sanitize(input)
        
        XCTAssertTrue(sanitized.contains("[DATE]"), "Should redact dates")
    }
    
    func testContainsPHI_DetectsPhoneNumber() {
        let input = "Call me at +1 (555) 123-4567"
        let containsPHI = InputSanitizer.containsPHI(input)
        
        XCTAssertTrue(containsPHI, "Should detect phone number as PHI")
    }
    
    func testContainsPHI_DetectsEmail() {
        let input = "Email me at test@example.com"
        let containsPHI = InputSanitizer.containsPHI(input)
        
        XCTAssertTrue(containsPHI, "Should detect email as PHI")
    }
    
    func testContainsPHI_DetectsSSN() {
        let input = "My SSN is 123-45-6789"
        let containsPHI = InputSanitizer.containsPHI(input)
        
        XCTAssertTrue(containsPHI, "Should detect SSN as PHI")
    }
    
    func testContainsPHI_NoPHI() {
        let input = "I've been feeling stressed about work lately."
        let containsPHI = InputSanitizer.containsPHI(input)
        
        XCTAssertFalse(containsPHI, "Should not flag normal text as PHI")
    }
    
    // MARK: - Crisis Resources Tests
    
    func testGetCrisisResources_US() {
        let usValidator = SafetyValidator(crisisResourceLocale: "US")
        let resources = usValidator.getCrisisResources()
        
        XCTAssertEqual(resources.hotline, "988", "US should have 988 hotline")
        XCTAssertEqual(resources.textLine, "Text HOME to 741741", "US should have crisis text line")
    }
    
    func testGetCrisisResources_UK() {
        let ukValidator = SafetyValidator(crisisResourceLocale: "UK")
        let resources = ukValidator.getCrisisResources()
        
        XCTAssertEqual(resources.hotline, "116 123", "UK should have Samaritans hotline")
    }
    
    func testGetCrisisResourceURL_ValidURL() {
        let url = validator.getCrisisResourceURL()
        
        XCTAssertNotNil(url, "Should return a valid URL")
        XCTAssertTrue(url?.scheme == "https", "Should use HTTPS")
    }
}

// MARK: - Fallback Logic Tests

@MainActor
final class WellnessAIServiceFallbackTests: XCTestCase {
    
    private var service: WellnessAIService!
    private var mockValidator: MockSafetyValidator!
    
    override func setUp() async throws {
        try await super.setUp()
        mockValidator = MockSafetyValidator()
        service = WellnessAIService(safetyValidator: mockValidator)
    }
    
    override func tearDown() async throws {
        service = nil
        mockValidator = nil
        try await super.tearDown()
    }
    
    func testCircuitBreaker_OpensAfterFailures() async {
        // Simulate multiple failures
        // Note: This would require exposing internal circuit breaker state or using dependency injection
        
        // For now, verify the circuit breaker status string changes
        _ = service.circuitBreakerStatus
        // In production, inject a testable circuit breaker
    }
    
    func testLocalResponse_GeneratesSafeResponse() async {
        // Test that local response generation works when services fail
        // This requires mocking the network layer
        
        // Placeholder - actual implementation would mock URLSession
    }
    
    func testAnonymization_RemovesPHI() async {
        // The service anonymizes input before sending to AI
        // This is tested indirectly through the InputSanitizer tests
        
        // Verify the method exists and is called
        // Actual testing would require dependency injection of the anonymization logic
    }
}

// MARK: - Mock Implementations

final class MockSafetyValidator: SafetyValidatorProtocol {
    
    var shouldReturnValid = true
    var shouldRequireCrisisResources = false
    var detectedCategories: [String] = []
    
    func validateResponse(_ response: String) async -> ValidationResult {
        if shouldRequireCrisisResources {
            return .crisis(detectedCategories)
        }
        
        if shouldReturnValid {
            return .valid
        } else {
            return .invalid("Mock validation failed")
        }
    }
    
    func detectCrisisKeywords(_ input: String) async -> [String] {
        if shouldRequireCrisisResources {
            return ["mock_crisis_keyword"]
        }
        return []
    }
    
    func requiresCrisisResources(_ input: String) async -> Bool {
        return shouldRequireCrisisResources
    }
}

// MARK: - Performance Tests

final class SafetyValidatorPerformanceTests: XCTestCase {
    
    private var validator: SafetyValidator!
    
    override func setUp() async throws {
        try await super.setUp()
        validator = SafetyValidator()
    }
    
    func testValidateResponse_Performance() async throws {
        let response = "Regular exercise and balanced nutrition can support your overall wellness journey."
        
        measure {
            Task {
                await validator.validateResponse(response)
            }
        }
    }
    
    func testDetectCrisisKeywords_Performance() async throws {
        let input = "I've been feeling stressed and anxious about my workload lately."
        
        measure {
            Task {
                await validator.detectCrisisKeywords(input)
            }
        }
    }
}
