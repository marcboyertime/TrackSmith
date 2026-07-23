import AgentCore
import AudioAnalysis
import CryptoKit
import DSPCore
import Foundation
import PlanSchema
import ProductionIntelligence
import PreviewWorkflow

private struct EvaluationDefinition {
    var identifier: String
    var sourceType: SourceType
    var sourceClass: SourceAnalysisClass
    var prompt: String
    var variant: Int
    var expectedDesired: Set<ProductionTerm> = []
    var expectedAnyAdditionalDesired: Set<ProductionTerm> = []
    var expectedPreserved: Set<ProductionTerm> = []
    var expectedProhibited: Set<ProductionTerm> = []
    var expectedConstraint: Set<ProductionTerm> = []
}

private struct MetricEvidence: Codable {
    var value: Double
    var unit: String
    var confidence: Double
}

private struct CandidateEvidence: Codable {
    var previewID: UUID
    var strength: String
    var status: String
    var hypothesisIdentifier: String?
    var candidateIdentifier: String?
    var planRequestID: UUID
    var nodeTypes: [String]
    var loudnessMatchGainDB: Double
    var loudnessMatchMethod: String
    var differenceRMSDBFS: Double
    var peakDBFS: Double?
    var truePeakDBTP: Double?
    var rejectionReasons: [String]
    var warnings: [String]
}

private struct CaseEvidence: Codable {
    var identifier: String
    var sourceClass: String
    var sourceType: String
    var sourceProvenance: String
    var sourceSHA256: String
    var sourceSampleRate: Double
    var sourceChannels: Int
    var sourceFrames: Int
    var userRequest: String
    var providerIdentifier: String
    var modelIdentifier: String
    var providerReportedModelIdentifier: String? = nil
    var providerResponseID: String? = nil
    var providerAttemptCount: Int? = nil
    var providerLatencyMilliseconds: Int? = nil
    var providerInputTokens: Int? = nil
    var providerOutputTokens: Int? = nil
    var completedValidationStages: [String] = []
    var validationRepairAttempted: Bool? = nil
    var expectedDesired: [String] = []
    var expectedAnyAdditionalDesired: [String] = []
    var expectedPreserved: [String] = []
    var expectedProhibited: [String] = []
    var expectedConstraint: [String] = []
    var semanticExpectationSatisfied: Bool? = nil
    var desired: [String]
    var preserved: [String]
    var prohibited: [String]
    var ambiguity: [String]
    var uncertainty: [String]
    var measuredEvidence: [String: MetricEvidence]
    var hypothesisIdentifiers: [String]
    var hypothesisOutcomes: [String]
    var candidatePreviews: [CandidateEvidence]
    var selectedPreviewID: UUID?
    var selectedRevisionPath: String
    var sourceUnchanged: Bool
    var success: Bool
    var failure: String?
    var validationFailureReason: String? = nil
}

private struct RunEvidence: Codable {
    var version = "1.1"
    var createdAt = Date()
    var generator = "TrackSmith deterministic musical-fixture generator v1"
    var fixtureLicense = "Generated locally by TrackSmith evaluation code; no third-party audio or copyrighted recording payload."
    var provider: ModelProviderDescriptor
    var cloudConsentGranted: Bool
    var credentialSource: String
    var subjectiveClaimBoundary = "No objective measurement or automated pass claims artistic superiority; listening remains decisive."
    var cases: [CaseEvidence]

    var successfulCaseCount: Int { cases.count(where: \.success) }
}

@main
private enum ProductionIntelligenceEvaluationMain {
    static func main() async {
        do {
            try await run()
        } catch let failure as EvaluationFailure {
            FileHandle.standardError.write(Data("ERROR \(failure.description)\n".utf8))
            exit(2)
        } catch {
            // Setup errors are intentionally category-only. A platform or
            // Keychain error can contain sensitive implementation detail and
            // must not be copied into logs or evidence.
            FileHandle.standardError.write(Data("ERROR evaluation_setup_failed\n".utf8))
            exit(2)
        }
    }

    private static func run() async throws {
        if hasFlag("--help") || hasFlag("-h") {
            printUsage()
            return
        }
        try validateArguments()
        let provider = try selectedProvider()
        let cloudConsentGranted = hasFlag("--cloud-consent") && provider.descriptor.usesNetwork
        if provider.descriptor.kind != .offline, argumentValue("--case") == nil {
            throw EvaluationFailure(
                "Model evaluation requires one explicit --case per invocation to bound latency, resource use, cost, and request count."
            )
        }
        let outputRoot = try outputURL()
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: outputRoot.path) else {
            throw EvaluationFailure("Output already exists: \(outputRoot.path)")
        }
        try fileManager.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        var records: [CaseEvidence] = []
        let selectedDefinitions: [EvaluationDefinition]
        if let onlyCase = argumentValue("--case") {
            selectedDefinitions = (definitions() + frontierDefinitions()).filter { $0.identifier == onlyCase }
            guard selectedDefinitions.count == 1 else { throw EvaluationFailure("Unknown case: \(onlyCase)") }
        } else {
            selectedDefinitions = definitions()
        }
        for definition in selectedDefinitions {
            print("EVALUATE \(definition.identifier) \(definition.sourceClass.rawValue)")
            let caseRoot = outputRoot.appendingPathComponent(definition.identifier, isDirectory: true)
            try fileManager.createDirectory(at: caseRoot, withIntermediateDirectories: false)
            let sourceURL = caseRoot.appendingPathComponent("generated-source.wav")
            let source = generatedFixture(for: definition.sourceClass, variant: definition.variant)
            try WAVFile.writePCM24(source, url: sourceURL)
            let sourceBefore = try Data(contentsOf: sourceURL)
            let sourceHash = SHA256.hash(data: sourceBefore).map { String(format: "%02x", $0) }.joined()
            do {
                let analysis = SourceAwareAudioAnalyzer().analyze(source, as: definition.sourceClass)
                let snapshotID = UUID()
                let authority = ProductionAuthorityIdentity(
                    captureSnapshotID: snapshotID,
                    conversationID: UUID()
                )
                let scope = ProcessingScope(
                    kind: .importedFile,
                    channelFormat: source.channelCount == 1 ? .mono : .stereo,
                    sourceType: definition.sourceType,
                    timeRangeSeconds: .init(
                        start: 0,
                        end: Double(source.frameCount) / source.sampleRate
                    )
                )
                let outcome = try await ProductionIntelligenceCoordinator().interpretAndPlan(
                    input: .init(
                        userRequest: definition.prompt,
                        scope: scope,
                        authority: authority,
                        analysis: analysis,
                        budget: .init(
                            maxContextUTF8Bytes: 48_000,
                            maxOutputTokens: 2_500,
                            maxAttempts: 1,
                            timeoutSeconds: provider.descriptor.kind == .local ? 45 : 60
                        )
                    ),
                    provider: provider,
                    currentAuthority: { authority }
                )
                let previewRoot = caseRoot.appendingPathComponent("previews", isDirectory: true)
                let rendered = try PreviewSessionExporter().exportProductionIntelligence(
                    inputURL: sourceURL,
                    prompt: definition.prompt,
                    sourceType: definition.sourceType,
                    outputDirectory: previewRoot,
                    sourceSnapshotID: snapshotID,
                    result: outcome.productionResult,
                    providerMetadata: outcome.validatedInterpretation.metadata
                )
                let candidates = rendered.manifest.variants.map { variant in
                    CandidateEvidence(
                        previewID: variant.previewID,
                        strength: variant.strength.rawValue,
                        status: variant.status.rawValue,
                        hypothesisIdentifier: variant.hypothesisIdentifier,
                        candidateIdentifier: variant.candidateIdentifier,
                        planRequestID: variant.plan.requestID,
                        nodeTypes: variant.plan.nodes.map(\.type.rawValue),
                        loudnessMatchGainDB: variant.loudnessMatchGainDB,
                        loudnessMatchMethod: variant.loudnessMatchMethod.rawValue,
                        differenceRMSDBFS: variant.difference.differenceRMSDBFS,
                        peakDBFS: variant.analysis.metrics["peak_dbfs"]?.value,
                        truePeakDBTP: variant.analysis.metrics["true_peak_dbtp"]?.value,
                        rejectionReasons: variant.rejectionReasons,
                        warnings: variant.warnings
                    )
                }
                for variant in rendered.manifest.variants {
                    try PlanValidator().validateForRealtimeActivation(
                        variant.plan,
                        currentSnapshotID: snapshotID
                    )
                }
                let selected = rendered.manifest.variants.first(where: {
                    $0.status == .valid && $0.strength == .balanced
                }) ?? rendered.manifest.variants.first(where: { $0.status == .valid })
                let sourceAfter = try Data(contentsOf: sourceURL)
                let unchanged = sourceAfter == sourceBefore
                let interpretedDesired = Set(outcome.validatedInterpretation.interpretation.desiredChanges.map(\.term))
                let interpretedPreserved = Set(outcome.validatedInterpretation.interpretation.preservedAttributes.map(\.term))
                let interpretedProhibited = Set(outcome.validatedInterpretation.interpretation.prohibitedChanges.map(\.term))
                let semanticExpectationSatisfied = interpretedDesired.isSuperset(of: definition.expectedDesired)
                    && interpretedPreserved.isSuperset(of: definition.expectedPreserved)
                    && interpretedProhibited.isSuperset(of: definition.expectedProhibited)
                    && interpretedPreserved.union(interpretedProhibited).isSuperset(of: definition.expectedConstraint)
                    && (definition.expectedAnyAdditionalDesired.isEmpty
                        || !interpretedDesired.intersection(definition.expectedAnyAdditionalDesired).isEmpty)
                let renderSucceeded = unchanged && rendered.manifest.variants.count == 3
                    && rendered.manifest.validVariantCount == 3 && selected != nil
                let metrics = Dictionary(uniqueKeysWithValues: analysis.metrics.map { identifier, observation in
                    (identifier, MetricEvidence(
                        value: observation.value,
                        unit: observation.definition.unit.rawValue,
                        confidence: observation.confidence
                    ))
                })
                records.append(CaseEvidence(
                    identifier: definition.identifier,
                    sourceClass: definition.sourceClass.rawValue,
                    sourceType: definition.sourceType.rawValue,
                    sourceProvenance: "Generated locally from deterministic synthesis seed \(definition.variant), algorithm TrackSmith musical-fixture generator v1.",
                    sourceSHA256: sourceHash,
                    sourceSampleRate: source.sampleRate,
                    sourceChannels: source.channelCount,
                    sourceFrames: source.frameCount,
                    userRequest: definition.prompt,
                    providerIdentifier: outcome.validatedInterpretation.metadata.providerIdentifier,
                    modelIdentifier: outcome.validatedInterpretation.metadata.modelIdentifier,
                    providerReportedModelIdentifier: outcome.validatedInterpretation.metadata.providerReportedModelIdentifier,
                    providerResponseID: outcome.validatedInterpretation.metadata.providerResponseID,
                    providerAttemptCount: outcome.validatedInterpretation.metadata.attemptCount,
                    providerLatencyMilliseconds: outcome.validatedInterpretation.metadata.latencyMilliseconds,
                    providerInputTokens: outcome.validatedInterpretation.metadata.inputTokens,
                    providerOutputTokens: outcome.validatedInterpretation.metadata.outputTokens,
                    completedValidationStages: outcome.validatedInterpretation.audit.completedStages.map(\.rawValue),
                    validationRepairAttempted: outcome.validatedInterpretation.audit.repairAttempted,
                    expectedDesired: definition.expectedDesired.map(\.rawValue).sorted(),
                    expectedAnyAdditionalDesired: definition.expectedAnyAdditionalDesired.map(\.rawValue).sorted(),
                    expectedPreserved: definition.expectedPreserved.map(\.rawValue).sorted(),
                    expectedProhibited: definition.expectedProhibited.map(\.rawValue).sorted(),
                    expectedConstraint: definition.expectedConstraint.map(\.rawValue).sorted(),
                    semanticExpectationSatisfied: semanticExpectationSatisfied,
                    desired: outcome.validatedInterpretation.interpretation.desiredChanges.map { "\($0.term.rawValue):\($0.direction.rawValue)" },
                    preserved: outcome.validatedInterpretation.interpretation.preservedAttributes.map { "\($0.term.rawValue):\($0.direction.rawValue)" },
                    prohibited: outcome.validatedInterpretation.interpretation.prohibitedChanges.map { "\($0.term.rawValue):\($0.direction.rawValue)" },
                    ambiguity: outcome.validatedInterpretation.interpretation.unresolvedAmbiguities,
                    uncertainty: outcome.productionResult.hypotheses.flatMap(\.uncertainty),
                    measuredEvidence: metrics,
                    hypothesisIdentifiers: outcome.productionResult.hypotheses.map(\.selectedStrategyIdentifier),
                    hypothesisOutcomes: outcome.productionResult.hypotheses.map(\.intendedPerceptualChange),
                    candidatePreviews: candidates,
                    selectedPreviewID: selected?.previewID,
                    selectedRevisionPath: selected.map { "Selected \($0.strength.rawValue) preview for a possible next conversational revision; no artistic preference was automated." }
                        ?? "No candidate was selected because every render was rejected by a safety or distinctness gate.",
                    sourceUnchanged: unchanged,
                    success: renderSucceeded && semanticExpectationSatisfied,
                    failure: !semanticExpectationSatisfied
                        ? "semantic_expectation_unsatisfied"
                        : (rendered.manifest.validVariantCount == 3
                            ? nil
                            : "Only \(rendered.manifest.validVariantCount) of three candidates passed safety and distinctness gates.")
                ))
            } catch {
                let sourceAfter = (try? Data(contentsOf: sourceURL)) ?? Data()
                records.append(CaseEvidence(
                    identifier: definition.identifier,
                    sourceClass: definition.sourceClass.rawValue,
                    sourceType: definition.sourceType.rawValue,
                    sourceProvenance: "Generated locally from deterministic synthesis seed \(definition.variant), algorithm TrackSmith musical-fixture generator v1.",
                    sourceSHA256: sourceHash,
                    sourceSampleRate: source.sampleRate,
                    sourceChannels: source.channelCount,
                    sourceFrames: source.frameCount,
                    userRequest: definition.prompt,
                    providerIdentifier: provider.descriptor.identifier,
                    modelIdentifier: provider.descriptor.modelIdentifier,
                    expectedDesired: definition.expectedDesired.map(\.rawValue).sorted(),
                    expectedAnyAdditionalDesired: definition.expectedAnyAdditionalDesired.map(\.rawValue).sorted(),
                    expectedPreserved: definition.expectedPreserved.map(\.rawValue).sorted(),
                    expectedProhibited: definition.expectedProhibited.map(\.rawValue).sorted(),
                    expectedConstraint: definition.expectedConstraint.map(\.rawValue).sorted(),
                    desired: [], preserved: [], prohibited: [], ambiguity: [], uncertainty: [],
                    measuredEvidence: [:], hypothesisIdentifiers: [], hypothesisOutcomes: [], candidatePreviews: [],
                    selectedPreviewID: nil,
                    selectedRevisionPath: "Pipeline failed before a safe selection.",
                    sourceUnchanged: sourceAfter == sourceBefore,
                    success: false,
                    failure: failureCategory(error),
                    validationFailureReason: validationFailureReason(error)
                ))
            }
        }

        let run = RunEvidence(
            provider: provider.descriptor,
            cloudConsentGranted: cloudConsentGranted,
            credentialSource: provider.descriptor.usesNetwork
                ? "macOS Keychain only; environment variables and command-line credential values are unsupported"
                : (provider.descriptor.kind == .local
                    ? "none; Apple on-device system language model"
                    : "none; deterministic offline provider"),
            cases: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(run).write(to: outputRoot.appendingPathComponent("run.json"), options: .atomic)
        let summary = "TrackSmith generated-audio production-intelligence evaluation [\(provider.descriptor.identifier) / \(provider.descriptor.modelIdentifier)]: \(run.successfulCaseCount)/\(records.count) cases produced a safe selectable result.\n"
        try Data(summary.utf8).write(to: outputRoot.appendingPathComponent("SUMMARY.txt"), options: .atomic)
        print(summary.trimmingCharacters(in: .whitespacesAndNewlines))
        print("EVIDENCE \(outputRoot.path)")
        if argumentValue("--case") == nil {
            guard records.count >= 30, run.successfulCaseCount >= 30 else { exit(1) }
        }
        guard run.successfulCaseCount == records.count else { exit(1) }
    }

    private static func selectedProvider() throws -> any ModelProvider {
        let name = argumentValue("--provider") ?? "mock"
        let model = argumentValue("--model")
        switch name.lowercased() {
        case "mock", "offline":
            guard model == nil else {
                throw EvaluationFailure("--model is only valid with a cloud provider.")
            }
            guard !hasFlag("--cloud-consent") else {
                throw EvaluationFailure("--cloud-consent is only valid with a cloud provider.")
            }
            return MockModelProvider()
        case "apple", "local", "on-device":
            guard model == nil else {
                throw EvaluationFailure("--model cannot replace the operating system's on-device model.")
            }
            guard !hasFlag("--cloud-consent") else {
                throw EvaluationFailure("--cloud-consent is not valid for the on-device provider.")
            }
            let provider = AppleFoundationModelProvider()
            guard provider.availability == .available else {
                throw EvaluationFailure("Apple on-device model unavailable: \(provider.availability.rawValue).")
            }
            return provider
        case "openai":
            guard hasFlag("--cloud-consent") else {
                throw EvaluationFailure(
                    "OpenAI evaluation requires explicit --cloud-consent for the labeled request and measurements."
                )
            }
            return OpenAIResponsesProvider(configuration: .init(
                modelIdentifier: model ?? "gpt-5.6-sol",
                cloudReasoningConsent: true,
                automaticRetryEnabled: false,
                maximumAttempts: 1
            ))
        case "gemini":
            guard hasFlag("--cloud-consent") else {
                throw EvaluationFailure(
                    "Gemini evaluation requires explicit --cloud-consent for the labeled request and measurements."
                )
            }
            return GeminiInteractionsProvider(configuration: .init(
                modelIdentifier: model ?? "gemini-3.6-flash",
                cloudReasoningConsent: true,
                automaticRetryEnabled: false,
                maximumAttempts: 1
            ))
        default:
            throw EvaluationFailure("Unknown --provider value: \(name). Use mock, apple, openai, or gemini.")
        }
    }

    private static func outputURL() throws -> URL {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--output"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL
        }
        let formatter = ISO8601DateFormatter()
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return URL(fileURLWithPath: ".build/evidence/production-intelligence-\(stamp)").standardizedFileURL
    }

    private static func argumentValue(_ name: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func hasFlag(_ name: String) -> Bool {
        CommandLine.arguments.contains(name)
    }

    private static func validateArguments() throws {
        let valued = Set(["--output", "--case", "--provider", "--model"])
        let switches = Set(["--cloud-consent"])
        let arguments = Array(CommandLine.arguments.dropFirst())
        var seen = Set<String>()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if valued.contains(argument) {
                guard seen.insert(argument).inserted else {
                    throw EvaluationFailure("Duplicate argument: \(argument).")
                }
                guard arguments.indices.contains(index + 1),
                      !arguments[index + 1].hasPrefix("-") else {
                    throw EvaluationFailure("Missing value for \(argument).")
                }
                index += 2
            } else if switches.contains(argument) {
                guard seen.insert(argument).inserted else {
                    throw EvaluationFailure("Duplicate argument: \(argument).")
                }
                index += 1
            } else {
                throw EvaluationFailure("Unknown argument: \(argument). Use --help for supported options.")
            }
        }
    }

    private static func printUsage() {
        print("""
        TrackSmith ProductionIntelligenceEvaluation

        Offline 30-case regression:
          ProductionIntelligenceEvaluation --provider mock --output <new-directory>

        One bounded credential-free on-device case:
          ProductionIntelligenceEvaluation --provider apple --case <case-id> \
            --output <new-directory>

        One bounded cloud case:
          ProductionIntelligenceEvaluation --provider openai|gemini --cloud-consent \\
            --case <case-id> [--model <model-id>] --output <new-directory>

        Every non-mock model mode requires exactly one explicit case per invocation.
        Cloud mode uses one attempt,
        reads credentials only from the TrackSmith macOS Keychain service, and never
        accepts credential values from arguments or environment variables. Output
        directories must not already exist. Use case IDs VOC-01...VOC-05, DRM-01...DRM-05,
        BAS-01...BAS-05, GTR-01...GTR-05, SYN-01...SYN-05, MIX-01...MIX-05,
        or the free-form on-device/frontier cases VOC-FRONTIER-01,
        DRM-FRONTIER-01, BAS-FRONTIER-01, GTR-FRONTIER-01,
        SYN-FRONTIER-01, and MIX-FRONTIER-01.
        """)
    }

    private static func failureCategory(_ error: Error) -> String {
        if let failure = error as? ModelProviderFailure {
            return switch failure {
            case .unavailable: "provider_unavailable"
            case .credentialMissing: "credential_missing"
            case .credentialStoreUnavailable: "credential_store_unavailable"
            case .credentialRejected: "credential_rejected"
            case .consentRequired: "consent_required"
            case .timedOut: "timed_out"
            case .cancelled: "cancelled"
            case .network: "network_failure"
            case .rateLimited: "rate_limited"
            case .malformedResponse: "malformed_response"
            case .providerRejected: "provider_rejected"
            case .responseTooLarge: "response_too_large"
            case .duplicateResponse: "duplicate_response"
            case .staleResult: "stale_result"
            }
        }
        if let validation = error as? ModelOutputValidationError,
           case let .rejected(stage, _) = validation {
            return "model_validation_\(stage.rawValue)"
        }
        return "tracksmith_pipeline_rejected"
    }

    /// Failure reasons retained here are TrackSmith-authored bounded strings,
    /// never raw provider text. This keeps failed evidence actionable without
    /// logging model envelopes, prompts, or hidden reasoning.
    private static func validationFailureReason(_ error: Error) -> String? {
        let reason: String?
        if let validation = error as? ModelOutputValidationError,
           case let .rejected(_, message) = validation {
            reason = message
        } else if let intent = error as? ProductionIntentError {
            reason = switch intent {
            case let .sourceAnalysisMismatch(expected, actual):
                "Source analysis mismatch: expected \(expected.rawValue), received \(actual.rawValue)."
            case let .noActionableIntent(message):
                "Production intent rejected: \(message)"
            case let .contradictoryIntent(message):
                "Production intent contradiction: \(message)"
            }
        } else if let plan = error as? PlanValidationError {
            reason = "Plan validation rejected: \(plan.description)"
        } else if let preview = error as? PreviewExportError {
            reason = "Preview export rejected: \(preview.description)"
        } else if let provider = error as? ModelProviderFailure {
            reason = switch provider {
            case .providerRejected("The provider exhausted its bounded output budget."):
                "Provider did not finish within TrackSmith's bounded output-token budget."
            case .providerRejected("The provider did not complete the interaction."):
                "Provider returned a non-completed interaction status."
            case .providerRejected:
                "Provider rejected the bounded request."
            case .malformedResponse:
                "Provider response did not satisfy the bounded transport envelope."
            case .responseTooLarge:
                "Provider response exceeded TrackSmith's byte bound."
            case .timedOut:
                "Provider exceeded TrackSmith's request deadline."
            case .cancelled:
                "Provider request was cancelled."
            case .network:
                "Provider transport failed."
            case .rateLimited:
                "Provider rate-limited the bounded request."
            case .unavailable:
                "Provider was unavailable."
            case .credentialMissing:
                "Provider credential was absent from the TrackSmith Keychain service."
            case .credentialStoreUnavailable:
                "TrackSmith could not access its Keychain credential store."
            case .credentialRejected:
                "Provider rejected the stored credential."
            case .consentRequired:
                "Explicit cloud-reasoning consent was absent."
            case .duplicateResponse:
                "Provider response replay was rejected."
            case .staleResult:
                "Provider result no longer matched current TrackSmith authority."
            }
        } else {
            reason = nil
        }
        guard let reason else { return nil }
        return reason.utf8.count <= 512 ? reason : "TrackSmith failure reason exceeded its evidence bound."
    }

    private static func definitions() -> [EvaluationDefinition] {
        let groups: [(String, SourceType, SourceAnalysisClass, [String])] = [
            ("VOC", .vocal, .vocal, [
                "make this warmer without losing air",
                "reduce sibilance but keep it intimate",
                "make this more forward but preserve air",
                "make this more controlled but preserve dynamics",
                "reduce harshness while maintaining clarity",
            ]),
            ("DRM", .drums, .drums, [
                "make these punchier without making the cymbals harsher",
                "make these warmer but preserve the punch",
                "make these more controlled but preserve dynamics",
                "make these more energetic without making them harsh",
                "make these tighter without losing low-end weight",
            ]),
            ("BAS", .bass, .bass, [
                "make this tighter without losing low-end weight",
                "make this clearer without making it thin",
                "make this more controlled but preserve dynamics",
                "make this warmer but preserve the punch",
                "reduce the boom without losing the bottom end",
            ]),
            ("GTR", .guitar, .guitar, [
                "make this less harsh without burying the pick attack",
                "make this warmer while maintaining clarity",
                "make this more aggressive without making it harsh",
                "make this more controlled but preserve dynamics",
                "make this punchier but keep it smooth",
            ]),
            ("SYN", .synth, .synthKeys, [
                "make this wider without damaging mono compatibility",
                "make this warmer without losing air",
                "make this clearer without making it brighter",
                "make this smoother but preserve dynamics",
                "make this more energetic without making it harsh",
            ]),
            ("MIX", .fullMix, .fullStereoMix, [
                "make this clearer without making it brighter",
                "make this more controlled but preserve dynamics",
                "make this warmer without losing air",
                "make this punchier without making it harsh",
                "reduce the mud without losing warmth",
            ]),
        ]
        return groups.flatMap { prefix, sourceType, sourceClass, prompts in
            prompts.enumerated().map { index, prompt in
                EvaluationDefinition(
                    identifier: String(format: "%@-%02d", prefix, index + 1),
                    sourceType: sourceType,
                    sourceClass: sourceClass,
                    prompt: prompt,
                    variant: index
                )
            }
        }
    }

    private static func frontierDefinitions() -> [EvaluationDefinition] {
        [
            EvaluationDefinition(
                identifier: "VOC-FRONTIER-01",
                sourceType: .vocal,
                sourceClass: .vocal,
                prompt: "Make this vocal feel more intimate and expensive, but keep the breathiness.",
                variant: 5,
                expectedDesired: [.intimate],
                expectedAnyAdditionalDesired: [.polished, .clear, .controlled, .warm],
                expectedPreserved: [.airy]
            ),
            EvaluationDefinition(
                identifier: "DRM-FRONTIER-01",
                sourceType: .drumBus,
                sourceClass: .drums,
                prompt: "The drums feel flat and small. Give them more life without making the cymbals obnoxious.",
                variant: 5,
                expectedDesired: [.energetic],
                expectedAnyAdditionalDesired: [.punchy, .wide, .aggressive, .forward],
                expectedProhibited: [.cymbalHarshness]
            ),
            EvaluationDefinition(
                identifier: "BAS-FRONTIER-01",
                sourceType: .bass,
                sourceClass: .bass,
                prompt: "The bass is huge but blurry. Tighten it without losing the weight.",
                variant: 5,
                expectedDesired: [.tight],
                expectedConstraint: [.lowEndWeight]
            ),
            EvaluationDefinition(
                identifier: "GTR-FRONTIER-01",
                sourceType: .guitar,
                sourceClass: .guitar,
                prompt: "This guitar hurts when I turn it up, but don't take away the aggression.",
                variant: 5,
                expectedDesired: [.harsh],
                expectedConstraint: [.aggressive]
            ),
            EvaluationDefinition(
                identifier: "SYN-FRONTIER-01",
                sourceType: .synth,
                sourceClass: .synthKeys,
                prompt: "Make this synth wider without damaging mono compatibility.",
                variant: 5,
                expectedDesired: [.wide],
                expectedConstraint: [.monoCompatibility]
            ),
            EvaluationDefinition(
                identifier: "MIX-FRONTIER-01",
                sourceType: .fullMix,
                sourceClass: .fullStereoMix,
                prompt: "Make this mix clearer without making it brighter.",
                variant: 5,
                expectedDesired: [.clear],
                expectedConstraint: [.bright]
            ),
        ]
    }

    private static func generatedFixture(
        for sourceClass: SourceAnalysisClass,
        variant: Int
    ) -> AudioBuffer {
        let sampleRate = 48_000.0
        let frameCount = 24_000
        var noise = SeededNoise(state: UInt64(0x545241434B534D49) &+ UInt64(variant * 31 + sourceClass.rawValue.utf8.count))
        var left = Array(repeating: Float.zero, count: frameCount)
        var right = Array(repeating: Float.zero, count: frameCount)
        for index in 0..<frameCount {
            let time = Double(index) / sampleRate
            let beatPhase = index % 6_000
            let modulation = sin(2 * Double.pi * (2.2 + Double(variant) * 0.08) * time)
            let slowEnvelope = 0.62 + 0.38 * modulation * modulation
            let random = noise.next()
            switch sourceClass {
            case .vocal:
                let f0 = 165.0 + Double(variant) * 9
                let vowel = slowEnvelope * (
                    0.11 * sin(2 * .pi * f0 * time)
                        + 0.065 * sin(2 * .pi * f0 * 2 * time)
                        + 0.035 * sin(2 * .pi * f0 * 3 * time)
                        + 0.018 * sin(2 * .pi * 2_400 * time)
                )
                let consonant = beatPhase > 4_900 && beatPhase < 5_080 ? random * 0.07 : 0
                left[index] = Float(vowel + consonant)
                right[index] = left[index]
            case .drums:
                let kick = beatPhase < 620
                    ? 0.34 * exp(-Double(beatPhase) / 155) * sin(2 * .pi * (78 + Double(variant) * 3) * time)
                    : 0
                let snarePhase = (index + 3_000) % 6_000
                let snare = snarePhase < 520 ? random * 0.24 * exp(-Double(snarePhase) / 170) : 0
                let hatPhase = index % 1_500
                let hat = hatPhase < 100 ? random * 0.07 * exp(-Double(hatPhase) / 32) : 0
                left[index] = Float(kick + snare + hat)
                right[index] = Float(kick + snare * 0.91 - hat * 0.85)
            case .bass:
                let f0 = 55.0 + Double(variant) * 3
                let decay = 0.35 + 0.65 * exp(-Double(beatPhase) / 2_800)
                let value = decay * (
                    0.19 * sin(2 * .pi * f0 * time)
                        + 0.075 * sin(2 * .pi * f0 * 2 * time)
                        + 0.028 * sin(2 * .pi * f0 * 4 * time)
                )
                left[index] = Float(value)
                right[index] = left[index]
            case .guitar:
                let f0 = 196.0 + Double(variant) * 11
                let decay = exp(-Double(beatPhase) / 4_200)
                let pick = beatPhase < 55 ? random * 0.12 : 0
                let value = decay * (
                    0.11 * sin(2 * .pi * f0 * time)
                        + 0.07 * sin(2 * .pi * f0 * 2.01 * time)
                        + 0.04 * sin(2 * .pi * f0 * 3.02 * time)
                ) + pick
                left[index] = Float(value)
                right[index] = left[index]
            case .synthKeys:
                let root = 110.0 + Double(variant) * 7
                let pad = 0.08 * sin(2 * .pi * root * time)
                    + 0.055 * sin(2 * .pi * root * 1.5 * time)
                    + 0.035 * sin(2 * .pi * root * 2 * time)
                let motion = 0.7 + 0.3 * sin(2 * .pi * 0.8 * time)
                left[index] = Float(pad * motion + 0.018 * sin(2 * .pi * 3_100 * time))
                right[index] = Float(pad * (1.4 - motion) + 0.018 * sin(2 * .pi * 3_100 * time + 0.55))
            case .fullStereoMix:
                let kick = beatPhase < 540
                    ? 0.2 * exp(-Double(beatPhase) / 150) * sin(2 * .pi * 76 * time)
                    : 0
                let bass = 0.09 * sin(2 * .pi * (55 + Double(variant)) * time)
                let center = slowEnvelope * (0.065 * sin(2 * .pi * 220 * time) + 0.028 * sin(2 * .pi * 440 * time))
                let sides = 0.038 * sin(2 * .pi * 330 * time)
                let hat = beatPhase % 1_500 < 85 ? random * 0.045 : 0
                left[index] = Float(kick + bass + center + sides + hat)
                right[index] = Float(kick + bass + center - sides - hat * 0.72)
            }
        }
        var channels: [[Float]] = switch sourceClass {
        case .vocal, .bass, .guitar: [left]
        case .drums, .synthKeys, .fullStereoMix: [left, right]
        }
        let peak = channels.flatMap { $0 }.map { abs(Double($0)) }.max() ?? 0
        if peak > 0 {
            // Representative production captures commonly use substantially
            // more headroom than the raw oscillator sum above. Normalize every
            // generated fixture to the same non-clipping peak so an absolute
            // dBFS distinctness gate is not biased by fixture level.
            let gain = 0.7 / peak
            for channel in channels.indices {
                for frame in channels[channel].indices {
                    channels[channel][frame] = Float(Double(channels[channel][frame]) * gain)
                }
            }
        }
        return AudioBuffer(channels: channels, sampleRate: sampleRate)
    }
}

private struct SeededNoise {
    var state: UInt64

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let normalized = Double((state >> 11) & 0x1F_FFFF) / Double(0x1F_FFFF)
        return normalized * 2 - 1
    }
}

private struct EvaluationFailure: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}
