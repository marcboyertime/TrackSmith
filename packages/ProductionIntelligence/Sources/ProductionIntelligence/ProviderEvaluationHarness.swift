import AgentCore
import Foundation

public struct ProviderEvaluationExpectation: Codable, Equatable, Sendable {
    public var desired: Set<ProductionTerm>
    public var preserved: Set<ProductionTerm>
    public var prohibited: Set<ProductionTerm>
    public var requiresClarification: Bool?
    public var expectedReferenceKinds: Set<ConversationalReferenceKind>

    public init(
        desired: Set<ProductionTerm>,
        preserved: Set<ProductionTerm> = [],
        prohibited: Set<ProductionTerm> = [],
        requiresClarification: Bool? = nil,
        expectedReferenceKinds: Set<ConversationalReferenceKind> = []
    ) {
        self.desired = desired
        self.preserved = preserved
        self.prohibited = prohibited
        self.requiresClarification = requiresClarification
        self.expectedReferenceKinds = expectedReferenceKinds
    }
}

public struct ProviderEvaluationCase: Sendable {
    public var identifier: String
    public var input: ProductionContextInput
    public var expectation: ProviderEvaluationExpectation

    public init(
        identifier: String,
        input: ProductionContextInput,
        expectation: ProviderEvaluationExpectation
    ) {
        self.identifier = identifier
        self.input = input
        self.expectation = expectation
    }
}

public struct ProviderEvaluationCaseResult: Codable, Equatable, Sendable {
    public var identifier: String
    public var structuredOutputValid: Bool
    public var semanticExpectationSatisfied: Bool
    public var preservationConstraintsSatisfied: Bool
    public var ambiguityBehaviorSatisfied: Bool
    public var referenceResolutionSatisfied: Bool
    public var unsupportedCapabilityHallucination: Bool
    public var providerReportedModelIdentifier: String? = nil
    public var providerResponseID: String? = nil
    public var latencyMilliseconds: Int?
    public var attemptCount: Int?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var failureCategory: String?

    public var passed: Bool {
        structuredOutputValid
            && semanticExpectationSatisfied
            && preservationConstraintsSatisfied
            && ambiguityBehaviorSatisfied
            && referenceResolutionSatisfied
            && !unsupportedCapabilityHallucination
    }
}

public struct ProviderEvaluationRun: Codable, Equatable, Sendable {
    public var version: String
    public var createdAt: Date
    public var provider: ModelProviderDescriptor
    public var results: [ProviderEvaluationCaseResult]

    public init(
        version: String = "1.0",
        createdAt: Date = Date(),
        provider: ModelProviderDescriptor,
        results: [ProviderEvaluationCaseResult]
    ) {
        self.version = version
        self.createdAt = createdAt
        self.provider = provider
        self.results = results
    }

    public var caseCount: Int { results.count }
    public var passedCount: Int { results.count(where: \.passed) }
    public var structuredValidityRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.count(where: \.structuredOutputValid)) / Double(results.count)
    }
    public var failureRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.count - passedCount) / Double(results.count)
    }
}

/// Runs the same normalized, locally grounded TrackSmith inputs through any
/// `ModelProvider`. Downstream contracts and scoring do not branch by vendor.
/// This is an engineering evaluation harness, not an artistic-quality score.
public struct ProviderEvaluationHarness: Sendable {
    public var coordinator: ProductionIntelligenceCoordinator

    public init(coordinator: ProductionIntelligenceCoordinator = .init()) {
        self.coordinator = coordinator
    }

    public func run(
        cases: [ProviderEvaluationCase],
        provider: any ModelProvider
    ) async -> ProviderEvaluationRun {
        var results: [ProviderEvaluationCaseResult] = []
        results.reserveCapacity(cases.count)
        for evaluationCase in cases {
            do {
                let expectedAuthority = evaluationCase.input.authority
                let outcome = try await coordinator.interpretAndPlan(
                    input: evaluationCase.input,
                    provider: provider,
                    currentAuthority: { expectedAuthority }
                )
                let interpretation = outcome.validatedInterpretation.interpretation
                let desired = Set(interpretation.desiredChanges.map(\.term))
                let preserved = Set(interpretation.preservedAttributes.map(\.term))
                let prohibited = Set(interpretation.prohibitedChanges.map(\.term))
                let referenceKinds = Set(outcome.validatedInterpretation.references.map(\.kind))
                let expectation = evaluationCase.expectation
                results.append(.init(
                    identifier: evaluationCase.identifier,
                    structuredOutputValid: true,
                    semanticExpectationSatisfied: desired.isSuperset(of: expectation.desired),
                    preservationConstraintsSatisfied:
                        preserved.isSuperset(of: expectation.preserved)
                            && prohibited.isSuperset(of: expectation.prohibited),
                    ambiguityBehaviorSatisfied: expectation.requiresClarification.map {
                        interpretation.requiresClarification == $0
                    } ?? true,
                    referenceResolutionSatisfied: referenceKinds.isSuperset(of: expectation.expectedReferenceKinds),
                    unsupportedCapabilityHallucination: false,
                    providerReportedModelIdentifier: outcome.validatedInterpretation.metadata.providerReportedModelIdentifier,
                    providerResponseID: outcome.validatedInterpretation.metadata.providerResponseID,
                    latencyMilliseconds: outcome.validatedInterpretation.metadata.latencyMilliseconds,
                    attemptCount: outcome.validatedInterpretation.metadata.attemptCount,
                    inputTokens: outcome.validatedInterpretation.metadata.inputTokens,
                    outputTokens: outcome.validatedInterpretation.metadata.outputTokens,
                    failureCategory: nil
                ))
            } catch let error as ModelOutputValidationError {
                var hallucinatedCapability = false
                if case let .rejected(stage, _) = error {
                    hallucinatedCapability = stage == .capability
                }
                results.append(failure(
                    identifier: evaluationCase.identifier,
                    category: "model_validation_\(validationStage(error).rawValue)",
                    unsupportedCapabilityHallucination: hallucinatedCapability
                ))
            } catch let error as ModelProviderFailure {
                results.append(failure(
                    identifier: evaluationCase.identifier,
                    category: providerFailureCategory(error),
                    unsupportedCapabilityHallucination: false
                ))
            } catch {
                results.append(failure(
                    identifier: evaluationCase.identifier,
                    category: "tracksmith_pipeline_rejected",
                    unsupportedCapabilityHallucination: false
                ))
            }
        }
        return ProviderEvaluationRun(provider: provider.descriptor, results: results)
    }

    private func failure(
        identifier: String,
        category: String,
        unsupportedCapabilityHallucination: Bool
    ) -> ProviderEvaluationCaseResult {
        .init(
            identifier: identifier,
            structuredOutputValid: false,
            semanticExpectationSatisfied: false,
            preservationConstraintsSatisfied: false,
            ambiguityBehaviorSatisfied: false,
            referenceResolutionSatisfied: false,
            unsupportedCapabilityHallucination: unsupportedCapabilityHallucination,
            providerReportedModelIdentifier: nil,
            providerResponseID: nil,
            latencyMilliseconds: nil,
            attemptCount: nil,
            inputTokens: nil,
            outputTokens: nil,
            failureCategory: category
        )
    }

    private func validationStage(_ error: ModelOutputValidationError) -> ModelValidationStage {
        if case let .rejected(stage, _) = error { return stage }
        return .schema
    }

    private func providerFailureCategory(_ error: ModelProviderFailure) -> String {
        switch error {
        case .unavailable: "unavailable"
        case .credentialMissing: "credential_missing"
        case .credentialStoreUnavailable: "credential_store_unavailable"
        case .credentialRejected: "credential_rejected"
        case .consentRequired: "consent_required"
        case .timedOut: "timed_out"
        case .cancelled: "cancelled"
        case .network: "network"
        case .rateLimited: "rate_limited"
        case .malformedResponse: "malformed_response"
        case .providerRejected: "provider_rejected"
        case .responseTooLarge: "response_too_large"
        case .duplicateResponse: "duplicate_response"
        case .staleResult: "stale_result"
        }
    }
}
