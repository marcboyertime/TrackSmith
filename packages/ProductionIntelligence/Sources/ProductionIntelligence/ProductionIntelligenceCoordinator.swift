import AgentCore
import AudioAnalysis
import Foundation
import PlanSchema

public struct ProductionIntelligenceOutcome: Codable, Equatable, Sendable {
    public var request: ModelInterpretationRequest
    public var validatedInterpretation: ValidatedModelInterpretation
    public var productionResult: ProductionIntentResult

    public init(
        request: ModelInterpretationRequest,
        validatedInterpretation: ValidatedModelInterpretation,
        productionResult: ProductionIntentResult
    ) {
        self.request = request
        self.validatedInterpretation = validatedInterpretation
        self.productionResult = productionResult
    }
}

/// Companion-process semantic orchestration. Provider output is validated and
/// grounded before the existing deterministic production engine can construct
/// plans. This type has no AU or realtime-thread dependency.
public struct ProductionIntelligenceCoordinator: Sendable {
    public var contextBuilder: DeterministicContextBuilder
    public var outputValidator: ModelOutputValidator
    public var intentEngine: ProductionIntentEngine

    public init(
        contextBuilder: DeterministicContextBuilder = .init(),
        outputValidator: ModelOutputValidator = .init(),
        intentEngine: ProductionIntentEngine = .init()
    ) {
        self.contextBuilder = contextBuilder
        self.outputValidator = outputValidator
        self.intentEngine = intentEngine
    }

    public func interpretAndPlan(
        input: ProductionContextInput,
        provider: any ModelProvider,
        currentAuthority: @escaping @Sendable () async -> ProductionAuthorityIdentity?
    ) async throws -> ProductionIntelligenceOutcome {
        let request = try contextBuilder.build(input)
        let response = try await provider.interpret(request)
        try Task.checkCancellation()
        guard let liveAuthority = await currentAuthority(), liveAuthority == request.authority else {
            throw ModelProviderFailure.staleResult
        }
        let validated = try outputValidator.validate(
            response,
            for: request,
            environment: .init(
                currentAuthority: liveAuthority,
                availableMetricIdentifiers: Set(input.analysis.metrics.keys),
                expectedProvider: provider.descriptor
            )
        )
        let production = try intentEngine.developHypotheses(
            interpretation: validated.interpretation,
            sourceSnapshotID: request.authority.captureSnapshotID,
            scope: request.scope,
            analysis: input.analysis,
            validatedStrategyProposals: validated.hypothesisProposals
        )
        guard let finalAuthority = await currentAuthority(), finalAuthority == request.authority else {
            throw ModelProviderFailure.staleResult
        }
        return ProductionIntelligenceOutcome(
            request: request,
            validatedInterpretation: validated,
            productionResult: production
        )
    }
}
