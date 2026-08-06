import Foundation

/// The kind of help a question is asking for. Inferred, visible, and revisable
/// — the user never has to pick one.
public enum GeneralQuestionKind: String, Codable, CaseIterable, Sendable {
    case troubleshootProblem
    case achieveSoundOrFeeling
    case explainConcept
    case productionStrategy
    case compareOptions
    case exactWorkflowHelp
    case planSession
    case diagnoseTradeoff
    case researchUnfamiliar
}

/// Broad production domain taxonomy. This is retrieval and evaluation
/// structure, not a list of everything a user may say.
public enum ProductionDomain: String, Codable, CaseIterable, Sendable {
    // Source and performance
    case vocals, drumsAndPercussion, bass, guitar, pianoAndKeys, synth
    case orchestralAndAcoustic, fullMix, master, referenceTrack

    // Recording
    case microphonePlacement, roomAndReflections, gainStaging
    case interfacesAndMonitoring, performanceCapture, latency
    case noise, clipping, doublingAndLayering

    // Editing
    case comping, timingEditing, fades, cleanup, pitchEditing
    case vocalAlignment, drumEditing, regionEditing, fileVersusRegionScope

    // MIDI and performance
    case quantization, smartQuantize, groove, velocity, noteLength
    case sustainPedal, tempoMapping, rubato, handIndependence
    case humanization, articulation, expression

    // Processing
    case gain, polarityAndPhase, eqAndFiltering, compression
    case expansionAndGating, deEssing, dynamicEQ, multiband
    case saturation, clippingProcessing, distortion, transientShaping
    case pitchEffects, modulation, stereoImaging, limiting, metering

    // Space and depth
    case reverb, delay, preDelay, earlyReflections, width, depth
    case frontToBackPlacement, monoCompatibility

    // Routing
    case buses, sends, parallelProcessing, sidechains, groupProcessing
    case channelStripOrder, wetDryTopology

    // Automation
    case levelAutomation, panAutomation, effectAutomation, delayThrows
    case sectionChanges, movementAndTransitions

    // Arrangement and energy
    case density, contrast, verseChorusDevelopment, intros, bridges
    case drops, builds, transitions, registerAllocation, callAndResponse
    case orchestration

    // Mixing
    case balance, masking, focus, tonalDistribution, mixDynamics
    case mixDepth, mixWidth, translation, references, orderOfOperations

    // Mastering and delivery
    case loudness, peaks, masterDynamics, sequencing, formatAndExport
    case streamingDelivery, qualityControl

    // Monitoring and acoustics
    case listeningLevel, headphonesVersusMonitors, roomProblems
    case earFatigue, comparisonBias

    // Logic workflow
    case logicTools, logicEditors, flex, smartTempo, logicAutomation
    case logicRouting, pluginOperation, selectionAndScope
    case projectAlternatives, bounceAndExport, versionDifferences

    // Production decision-making
    case whatToTryFirst, comparingApproaches, knowingWhenToStop
    case preservingIntent, sourceVersusProcessingDecision
    case creativeAlternatives

    /// Coarse grouping used for retrieval routing and evaluation reporting.
    public var group: ProductionDomainGroup {
        switch self {
        case .vocals, .drumsAndPercussion, .bass, .guitar, .pianoAndKeys,
             .synth, .orchestralAndAcoustic, .fullMix, .master, .referenceTrack:
            return .sourceAndPerformance
        case .microphonePlacement, .roomAndReflections, .gainStaging,
             .interfacesAndMonitoring, .performanceCapture, .latency, .noise,
             .clipping, .doublingAndLayering:
            return .recording
        case .comping, .timingEditing, .fades, .cleanup, .pitchEditing,
             .vocalAlignment, .drumEditing, .regionEditing, .fileVersusRegionScope:
            return .editing
        case .quantization, .smartQuantize, .groove, .velocity, .noteLength,
             .sustainPedal, .tempoMapping, .rubato, .handIndependence,
             .humanization, .articulation, .expression:
            return .midiAndPerformance
        case .gain, .polarityAndPhase, .eqAndFiltering, .compression,
             .expansionAndGating, .deEssing, .dynamicEQ, .multiband, .saturation,
             .clippingProcessing, .distortion, .transientShaping, .pitchEffects,
             .modulation, .stereoImaging, .limiting, .metering:
            return .processing
        case .reverb, .delay, .preDelay, .earlyReflections, .width, .depth,
             .frontToBackPlacement, .monoCompatibility:
            return .spaceAndDepth
        case .buses, .sends, .parallelProcessing, .sidechains, .groupProcessing,
             .channelStripOrder, .wetDryTopology:
            return .routing
        case .levelAutomation, .panAutomation, .effectAutomation, .delayThrows,
             .sectionChanges, .movementAndTransitions:
            return .automation
        case .density, .contrast, .verseChorusDevelopment, .intros, .bridges,
             .drops, .builds, .transitions, .registerAllocation,
             .callAndResponse, .orchestration:
            return .arrangementAndEnergy
        case .balance, .masking, .focus, .tonalDistribution, .mixDynamics,
             .mixDepth, .mixWidth, .translation, .references, .orderOfOperations:
            return .mixing
        case .loudness, .peaks, .masterDynamics, .sequencing, .formatAndExport,
             .streamingDelivery, .qualityControl:
            return .masteringAndDelivery
        case .listeningLevel, .headphonesVersusMonitors, .roomProblems,
             .earFatigue, .comparisonBias:
            return .monitoringAndAcoustics
        case .logicTools, .logicEditors, .flex, .smartTempo, .logicAutomation,
             .logicRouting, .pluginOperation, .selectionAndScope,
             .projectAlternatives, .bounceAndExport, .versionDifferences:
            return .logicWorkflow
        case .whatToTryFirst, .comparingApproaches, .knowingWhenToStop,
             .preservingIntent, .sourceVersusProcessingDecision,
             .creativeAlternatives:
            return .productionDecisionMaking
        }
    }
}

public enum ProductionDomainGroup: String, Codable, CaseIterable, Sendable {
    case sourceAndPerformance
    case recording
    case editing
    case midiAndPerformance
    case processing
    case spaceAndDepth
    case routing
    case automation
    case arrangementAndEnergy
    case mixing
    case masteringAndDelivery
    case monitoringAndAcoustics
    case logicWorkflow
    case productionDecisionMaking
}

/// How a statement in an answer is warranted. Answers must never flatten these
/// into a single confidence number.
public enum GeneralEvidenceClass: String, Codable, CaseIterable, Sendable {
    case documentedBehavior
    case measuredBehavior
    case technicalInference
    case professionalPracticeHeuristic
    case subjectivePreference
    case userConfirmedPersonalResult
    case provisionalResearch
    case unresolvedOrDisputed
}

/// Source reliability tier. Tier C may surface questions and hypotheses but
/// never becomes factual or procedural authority on its own.
public enum SourceTier: String, Codable, CaseIterable, Sendable {
    case tierAPrimaryOrDirect
    case tierBReviewedProfessionalPractice
    case tierCDiscoveryOrAnecdotal
}
