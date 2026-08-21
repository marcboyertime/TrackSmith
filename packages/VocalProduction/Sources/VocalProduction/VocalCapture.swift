import AudioAnalysis
import Foundation

public enum VocalKnowledgeState: String, Codable, CaseIterable, Sendable {
    case known
    case unknown
    case userUnsure
    case notPresent
}

public enum VocalEquipmentKind: String, Codable, CaseIterable, Sendable {
    case microphone
    case audioInterface
    case externalPreamp
    case headphones
    case popFilter
}

public struct VocalEquipmentItem: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var kind: VocalEquipmentKind
    public var state: VocalKnowledgeState
    public var manufacturer: String?
    public var model: String?
    public var userConfirmedFeatures: [String]
    public var uncertainty: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        kind: VocalEquipmentKind,
        state: VocalKnowledgeState,
        manufacturer: String? = nil,
        model: String? = nil,
        userConfirmedFeatures: [String] = [],
        uncertainty: [String] = []
    ) {
        self.version = version
        self.kind = kind
        self.state = state
        self.manufacturer = manufacturer
        self.model = model
        self.userConfirmedFeatures = userConfirmedFeatures
        self.uncertainty = uncertainty
    }
}

public struct VocalCaptureEquipment: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var microphone: VocalEquipmentItem
    public var audioInterface: VocalEquipmentItem
    public var externalPreamp: VocalEquipmentItem
    public var headphones: VocalEquipmentItem
    public var popFilter: VocalEquipmentItem

    public init(
        version: VocalSchemaVersion = .v1,
        microphone: VocalEquipmentItem,
        audioInterface: VocalEquipmentItem,
        externalPreamp: VocalEquipmentItem,
        headphones: VocalEquipmentItem,
        popFilter: VocalEquipmentItem
    ) {
        self.version = version
        self.microphone = microphone
        self.audioInterface = audioInterface
        self.externalPreamp = externalPreamp
        self.headphones = headphones
        self.popFilter = popFilter
    }

    public var containsUnknownHardware: Bool {
        [microphone, audioInterface, externalPreamp, headphones, popFilter].contains {
            $0.state == .unknown || $0.state == .userUnsure
        }
    }
}

public enum VocalMicPattern: String, Codable, CaseIterable, Sendable {
    case cardioid
    case supercardioid
    case hypercardioid
    case omnidirectional
    case figureEight
    case selectableOther
}

public struct VocalMicPatternKnowledge: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var state: VocalKnowledgeState
    public var pattern: VocalMicPattern?
    public var confirmedByUser: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        state: VocalKnowledgeState,
        pattern: VocalMicPattern? = nil,
        confirmedByUser: Bool = false
    ) {
        self.version = version
        self.state = state
        self.pattern = state == .known ? pattern : nil
        self.confirmedByUser = state == .known && confirmedByUser
    }
}

public enum VocalConditionLevel: String, Codable, CaseIterable, Sendable {
    case unknown
    case low
    case moderate
    case high
}

public struct VocalCaptureEnvironment: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var backgroundNoise: VocalConditionLevel
    public var reflectionRisk: VocalConditionLevel
    public var roomSizeKnown: Bool
    public var roomDescription: String?
    public var movableSoftMaterialsAvailable: VocalKnowledgeState
    public var knownNoiseSources: [String]
    public var observations: [String]
    public var provenance: [VocalProvenance]

    public init(
        version: VocalSchemaVersion = .v1,
        backgroundNoise: VocalConditionLevel = .unknown,
        reflectionRisk: VocalConditionLevel = .unknown,
        roomSizeKnown: Bool = false,
        roomDescription: String? = nil,
        movableSoftMaterialsAvailable: VocalKnowledgeState = .unknown,
        knownNoiseSources: [String] = [],
        observations: [String] = [],
        provenance: [VocalProvenance] = []
    ) {
        self.version = version
        self.backgroundNoise = backgroundNoise
        self.reflectionRisk = reflectionRisk
        self.roomSizeKnown = roomSizeKnown
        self.roomDescription = roomDescription
        self.movableSoftMaterialsAvailable = movableSoftMaterialsAvailable
        self.knownNoiseSources = knownNoiseSources
        self.observations = observations
        self.provenance = provenance
    }
}

public enum VocalCaptureConstraintKind: String, Codable, CaseIterable, Sendable {
    case maximumSetupTime
    case mustRemainQuiet
    case fixedRoomPosition
    case fixedMicrophone
    case noAdditionalEquipment
    case performerComfort
    case hearingSafety
    case other
}

public struct VocalCaptureConstraint: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var kind: VocalCaptureConstraintKind
    public var description: String
    public var hardConstraint: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        kind: VocalCaptureConstraintKind,
        description: String,
        hardConstraint: Bool
    ) {
        self.version = version
        self.kind = kind
        self.description = description
        self.hardConstraint = hardConstraint
    }
}

public enum VocalCapturePriority: String, Codable, CaseIterable, Sendable {
    case intelligibility
    case naturalTone
    case intimacy
    case lowNoise
    case lowReflection
    case controlledPlosives
    case controlledSibilance
    case performanceComfort
    case dynamicRange
    case editability
}

public struct VocalCapturePriorityWeight: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var priority: VocalCapturePriority
    public var weight: Double

    public init(
        version: VocalSchemaVersion = .v1,
        priority: VocalCapturePriority,
        weight: Double
    ) {
        self.version = version
        self.priority = priority
        self.weight = min(max(weight.isFinite ? weight : 0, 0), 1)
    }
}

public enum VocalPerformanceAttribute: String, Codable, CaseIterable, Sendable {
    case emotionalDelivery
    case naturalDynamics
    case breathDetail
    case diction
    case pitchVariation
    case timingFeel
    case rasp
    case softness
    case projection
    case proximityEffect
    case movementFreedom
}

public struct VocalCaptureBrief: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var desiredResult: String
    public var priorities: [VocalCapturePriorityWeight]
    public var equipment: VocalCaptureEquipment
    public var microphonePattern: VocalMicPatternKnowledge
    public var environment: VocalCaptureEnvironment
    public var practicalConstraints: [VocalCaptureConstraint]
    public var preservePerformanceAttributes: [VocalPerformanceAttribute]
    public var preserveVoiceAttributes: [VocalAspect]
    public var assumptions: [String]
    public var missingInformation: [String]
    public var uncertainty: [String]
    public var provenance: [VocalProvenance]

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        desiredResult: String,
        priorities: [VocalCapturePriorityWeight],
        equipment: VocalCaptureEquipment,
        microphonePattern: VocalMicPatternKnowledge,
        environment: VocalCaptureEnvironment,
        practicalConstraints: [VocalCaptureConstraint] = [],
        preservePerformanceAttributes: [VocalPerformanceAttribute] = [],
        preserveVoiceAttributes: [VocalAspect] = [.voiceIdentity, .pitch, .timing, .dynamics],
        assumptions: [String] = [],
        missingInformation: [String] = [],
        uncertainty: [String] = [],
        provenance: [VocalProvenance] = []
    ) {
        self.version = version
        self.id = id
        self.desiredResult = desiredResult
        self.priorities = priorities
        self.equipment = equipment
        self.microphonePattern = microphonePattern
        self.environment = environment
        self.practicalConstraints = practicalConstraints
        self.preservePerformanceAttributes = preservePerformanceAttributes
        self.preserveVoiceAttributes = preserveVoiceAttributes
        self.assumptions = assumptions
        self.missingInformation = missingInformation
        self.uncertainty = uncertainty
        self.provenance = provenance
    }
}

public enum VocalRelativeDistance: String, Codable, CaseIterable, Sendable {
    case currentMarked
    case veryClose
    case close
    case moderate
    case farther
}

public enum VocalRelativeHeight: String, Codable, CaseIterable, Sendable {
    case currentMarked
    case belowMouth
    case mouthLevel
    case slightlyAboveMouth
}

public enum VocalRelativeAngle: String, Codable, CaseIterable, Sendable {
    case currentMarked
    case onAxis
    case slightlyOffAxis
    case moderatelyOffAxis
}

public enum VocalRoomPositionStrategy: String, Codable, CaseIterable, Sendable {
    case preserveCurrentPosition
    case moveAwayFromNearestHardBoundary
    case faceTowardSofterIrregularArea
    case compareTwoAvailablePositions
}

public struct VocalMicPlacement: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var distance: VocalRelativeDistance
    public var height: VocalRelativeHeight
    public var angle: VocalRelativeAngle
    public var popFilterUse: VocalKnowledgeState
    public var popFilterPosition: String
    public var performerOrientation: String
    public var boundedAdjustment: String

    public init(
        version: VocalSchemaVersion = .v1,
        distance: VocalRelativeDistance,
        height: VocalRelativeHeight,
        angle: VocalRelativeAngle,
        popFilterUse: VocalKnowledgeState,
        popFilterPosition: String,
        performerOrientation: String,
        boundedAdjustment: String
    ) {
        self.version = version
        self.distance = distance
        self.height = height
        self.angle = angle
        self.popFilterUse = popFilterUse
        self.popFilterPosition = popFilterPosition
        self.performerOrientation = performerOrientation
        self.boundedAdjustment = boundedAdjustment
    }
}

public enum VocalGainDirection: String, Codable, CaseIterable, Sendable {
    case preserve
    case reduceOneSmallStep
    case increaseOneSmallStep
    case setFromLoudestPass
}

public struct VocalGainAndHeadroomPlan: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var direction: VocalGainDirection
    public var loudestPassPeakTargetDBFS: ClosedRange<Double>
    public var instruction: String
    public var unknownHardwareBoundary: String

    public init(
        version: VocalSchemaVersion = .v1,
        direction: VocalGainDirection,
        loudestPassPeakTargetDBFS: ClosedRange<Double> = -18 ... -10,
        instruction: String,
        unknownHardwareBoundary: String = "Use the interface's own meter and one small relative gain move; no knob position or device-specific behavior is assumed."
    ) {
        self.version = version
        self.direction = direction
        self.loudestPassPeakTargetDBFS = loudestPassPeakTargetDBFS
        self.instruction = instruction
        self.unknownHardwareBoundary = unknownHardwareBoundary
    }
}

public struct VocalMonitoringPlan: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var instruction: String
    public var hearingSafetyConstraint: String
    public var latencyBoundary: String

    public init(
        version: VocalSchemaVersion = .v1,
        instruction: String,
        hearingSafetyConstraint: String,
        latencyBoundary: String
    ) {
        self.version = version
        self.instruction = instruction
        self.hearingSafetyConstraint = hearingSafetyConstraint
        self.latencyBoundary = latencyBoundary
    }
}

public struct VocalCaptureComparisonProtocol: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var testTakeLabel: String
    public var exactProcedure: [String]
    public var variablesHeldConstant: [String]
    public var listenFor: [String]
    public var warningSigns: [String]
    public var stopRule: String
    public var rollbackInstructions: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        testTakeLabel: String,
        exactProcedure: [String],
        variablesHeldConstant: [String],
        listenFor: [String],
        warningSigns: [String],
        stopRule: String,
        rollbackInstructions: [String]
    ) {
        self.version = version
        self.testTakeLabel = testTakeLabel
        self.exactProcedure = exactProcedure
        self.variablesHeldConstant = variablesHeldConstant
        self.listenFor = listenFor
        self.warningSigns = warningSigns
        self.stopRule = stopRule
        self.rollbackInstructions = rollbackInstructions
    }
}

public struct VocalCaptureInterpretation: Codable, Equatable, Identifiable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var parentInterpretationID: UUID?
    public var revisionID: UUID?
    public var ancestry: [UUID]
    public var title: String
    public var hypothesis: String
    public var placement: VocalMicPlacement
    public var roomPosition: VocalRoomPositionStrategy
    public var reflectionRisk: VocalConditionLevel
    public var gainAndHeadroom: VocalGainAndHeadroomPlan
    public var monitoring: VocalMonitoringPlan
    public var performanceAndProximityConsiderations: [String]
    public var comparison: VocalCaptureComparisonProtocol
    public var assumptions: [String]
    public var missingInformation: [String]
    public var uncertainty: [String]
    public var provenance: [VocalProvenance]

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        parentInterpretationID: UUID? = nil,
        revisionID: UUID? = nil,
        ancestry: [UUID] = [],
        title: String,
        hypothesis: String,
        placement: VocalMicPlacement,
        roomPosition: VocalRoomPositionStrategy,
        reflectionRisk: VocalConditionLevel,
        gainAndHeadroom: VocalGainAndHeadroomPlan,
        monitoring: VocalMonitoringPlan,
        performanceAndProximityConsiderations: [String],
        comparison: VocalCaptureComparisonProtocol,
        assumptions: [String],
        missingInformation: [String],
        uncertainty: [String],
        provenance: [VocalProvenance]
    ) {
        self.version = version
        self.id = id
        self.parentInterpretationID = parentInterpretationID
        self.revisionID = revisionID
        self.ancestry = ancestry
        self.title = title
        self.hypothesis = hypothesis
        self.placement = placement
        self.roomPosition = roomPosition
        self.reflectionRisk = reflectionRisk
        self.gainAndHeadroom = gainAndHeadroom
        self.monitoring = monitoring
        self.performanceAndProximityConsiderations = performanceAndProximityConsiderations
        self.comparison = comparison
        self.assumptions = assumptions
        self.missingInformation = missingInformation
        self.uncertainty = uncertainty
        self.provenance = provenance
    }
}

public enum VocalCapturePlannerError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidBrief(String)
    case invalidIdentityCount(Int)

    public var description: String {
        switch self {
        case let .invalidBrief(reason): "Invalid vocal capture brief: \(reason)"
        case let .invalidIdentityCount(count): "Vocal capture planning requires exactly three unique interpretation IDs; received \(count)."
        }
    }
}

public struct VocalCapturePlanner: Sendable {
    public init() {}

    private enum InterpretationKind: Int, Sendable {
        case directAndControlled
        case balancedArticulation
        case reflectionAndBreathStressTest
    }

    private struct InterpretationSpecification: Sendable {
        var kind: InterpretationKind
        var title: String
        var hypothesis: String
        var placement: VocalMicPlacement
        var room: VocalRoomPositionStrategy
        var gain: VocalGainAndHeadroomPlan
        var considerations: [String]
    }

    public func plan(
        brief: VocalCaptureBrief,
        interpretationIDs: [UUID] = [UUID(), UUID(), UUID()]
    ) throws -> [VocalCaptureInterpretation] {
        guard !brief.desiredResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VocalCapturePlannerError.invalidBrief("The desired result is empty.")
        }
        let equipmentKinds: [(VocalEquipmentItem, VocalEquipmentKind)] = [
            (brief.equipment.microphone, .microphone),
            (brief.equipment.audioInterface, .audioInterface),
            (brief.equipment.externalPreamp, .externalPreamp),
            (brief.equipment.headphones, .headphones),
            (brief.equipment.popFilter, .popFilter),
        ]
        guard equipmentKinds.allSatisfy({ $0.0.kind == $0.1 }) else {
            throw VocalCapturePlannerError.invalidBrief("Equipment fields and typed equipment kinds disagree.")
        }
        guard brief.microphonePattern.state != .known || brief.microphonePattern.pattern != nil else {
            throw VocalCapturePlannerError.invalidBrief("A known microphone pattern requires a typed pattern value.")
        }
        guard brief.priorities.allSatisfy({ $0.weight.isFinite && (0...1).contains($0.weight) }) else {
            throw VocalCapturePlannerError.invalidBrief("Capture priority weights must be finite and inside 0...1.")
        }
        guard interpretationIDs.count == 3, Set(interpretationIDs).count == 3 else {
            throw VocalCapturePlannerError.invalidIdentityCount(interpretationIDs.count)
        }
        guard brief.equipment.microphone.state != .notPresent else {
            throw VocalCapturePlannerError.invalidBrief(
                "A capture plan cannot claim a microphone setup when the microphone is reported absent."
            )
        }
        let facts = try captureFacts(for: brief)

        let sharedUncertainty = uniqueStrings(brief.uncertainty + facts.uncertainty + (facts.hasUnknownHardwareBoundary ? [
            "Hardware or pickup behavior is unknown; every proposal is a relative, reversible listening experiment rather than a device-specific prediction.",
        ] : []))
        let sharedMissing = uniqueStrings(brief.missingInformation + missingInformation(for: brief))
        let reflectionRisk = brief.environment.reflectionRisk
        let sourceProvenance = brief.provenance + [
            VocalProvenance(
                identifier: "capture-relative-comparison-v1",
                evidenceKind: .professionalPracticeHeuristic,
                statement: "Change one bounded capture variable at a time and compare the same passage at matched playback level.",
                limitations: ["The preferred result is listening-only and performer-dependent."],
                confidence: 0.72
            ),
        ]

        let specifications: [InterpretationSpecification] = [
            InterpretationSpecification(
                kind: .directAndControlled,
                title: "Direct and controlled",
                hypothesis: "For the stated result “\(facts.desiredResult)”, a closer, slightly off-axis comparison may increase direct-vocal share while limiting breath blasts; only the comparison take can establish whether it suits this singer and microphone.",
                placement: VocalMicPlacement(
                    distance: .close,
                    height: .slightlyAboveMouth,
                    angle: .slightlyOffAxis,
                    popFilterUse: facts.popFilterState,
                    popFilterPosition: facts.popFilterInstruction,
                    performerOrientation: "Aim the voice just past the capsule while keeping posture comfortable.",
                    boundedAdjustment: "Start at the current safe distance, move one hand-width closer at most, and return to the floor/stand marks if proximity or plosives worsen."
                ),
                room: reflectionRisk == .high ? .faceTowardSofterIrregularArea : .preserveCurrentPosition,
                gain: VocalGainAndHeadroomPlan(
                    direction: .setFromLoudestPass,
                    instruction: "Perform the loudest expected phrase, then change input gain only enough that the loudest meter peaks remain inside the stated headroom range."
                ),
                considerations: [
                    "Closer placement can change low-frequency balance and mouth detail; treat both as listening judgments, not guaranteed proximity behavior.",
                    "Stop if posture, pitch delivery, breath control, or emotional delivery becomes less natural.",
                ]
            ),
            InterpretationSpecification(
                kind: .balancedArticulation,
                title: "Balanced articulation",
                hypothesis: "For the stated result “\(facts.desiredResult)”, a moderate, mouth-level comparison can trade some immediacy for more even movement tolerance and may make consonant balance easier to judge.",
                placement: VocalMicPlacement(
                    distance: .moderate,
                    height: .mouthLevel,
                    angle: .onAxis,
                    popFilterUse: facts.popFilterState,
                    popFilterPosition: facts.popFilterInstruction,
                    performerOrientation: "Sing toward the capsule with the usual performance posture.",
                    boundedAdjustment: "Move one hand-width farther than the direct interpretation; do not change angle and distance in the same take."
                ),
                room: .moveAwayFromNearestHardBoundary,
                gain: VocalGainAndHeadroomPlan(
                    direction: .setFromLoudestPass,
                    instruction: "Repeat the identical loudest-pass calibration after moving the microphone; do not copy a knob position from another distance."
                ),
                considerations: [
                    "The moderate position may tolerate small performance movement, but room contribution can increase; listen rather than assume.",
                    "Keep the singer's delivery and monitoring balance stable across the comparison.",
                ]
            ),
            InterpretationSpecification(
                kind: .reflectionAndBreathStressTest,
                title: "Reflection and breath stress test",
                hypothesis: "For the stated result “\(facts.desiredResult)”, a moderately off-axis, alternate room-orientation comparison tests whether local reflections or breath energy are the dominant capture risk without changing or assuming equipment.",
                placement: VocalMicPlacement(
                    distance: .moderate,
                    height: .slightlyAboveMouth,
                    angle: .moderatelyOffAxis,
                    popFilterUse: facts.popFilterState,
                    popFilterPosition: facts.popFilterInstruction,
                    performerOrientation: "Keep the mouth-to-stand distance repeatable while directing the strongest breath past the capsule.",
                    boundedAdjustment: "Compare only the marked current position and one available position facing a softer or irregular area; make no unmarked room sweep."
                ),
                room: .compareTwoAvailablePositions,
                gain: VocalGainAndHeadroomPlan(
                    direction: .setFromLoudestPass,
                    instruction: "Recalibrate from one loudest pass after the position change, using only the input meter and the same peak range."
                ),
                considerations: [
                    "Off-axis response is microphone-dependent and unknown unless documented for the exact microphone; judge diction and tone by playback.",
                    "This test does not identify a room mode, reflection path, plosive, or sibilant phoneme.",
                ]
            ),
        ]

        let rankedSpecifications = specifications.enumerated().sorted { lhs, rhs in
            let lhsScore = priorityFitScore(for: lhs.element.kind, weights: facts.priorityWeights)
            let rhsScore = priorityFitScore(for: rhs.element.kind, weights: facts.priorityWeights)
            if lhsScore == rhsScore { return lhs.offset < rhs.offset }
            return lhsScore > rhsScore
        }.map(\.element)

        var interpretations: [VocalCaptureInterpretation] = []
        interpretations.reserveCapacity(rankedSpecifications.count)
        for (index, spec) in rankedSpecifications.enumerated() {
            let id = interpretationIDs[index]
            let placement = constrainedPlacement(spec.placement, facts: facts)
            let roomPosition = facts.fixedRoomPosition ? .preserveCurrentPosition : spec.room
            var gain = spec.gain
            gain.instruction += " Capture path held constant: \(facts.capturePathInstruction)"
            gain.unknownHardwareBoundary = facts.gainBoundary
            let priorityFit = priorityFitExplanation(for: spec.kind, weights: facts.priorityWeights)
            let considerations = uniqueStrings(
                spec.considerations
                    + facts.priorityTradeoffs
                    + facts.preservationChecks
                    + facts.hardConstraintTradeoffs
            )
            var assumptionFields: [String] = []
            assumptionFields.reserveCapacity(
                brief.assumptions.count + 3 + facts.equipmentFacts.count + facts.patternFacts.count
                    + facts.roomNoiseFacts.count + facts.hardConstraintFacts.count + facts.preservationChecks.count
            )
            assumptionFields.append(contentsOf: brief.assumptions)
            assumptionFields.append("Desired capture result supplied by the musician: \(facts.desiredResult)")
            assumptionFields.append(facts.prioritySummary)
            assumptionFields.append(priorityFit)
            assumptionFields.append(contentsOf: facts.equipmentFacts)
            assumptionFields.append(contentsOf: facts.patternFacts)
            assumptionFields.append(contentsOf: facts.roomNoiseFacts)
            assumptionFields.append(contentsOf: facts.hardConstraintFacts)
            assumptionFields.append(contentsOf: facts.preservationChecks)
            let assumptions = uniqueStrings(assumptionFields)
            let comparison = comparisonProtocol(
                index: index,
                interpretationID: id,
                facts: facts,
                placement: placement,
                roomPosition: roomPosition
            )
            let interpretation = VocalCaptureInterpretation(
                id: id,
                title: spec.title,
                hypothesis: "\(spec.hypothesis) \(priorityFit)",
                placement: placement,
                roomPosition: roomPosition,
                reflectionRisk: reflectionRisk,
                gainAndHeadroom: gain,
                monitoring: monitoringPlan(facts: facts),
                performanceAndProximityConsiderations: considerations,
                comparison: comparison,
                assumptions: assumptions,
                missingInformation: sharedMissing,
                uncertainty: sharedUncertainty,
                provenance: sourceProvenance
            )
            interpretations.append(interpretation)
        }
        return interpretations
    }

    private func missingInformation(for brief: VocalCaptureBrief) -> [String] {
        var result: [String] = []
        let equipment: [(String, VocalEquipmentItem)] = [
            ("microphone", brief.equipment.microphone),
            ("audio interface", brief.equipment.audioInterface),
            ("external preamp", brief.equipment.externalPreamp),
            ("headphones", brief.equipment.headphones),
            ("pop filter", brief.equipment.popFilter),
        ]
        for (label, item) in equipment {
            switch item.state {
            case .unknown:
                result.append("The \(label) is unknown.")
            case .userUnsure:
                result.append("The musician is unsure about the \(label).")
            case .known, .notPresent:
                break
            }
        }
        if brief.microphonePattern.state != .known || !brief.microphonePattern.confirmedByUser {
            result.append("Microphone pickup pattern is not user-confirmed.")
        }
        if brief.environment.backgroundNoise == .unknown { result.append("Background-noise condition has not been confirmed by listening.") }
        if brief.environment.reflectionRisk == .unknown { result.append("Reflection condition has not been confirmed by listening.") }
        if !brief.environment.roomSizeKnown { result.append("Room size is not confirmed.") }
        if brief.environment.movableSoftMaterialsAvailable == .unknown || brief.environment.movableSoftMaterialsAvailable == .userUnsure {
            result.append("Availability of movable soft materials is not confirmed.")
        }
        return uniqueStrings(result)
    }

    private func comparisonProtocol(
        index: Int,
        interpretationID: UUID,
        facts: CaptureFacts,
        placement: VocalMicPlacement,
        roomPosition: VocalRoomPositionStrategy
    ) -> VocalCaptureComparisonProtocol {
        let label = "vocal-capture-\(index + 1)-\(interpretationID.uuidString.lowercased())"
        let procedure = uniqueStrings([
            "Target supplied by the musician: \(facts.desiredResult)",
            facts.prioritySummary,
            "Interpretation \(index + 1) uses the typed relation \(placement.distance.rawValue), \(placement.height.rawValue), \(placement.angle.rawValue), with room strategy \(roomPosition.rawValue).",
        ] + facts.hardConstraintFacts + facts.roomNoiseFacts + [
            "Mark the stand, singer foot position, input-gain position, and monitor level before moving anything.",
            "Record the same short passage once at normal delivery and once at the loudest expected delivery; announce label \(label) before recording.",
            "Check the input meter for clipping before continuing. If it clips, stop, lower input gain one small step, relabel, and retake.",
            "Play all candidates at matched perceived playback level; do not prefer the louder file by default.",
        ])
        let listenFor = uniqueStrings([
            "Does the take move toward the musician's stated result: \(facts.desiredResult)?",
        ] + facts.priorityChecks + facts.preservationChecks + [
            "word clarity without exaggerated consonants",
            "natural voice identity and desired emotion",
            "low-frequency balance and mouth detail",
            "between-phrase noise and apparent room/reflections",
            "breath blasts or sharp high-frequency events",
        ])
        let warnings = uniqueStrings(facts.preservationWarnings + facts.priorityWarnings + [
            "any clipped sample or red input indication",
            "worse diction, hollow/thin tone, excessive low-frequency buildup, or distracting mouth noise",
            "stronger apparent room sound, new comb-like coloration, headphone spill, discomfort, or inhibited performance",
        ])
        return VocalCaptureComparisonProtocol(
            testTakeLabel: label,
            exactProcedure: procedure,
            variablesHeldConstant: uniqueStrings([
                "same passage and lyrics",
                "same intended delivery and posture",
                facts.fixedMicrophone
                    ? "the hard fixed-microphone constraint: microphone and stand stay in the recorded position"
                    : facts.capturePathInstruction,
                facts.patternHeldConstant,
                "same playback position and matched comparison level",
            ] + facts.hardConstraintTradeoffs),
            listenFor: listenFor,
            warningSigns: warnings,
            stopRule: uniqueStrings([
                "Stop the experiment immediately on clipping, hearing discomfort, equipment instability, or a clear loss of the selected preservation attributes; do not keep moving farther in the same direction.",
            ] + facts.stopConditions).joined(separator: " "),
            rollbackInstructions: uniqueStrings([
                "Return the stand and singer to the photographed or taped starting marks.",
                "Return input gain and monitor level to their recorded starting marks.",
                "Restore the original microphone angle, pattern only if user-confirmed, pop-filter state, and processing bypass state.",
                "Retain every labeled take; never overwrite the prior capture while comparing.",
            ] + facts.rollbackInstructions)
        )
    }

    private struct CaptureFacts {
        var desiredResult: String
        var priorityWeights: [VocalCapturePriority: Double]
        var prioritySummary: String
        var priorityChecks: [String]
        var priorityTradeoffs: [String]
        var priorityWarnings: [String]
        var equipmentFacts: [String]
        var patternFacts: [String]
        var roomNoiseFacts: [String]
        var hardConstraintFacts: [String]
        var hardConstraintTradeoffs: [String]
        var preservationChecks: [String]
        var preservationWarnings: [String]
        var stopConditions: [String]
        var rollbackInstructions: [String]
        var uncertainty: [String]
        var hasUnknownHardwareBoundary: Bool
        var fixedRoomPosition: Bool
        var fixedMicrophone: Bool
        var noAdditionalEquipment: Bool
        var mustRemainQuiet: Bool
        var hasMaximumSetupTime: Bool
        var popFilterState: VocalKnowledgeState
        var popFilterInstruction: String
        var monitoringInstruction: String
        var monitoringLatencyBoundary: String
        var gainBoundary: String
        var capturePathInstruction: String
        var patternHeldConstant: String
    }

    private func captureFacts(for brief: VocalCaptureBrief) throws -> CaptureFacts {
        guard !brief.priorities.isEmpty else {
            throw VocalCapturePlannerError.invalidBrief("At least one weighted capture priority is required.")
        }
        guard Set(brief.priorities.map(\.priority)).count == brief.priorities.count else {
            throw VocalCapturePlannerError.invalidBrief("Each capture priority must appear once so its weight has an unambiguous effect.")
        }
        guard brief.priorities.contains(where: { $0.weight > 0 }) else {
            throw VocalCapturePlannerError.invalidBrief("At least one capture priority must have a nonzero weight.")
        }
        let constraints = brief.practicalConstraints.sorted {
            constraintSortKey($0) < constraintSortKey($1)
        }
        guard constraints.allSatisfy({ !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw VocalCapturePlannerError.invalidBrief("Every capture constraint needs a description that can be checked during the comparison.")
        }
        let hardConstraints = constraints.filter(\.hardConstraint)
        let priorities = brief.priorities.sorted {
            if $0.weight == $1.weight { return $0.priority.rawValue < $1.priority.rawValue }
            return $0.weight > $1.weight
        }
        let priorityWeights = Dictionary(uniqueKeysWithValues: priorities.map { ($0.priority, $0.weight) })
        let equipment: [(String, VocalEquipmentItem)] = [
            ("Microphone", brief.equipment.microphone),
            ("Audio interface", brief.equipment.audioInterface),
            ("External preamp", brief.equipment.externalPreamp),
            ("Headphones", brief.equipment.headphones),
            ("Pop filter", brief.equipment.popFilter),
        ]
        let equipmentFacts = equipment.map { equipmentFact(label: $0.0, item: $0.1) }
        let patternFacts = microphonePatternFacts(brief.microphonePattern)
        let roomNoiseFacts = roomNoiseFacts(for: brief.environment)
        let fixedRoomPosition = containsHardConstraint(.fixedRoomPosition, in: hardConstraints)
        let fixedMicrophone = containsHardConstraint(.fixedMicrophone, in: hardConstraints)
        let noAdditionalEquipment = containsHardConstraint(.noAdditionalEquipment, in: hardConstraints)
        let mustRemainQuiet = containsHardConstraint(.mustRemainQuiet, in: hardConstraints)
        let hasMaximumSetupTime = containsHardConstraint(.maximumSetupTime, in: hardConstraints)
        let hasHearingSafety = containsHardConstraint(.hearingSafety, in: hardConstraints)
        let hasComfort = containsHardConstraint(.performerComfort, in: hardConstraints)
        let hardConstraintFacts = constraints.isEmpty
            ? ["No capture constraint was supplied; use only the bounded one-variable comparison stated in this plan."]
            : constraints.map {
                "\($0.hardConstraint ? "Hard constraint" : "Preference constraint") (\($0.kind.rawValue)): \($0.description)"
            }
        var hardTradeoffs: [String] = []
        var stopConditions: [String] = []
        var rollback: [String] = []
        if fixedRoomPosition {
            hardTradeoffs.append("The fixed-room-position constraint removes room-position alternatives; candidates differ only through allowed local comparison conditions.")
            rollback.append("Confirm that the hard fixed-room-position condition remains satisfied before accepting any take.")
        }
        if fixedMicrophone {
            hardTradeoffs.append("The fixed-microphone constraint permits no microphone/stand movement; any comparison movement is made by the performer only.")
            rollback.append("Verify the microphone and stand remain at their recorded fixed position before rolling back.")
        }
        if noAdditionalEquipment {
            hardTradeoffs.append("No additional equipment is introduced, improvised, purchased, or substituted; only the reported setup may be used.")
        }
        if mustRemainQuiet {
            hardTradeoffs.append("The quiet-setup constraint favors marks, existing controls, and room-tone documentation over noisy setup experiments.")
            stopConditions.append("Stop if the next setup action would violate the required quiet condition.")
        }
        if hasMaximumSetupTime {
            hardTradeoffs.append("The maximum-setup-time constraint limits each candidate to the recorded start plus one bounded comparison move.")
            stopConditions.append("Stop when the musician's stated maximum setup time is reached; do not trade time compliance for another trial.")
        }
        if hasComfort {
            stopConditions.append("Stop and roll back if the performer-comfort constraint is no longer satisfied.")
        }
        if hasHearingSafety {
            stopConditions.append("Stop and lower monitoring if the hearing-safety constraint is no longer satisfied.")
        }
        for constraint in hardConstraints where constraint.kind == .other {
            hardTradeoffs.append("The other hard constraint is a manual check, not a capability claim: \(constraint.description)")
            stopConditions.append("Stop if the manually checked other hard constraint is not satisfied: \(constraint.description)")
        }
        for constraint in constraints where !constraint.hardConstraint {
            hardTradeoffs.append(
                "Preference constraint (\(constraint.kind.rawValue)) is retained for comparison but is not treated as authority to violate a hard stop: \(constraint.description)"
            )
        }

        let performance = Array(Set(brief.preservePerformanceAttributes)).sorted { $0.rawValue < $1.rawValue }
        let voice = Array(Set(brief.preserveVoiceAttributes)).sorted { $0.rawValue < $1.rawValue }
        let preservationChecks = preservationChecks(performance: performance, voice: voice)
        let preservationWarnings = preservationWarnings(performance: performance, voice: voice)
        let unknownHardware = brief.equipment.containsUnknownHardware
            || brief.microphonePattern.state != .known
            || !brief.microphonePattern.confirmedByUser
            || knownMicrophoneIdentityIsIncomplete(brief.equipment.microphone)
        var uncertainty: [String] = []
        if brief.microphonePattern.state == .known && !brief.microphonePattern.confirmedByUser {
            uncertainty.append("The microphone pattern has a typed value but is not user-confirmed, so no directional behavior is assumed.")
        }
        if knownMicrophoneIdentityIsIncomplete(brief.equipment.microphone) {
            uncertainty.append("The microphone is marked known without a maker or model, so no device-specific response or setting is assumed.")
        }
        if brief.environment.movableSoftMaterialsAvailable == .unknown || brief.environment.movableSoftMaterialsAvailable == .userUnsure {
            uncertainty.append("Movable soft-material availability is unresolved; no treatment placement is assumed.")
        }
        let prioritySummary = "Weighted priorities (highest first): " + priorities.map {
            "\(priorityLabel($0.priority))=\(formatWeight($0.weight))"
        }.joined(separator: ", ") + "."
        let priorityChecks = priorities.map {
            "Priority \(priorityLabel($0.priority)) (weight \(formatWeight($0.weight))): \(priorityCheck($0.priority))"
        }
        let priorityTradeoffs = priorities.map {
            "Tradeoff for \(priorityLabel($0.priority)) at weight \(formatWeight($0.weight)): \(priorityTradeoff($0.priority))"
        }
        let priorityWarnings = priorities.compactMap { priority in
            priorityWarning(priority.priority).map { warning in
                "Priority warning for \(priorityLabel(priority.priority)): \(warning)"
            }
        }
        let popFilterInstruction = popFilterInstruction(for: brief.equipment.popFilter.state)
        let monitoring = monitoringGuidance(
            headphoneState: brief.equipment.headphones.state,
            hearingSafetyIsHard: hasHearingSafety
        )
        let gainBoundary = unknownHardware
            ? "Use the available meter and one small relative gain move only. Unknown or unconfirmed hardware details never authorize a device-specific knob position, pad, pattern, or preamp behavior claim."
            : "Reported hardware identities remain user-reported labels. Use the available meter and one small relative gain move; no device-specific knob position or response is inferred."
        let capturePathInstruction = capturePathInstruction(for: brief.equipment)
        let patternHeldConstant = patternHeldConstant(brief.microphonePattern)
        return CaptureFacts(
            desiredResult: brief.desiredResult.trimmingCharacters(in: .whitespacesAndNewlines),
            priorityWeights: priorityWeights,
            prioritySummary: prioritySummary,
            priorityChecks: priorityChecks,
            priorityTradeoffs: priorityTradeoffs,
            priorityWarnings: priorityWarnings,
            equipmentFacts: equipmentFacts,
            patternFacts: patternFacts,
            roomNoiseFacts: roomNoiseFacts,
            hardConstraintFacts: hardConstraintFacts,
            hardConstraintTradeoffs: hardTradeoffs,
            preservationChecks: preservationChecks,
            preservationWarnings: preservationWarnings,
            stopConditions: stopConditions,
            rollbackInstructions: rollback,
            uncertainty: uncertainty,
            hasUnknownHardwareBoundary: unknownHardware,
            fixedRoomPosition: fixedRoomPosition,
            fixedMicrophone: fixedMicrophone,
            noAdditionalEquipment: noAdditionalEquipment,
            mustRemainQuiet: mustRemainQuiet,
            hasMaximumSetupTime: hasMaximumSetupTime,
            popFilterState: brief.equipment.popFilter.state,
            popFilterInstruction: popFilterInstruction,
            monitoringInstruction: monitoring.instruction,
            monitoringLatencyBoundary: monitoring.latencyBoundary,
            gainBoundary: gainBoundary,
            capturePathInstruction: capturePathInstruction,
            patternHeldConstant: patternHeldConstant
        )
    }

    private func constrainedPlacement(
        _ input: VocalMicPlacement,
        facts: CaptureFacts
    ) -> VocalMicPlacement {
        var placement = input
        placement.popFilterUse = facts.popFilterState
        placement.popFilterPosition = facts.popFilterInstruction
        if facts.fixedRoomPosition {
            placement.distance = .currentMarked
            placement.height = .currentMarked
            placement.angle = .currentMarked
            placement.performerOrientation = "Preserve the photographed or taped starting microphone/performer relationship."
            placement.boundedAdjustment = "Keep the microphone and performer at the current room position. This candidate is a listening focus only; do not create a room-position sweep or claim an unmeasured alternate placement."
        } else if facts.fixedMicrophone {
            placement.boundedAdjustment = "Keep the microphone and stand fixed. If this comparison changes the typed relationship, move the performer one marked step only; do not move the microphone."
        } else if facts.hasMaximumSetupTime {
            placement.boundedAdjustment = "Use the recorded start plus one marked bounded move only, then compare; the stated maximum setup time blocks further exploration."
        }
        if facts.noAdditionalEquipment {
            placement.boundedAdjustment += " Do not add, improvise, or substitute equipment."
        }
        if facts.mustRemainQuiet {
            placement.boundedAdjustment += " Keep setup actions quiet and use marks rather than repeated repositioning."
        }
        return placement
    }

    private func monitoringPlan(facts: CaptureFacts) -> VocalMonitoringPlan {
        VocalMonitoringPlan(
            instruction: facts.monitoringInstruction,
            hearingSafetyConstraint: "Stop and lower monitoring immediately if it is uncomfortable; capture quality never justifies unsafe level.",
            latencyBoundary: facts.monitoringLatencyBoundary
        )
    }

    private func priorityFitScore(
        for kind: InterpretationKind,
        weights: [VocalCapturePriority: Double]
    ) -> Double {
        VocalCapturePriority.allCases.reduce(into: 0) { total, priority in
            total += weights[priority, default: 0] * priorityAffinity(priority, for: kind)
        }
    }

    private func priorityFitExplanation(
        for kind: InterpretationKind,
        weights: [VocalCapturePriority: Double]
    ) -> String {
        let ranked = weights
            .filter { $0.value > 0 }
            .sorted {
                if $0.value == $1.value { return $0.key.rawValue < $1.key.rawValue }
                return $0.value > $1.value
            }
        let leading = ranked.prefix(3).map {
            "\(priorityLabel($0.key))=\(formatWeight($0.value))"
        }.joined(separator: ", ")
        return "Deterministic weighted fit \(formatWeight(priorityFitScore(for: kind, weights: weights))) using all supplied priorities; leading inputs: \(leading)."
    }

    private func priorityAffinity(
        _ priority: VocalCapturePriority,
        for kind: InterpretationKind
    ) -> Double {
        switch (kind, priority) {
        case (.directAndControlled, .intelligibility): 1.15
        case (.directAndControlled, .naturalTone): 0.75
        case (.directAndControlled, .intimacy): 1.60
        case (.directAndControlled, .lowNoise): 1.35
        case (.directAndControlled, .lowReflection): 0.55
        case (.directAndControlled, .controlledPlosives): 1.00
        case (.directAndControlled, .controlledSibilance): 0.75
        case (.directAndControlled, .performanceComfort): 0.70
        case (.directAndControlled, .dynamicRange): 0.70
        case (.directAndControlled, .editability): 0.55

        case (.balancedArticulation, .intelligibility): 1.45
        case (.balancedArticulation, .naturalTone): 1.65
        case (.balancedArticulation, .intimacy): 0.65
        case (.balancedArticulation, .lowNoise): 0.75
        case (.balancedArticulation, .lowReflection): 0.80
        case (.balancedArticulation, .controlledPlosives): 0.65
        case (.balancedArticulation, .controlledSibilance): 0.85
        case (.balancedArticulation, .performanceComfort): 1.50
        case (.balancedArticulation, .dynamicRange): 1.30
        case (.balancedArticulation, .editability): 1.00

        case (.reflectionAndBreathStressTest, .intelligibility): 0.90
        case (.reflectionAndBreathStressTest, .naturalTone): 0.65
        case (.reflectionAndBreathStressTest, .intimacy): 0.35
        case (.reflectionAndBreathStressTest, .lowNoise): 1.10
        case (.reflectionAndBreathStressTest, .lowReflection): 1.80
        case (.reflectionAndBreathStressTest, .controlledPlosives): 1.55
        case (.reflectionAndBreathStressTest, .controlledSibilance): 1.40
        case (.reflectionAndBreathStressTest, .performanceComfort): 0.55
        case (.reflectionAndBreathStressTest, .dynamicRange): 0.80
        case (.reflectionAndBreathStressTest, .editability): 1.25
        }
    }

    private func capturePathInstruction(for equipment: VocalCaptureEquipment) -> String {
        let items = [equipment.microphone, equipment.audioInterface, equipment.externalPreamp]
        let descriptions = items.map { item -> String in
            let label = switch item.kind {
            case .microphone: "microphone"
            case .audioInterface: "audio interface"
            case .externalPreamp: "external preamp"
            case .headphones: "headphones"
            case .popFilter: "pop filter"
            }
            let identity = [item.manufacturer, item.model]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            switch item.state {
            case .known:
                return identity.isEmpty
                    ? "reported \(label) with unresolved identity"
                    : "user-reported \(label) label \(identity)"
            case .unknown: return "unknown \(label) identity"
            case .userUnsure: return "unsure \(label) identity"
            case .notPresent: return "no reported \(label)"
            }
        }
        return "Hold the reported path constant (\(descriptions.joined(separator: "; "))) and introduce no unreported processor or device; labels are non-authoritative for hardware behavior."
    }

    private func patternHeldConstant(_ pattern: VocalMicPatternKnowledge) -> String {
        switch pattern.state {
        case .known where pattern.confirmedByUser && pattern.pattern != nil:
            return "same user-confirmed \(pattern.pattern!.rawValue) pattern label; do not infer its directional response"
        case .known:
            return "same recorded but unconfirmed pattern control; do not infer its value or response"
        case .unknown:
            return "pickup pattern remains unknown and no unidentified pattern control is moved"
        case .userUnsure:
            return "pickup pattern remains user-unsure and no unidentified pattern control is moved"
        case .notPresent:
            return "no pickup-pattern control or directional behavior is assumed"
        }
    }

    private func equipmentFact(label: String, item: VocalEquipmentItem) -> String {
        let reportedIdentity = [item.manufacturer, item.model]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let featureText = item.userConfirmedFeatures
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        switch item.state {
        case .known:
            var detail = reportedIdentity.isEmpty
                ? "\(label) is marked known, but no maker/model is supplied."
                : "\(label) is user-reported as \(reportedIdentity)."
            if !featureText.isEmpty {
                detail += " User-confirmed features recorded only: \(featureText.joined(separator: ", "))."
            }
            return detail + " It is a labeled comparison fact, not authority for device-specific response, gain, or control behavior."
        case .unknown:
            return "\(label) is unknown; no device identity, response, control, or setting is assumed."
        case .userUnsure:
            return "The musician is unsure about the \(label.lowercased()); no device behavior or setting is assumed."
        case .notPresent:
            return "\(label) is reported absent; no substitute or improvised replacement is proposed."
        }
    }

    private func microphonePatternFacts(_ pattern: VocalMicPatternKnowledge) -> [String] {
        switch pattern.state {
        case .known:
            if pattern.confirmedByUser, let value = pattern.pattern {
                return ["Microphone pickup pattern is user-confirmed as \(value.rawValue); retain it as a labeled test condition only, without predicting its directional response."]
            }
            return ["A microphone pattern value is recorded but not user-confirmed; it is not used to predict pickup or off-axis behavior."]
        case .unknown:
            return ["Microphone pickup pattern is unknown; every angle instruction is a reversible listening comparison, not a polar-response prediction."]
        case .userUnsure:
            return ["The musician is unsure about microphone pickup pattern; no polar-response behavior is assumed."]
        case .notPresent:
            return ["No microphone pickup pattern is available; no directional behavior is assumed."]
        }
    }

    private func roomNoiseFacts(for environment: VocalCaptureEnvironment) -> [String] {
        var result = [
            "Reported background-noise condition: \(environment.backgroundNoise.rawValue); no dB measurement or noise-source attribution is inferred.",
            "Reported reflection risk: \(environment.reflectionRisk.rawValue); no room-mode or reflection-path diagnosis is claimed.",
            environment.roomSizeKnown
                ? "Room size is reported known, but no acoustic dimensions or response measurement is inferred."
                : "Room size is not reported known; do not infer a room-volume or decay estimate.",
        ]
        if let description = environment.roomDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            result.append("User room description: \(description). It is retained as a comparison note, not an acoustic measurement.")
        } else {
            result.append("No room description was supplied; placement is not based on a claimed room model.")
        }
        switch environment.movableSoftMaterialsAvailable {
        case .known:
            result.append("Movable soft materials are reported available; use only existing materials if the musician elects a reversible comparison, without claiming treatment performance.")
        case .notPresent:
            result.append("No movable soft materials are reported available; no substitute treatment is proposed.")
        case .unknown:
            result.append("Movable soft-material availability is unknown; no treatment placement is assumed.")
        case .userUnsure:
            result.append("The musician is unsure whether movable soft materials are available; no treatment placement is assumed.")
        }
        let noiseSources = environment.knownNoiseSources
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        if noiseSources.isEmpty {
            result.append("No named noise source was supplied; this is not evidence that the room is quiet.")
        } else {
            result.append("Named noise sources to document in the room-tone comparison: \(noiseSources.joined(separator: ", ")).")
        }
        let observations = environment.observations
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        if !observations.isEmpty {
            result.append("User room observations to retain without causal inference: \(observations.joined(separator: " | ")).")
        }
        return result
    }

    private func preservationChecks(
        performance: [VocalPerformanceAttribute],
        voice: [VocalAspect]
    ) -> [String] {
        var result: [String] = []
        if performance.isEmpty {
            result.append("No performance attribute was selected for preservation; do not infer that unselected performance details are disposable.")
        } else {
            result.append("Preserve performance attributes by listening: \(performance.map(\.rawValue).joined(separator: ", ")).")
        }
        if voice.isEmpty {
            result.append("No voice/musical attribute was selected for preservation; the original take remains available for comparison.")
        } else {
            result.append("Preserve voice/musical attributes by listening: \(voice.map(\.rawValue).joined(separator: ", ")).")
        }
        return result
    }

    private func preservationWarnings(
        performance: [VocalPerformanceAttribute],
        voice: [VocalAspect]
    ) -> [String] {
        var result: [String] = []
        for attribute in performance {
            result.append("loss of selected performance attribute \(attribute.rawValue)")
        }
        for aspect in voice {
            result.append("loss of selected voice/musical attribute \(aspect.rawValue)")
        }
        return result
    }

    private func priorityLabel(_ priority: VocalCapturePriority) -> String {
        switch priority {
        case .intelligibility: "intelligibility"
        case .naturalTone: "natural tone"
        case .intimacy: "intimacy"
        case .lowNoise: "low noise"
        case .lowReflection: "low reflection"
        case .controlledPlosives: "controlled plosives"
        case .controlledSibilance: "controlled sibilance"
        case .performanceComfort: "performance comfort"
        case .dynamicRange: "dynamic range"
        case .editability: "editability"
        }
    }

    private func priorityCheck(_ priority: VocalCapturePriority) -> String {
        switch priority {
        case .intelligibility: "listen for word clarity without creating exaggerated consonants; no phoneme score is claimed."
        case .naturalTone: "compare natural tone at matched level rather than naming a microphone response as fact."
        case .intimacy: "compare directness and mouth detail without assuming proximity effect."
        case .lowNoise: "compare a room-tone segment and between-phrase noise without claiming a noise measurement."
        case .lowReflection: "compare apparent room/reflection cues without diagnosing a reflection path."
        case .controlledPlosives: "compare breath blasts and low-frequency bursts without identifying phonemes automatically."
        case .controlledSibilance: "compare sharp upper events by listening; no sibilance measurement is inferred from the setup."
        case .performanceComfort: "ask whether posture, breath, timing feel, and delivery remain comfortable."
        case .dynamicRange: "compare loud and normal delivery without flattening musical dynamics by default."
        case .editability: "retain clearly labeled, bypassed takes so later editing remains reversible."
        }
    }

    private func priorityTradeoff(_ priority: VocalCapturePriority) -> String {
        switch priority {
        case .intelligibility: "a brighter or more direct comparison may expose mouth noise or reduce the preferred tone."
        case .naturalTone: "a pleasing tone must not outrank audible diction, noise, or performance quality without listening."
        case .intimacy: "closer directness can increase mouth detail and low-frequency balance changes."
        case .lowNoise: "a quieter comparison may be less convenient but does not prove a quieter acoustic environment."
        case .lowReflection: "moving away from a hard boundary can change performance comfort and directness."
        case .controlledPlosives: "more off-axis orientation can reduce blasts while changing tone or diction."
        case .controlledSibilance: "softer upper energy can trade off apparent clarity."
        case .performanceComfort: "comfort overrides a theoretically cleaner placement."
        case .dynamicRange: "more headroom can require lower apparent monitoring or playback level during comparison."
        case .editability: "preserving options requires labeled takes and avoids overwriting an earlier capture."
        }
    }

    private func priorityWarning(_ priority: VocalCapturePriority) -> String? {
        switch priority {
        case .intelligibility: "words become harder to follow"
        case .naturalTone: "tone becomes hollow, brittle, or unnatural to the musician"
        case .intimacy: "mouth detail or low-frequency buildup becomes distracting"
        case .lowNoise: "between-phrase noise rises"
        case .lowReflection: "room coloration becomes more obvious"
        case .controlledPlosives: "breath blasts or low-frequency bursts increase"
        case .controlledSibilance: "sharp consonant events become distracting"
        case .performanceComfort: "posture, breath control, or delivery becomes uncomfortable"
        case .dynamicRange: "loud delivery clips or loses intended dynamic movement"
        case .editability: "take labels, bypass state, or original files are no longer recoverable"
        }
    }

    private func popFilterInstruction(for state: VocalKnowledgeState) -> String {
        switch state {
        case .known:
            return "A pop filter is reported present. Mark its current position and keep it unchanged for the comparison; no device-specific spacing rule is assumed."
        case .notPresent:
            return "No pop filter is reported. Use only the bounded off-axis comparison; do not improvise material near the capsule."
        case .unknown:
            return "Pop-filter availability is unknown. Do not assume one is present or add a substitute; compare only a marked, reversible angle change if needed."
        case .userUnsure:
            return "The musician is unsure about pop-filter availability. Do not assume one is present or add a substitute; retain the uncertainty in the take notes."
        }
    }

    private func monitoringGuidance(
        headphoneState: VocalKnowledgeState,
        hearingSafetyIsHard: Bool
    ) -> (instruction: String, latencyBoundary: String) {
        let safety = hearingSafetyIsHard
            ? " The typed hearing-safety constraint is a stop condition."
            : ""
        switch headphoneState {
        case .known:
            return (
                "Headphones are reported available. Start low and keep their playback/monitor balance unchanged between takes; their isolation, latency, and level behavior are not inferred." + safety,
                "No interface, headphone, or host latency behavior is assumed. If timing feels altered, use only the musician's already-verified low-latency/direct-monitoring path or stop the comparison."
            )
        case .notPresent:
            return (
                "No headphones are reported. Do not assume a speaker-monitoring path is safe or spill-free; use only an already-verified safe monitoring path or stop." + safety,
                "No monitoring or latency path is assumed when headphones are absent. Do not create a latency or spill workaround during the capture comparison."
            )
        case .unknown, .userUnsure:
            return (
                "Headphone availability is unresolved. Do not assume closed monitoring, isolation, or a safe level; use only an already-verified monitoring path or stop." + safety,
                "No interface, headphone, or host latency behavior is assumed while monitoring hardware is unknown or unsure."
            )
        }
    }

    private func containsHardConstraint(
        _ kind: VocalCaptureConstraintKind,
        in constraints: [VocalCaptureConstraint]
    ) -> Bool {
        constraints.contains { $0.kind == kind }
    }

    private func constraintSortKey(_ constraint: VocalCaptureConstraint) -> String {
        "\(constraint.kind.rawValue)\u{0}\(constraint.description)"
    }

    private func knownMicrophoneIdentityIsIncomplete(_ microphone: VocalEquipmentItem) -> Bool {
        guard microphone.state == .known else { return false }
        let maker = microphone.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = microphone.model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return maker.isEmpty && model.isEmpty
    }

    private func formatWeight(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }
}

public enum VocalCaptureFindingKind: String, Codable, CaseIterable, Sendable {
    case clipping
    case silence
    case veryLowLevel
    case activeWindowShare
    case gatedLevelVariability
    case heuristicNoiseRisk
    case insufficientEvidence
}

public enum VocalCaptureFindingSeverity: String, Codable, CaseIterable, Sendable {
    case information
    case caution
    case stop
}

public struct VocalCaptureFinding: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var kind: VocalCaptureFindingKind
    public var severity: VocalCaptureFindingSeverity
    public var statement: String
    public var evidenceKind: VocalEvidenceKind
    public var metricIdentifier: String?
    public var value: Double?
    public var unit: String?
    public var confidence: Double
    public var limitations: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        kind: VocalCaptureFindingKind,
        severity: VocalCaptureFindingSeverity,
        statement: String,
        evidenceKind: VocalEvidenceKind,
        metricIdentifier: String? = nil,
        value: Double? = nil,
        unit: String? = nil,
        confidence: Double,
        limitations: [String]
    ) {
        self.version = version
        self.kind = kind
        self.severity = severity
        self.statement = statement
        self.evidenceKind = evidenceKind
        self.metricIdentifier = metricIdentifier
        self.value = value.map { $0.isFinite ? $0 : 0 }
        self.unit = unit
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
        self.limitations = limitations
    }
}

public enum VocalListeningJudgment: String, Codable, CaseIterable, Sendable {
    case wordClarity
    case plosivePerception
    case sibilancePerception
    case roomReflectionPerception
    case noiseIdentityAndAcceptability
    case pitchAndMelody
    case performanceEmotion
    case proximityCharacter
    case voiceNaturalness
}

public struct VocalTestTakeAssessment: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var analysisVersion: String
    public var sourceClass: SourceAnalysisClass?
    public var findings: [VocalCaptureFinding]
    public var listeningOnlyJudgments: [VocalListeningJudgment]
    public var measurementLimitations: [String]

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        analysisVersion: String,
        sourceClass: SourceAnalysisClass?,
        findings: [VocalCaptureFinding],
        listeningOnlyJudgments: [VocalListeningJudgment],
        measurementLimitations: [String]
    ) {
        self.version = version
        self.id = id
        self.analysisVersion = analysisVersion
        self.sourceClass = sourceClass
        self.findings = findings
        self.listeningOnlyJudgments = listeningOnlyJudgments
        self.measurementLimitations = measurementLimitations
    }

    public var requiresImmediateStop: Bool { findings.contains { $0.severity == .stop } }
}

public struct VocalTestTakeAssessor: Sendable {
    public init() {}

    public func assess(_ report: AnalysisReport, assessmentID: UUID = UUID()) -> VocalTestTakeAssessment {
        assess(base: report, sourceAware: nil, sourceClass: nil, assessmentID: assessmentID)
    }

    public func assess(
        _ report: SourceAwareAnalysisReport,
        assessmentID: UUID = UUID()
    ) -> VocalTestTakeAssessment {
        assess(
            base: report.baseReport,
            sourceAware: report,
            sourceClass: report.sourceClass,
            assessmentID: assessmentID
        )
    }

    private func assess(
        base: AnalysisReport,
        sourceAware: SourceAwareAnalysisReport?,
        sourceClass: SourceAnalysisClass?,
        assessmentID: UUID
    ) -> VocalTestTakeAssessment {
        var findings: [VocalCaptureFinding] = []
        let clipping = base.metrics["clipping_samples"]?.value ?? 0
        if base.warnings.contains(.clippingDetected) || clipping > 0 {
            findings.append(VocalCaptureFinding(
                kind: .clipping,
                severity: .stop,
                statement: "The analyzed file contains samples at or beyond digital full scale. Stop this setup comparison and retake at lower input gain.",
                evidenceKind: .measurementSupported,
                metricIdentifier: "clipping_samples",
                value: clipping,
                unit: "samples",
                confidence: base.metrics["clipping_samples"]?.confidence ?? 1,
                limitations: ["This detects digital full-scale samples; it cannot prove or rule out upstream analog clipping below full scale."]
            ))
        }

        let peak = base.metrics["peak_dbfs"]?.value ?? -240
        let rms = base.metrics["rms_dbfs"]?.value ?? -240
        if base.warnings.contains(.silence) || peak <= -160 {
            findings.append(VocalCaptureFinding(
                kind: .silence,
                severity: .stop,
                statement: "The analyzed interval is numerical silence or effectively silent; it cannot support a capture choice.",
                evidenceKind: .measurementSupported,
                metricIdentifier: "peak_dbfs",
                value: peak,
                unit: "dBFS",
                confidence: base.metrics["peak_dbfs"]?.confidence ?? 1,
                limitations: ["This says nothing about why signal is missing."]
            ))
            findings.append(VocalCaptureFinding(
                kind: .insufficientEvidence,
                severity: .stop,
                statement: "A silent interval cannot support capture placement, gain, noise, dynamics, articulation, or performance conclusions.",
                evidenceKind: .measurementSupported,
                metricIdentifier: "peak_dbfs",
                value: peak,
                unit: "dBFS",
                confidence: base.metrics["peak_dbfs"]?.confidence ?? 1,
                limitations: ["Record a labeled non-silent test take before revising the capture interpretation."]
            ))
        } else if peak < -30 || rms < -50 {
            findings.append(VocalCaptureFinding(
                kind: .veryLowLevel,
                severity: .caution,
                statement: "Recorded level is very low relative to full scale. The threshold is a conservative product heuristic, not a claim about the microphone or preamp.",
                evidenceKind: .productHeuristic,
                metricIdentifier: peak < -30 ? "peak_dbfs" : "rms_dbfs",
                value: peak < -30 ? peak : rms,
                unit: "dBFS",
                confidence: min(
                    base.metrics["peak_dbfs"]?.confidence ?? 0,
                    base.metrics["rms_dbfs"]?.confidence ?? 0
                ),
                limitations: ["A quiet performance can be intentional; listening and the known capture chain remain decisive."]
            ))
        }

        let active = activeWindowStatistics(base.series?["rms_dbfs_timeline"])
        findings.append(VocalCaptureFinding(
            kind: .activeWindowShare,
            severity: active.confidence > 0 ? .information : .caution,
            statement: "Active-window share uses 200 ms RMS windows no more than 40 dB below the loudest window.",
            evidenceKind: .measurementSupported,
            metricIdentifier: "rms_dbfs_timeline",
            value: active.share,
            unit: "ratio",
            confidence: active.confidence,
            limitations: ["Quiet words, breaths, fades, and tails can fall below the gate; this is not speech or phrase recognition."]
        ))

        if let variability = sourceAware?.metrics["level_variability_p90_p10_db"] {
            findings.append(VocalCaptureFinding(
                kind: .gatedLevelVariability,
                severity: .information,
                statement: "Gated active-window level variability is reported descriptively; it does not prove inconsistent singing or a need for compression.",
                evidenceKind: .measurementSupported,
                metricIdentifier: variability.definition.identifier,
                value: variability.value,
                unit: "dB",
                confidence: variability.confidence,
                limitations: variability.definition.knownFailureModes
            ))
        } else {
            let variability = percentile(active.activeValues, 0.90) - percentile(active.activeValues, 0.10)
            findings.append(VocalCaptureFinding(
                kind: .gatedLevelVariability,
                severity: .information,
                statement: "A locally derived active-window P90-P10 level range is reported descriptively.",
                evidenceKind: .measurementSupported,
                metricIdentifier: "rms_dbfs_timeline",
                value: max(0, variability),
                unit: "dB",
                confidence: active.activeValues.count >= 2 ? active.confidence : 0,
                limitations: ["It does not identify words, performance intent, distance changes, or a compression requirement."]
            ))
        }

        let noise = heuristicNoiseRisk(active: active)
        findings.append(noise)
        if sourceClass != nil, sourceClass != .vocal {
            findings.append(VocalCaptureFinding(
                kind: .insufficientEvidence,
                severity: .caution,
                statement: "The source-aware report was not classified as vocal; vocal-specific interpretation is withheld.",
                evidenceKind: .measurementSupported,
                confidence: 1,
                limitations: ["Source class is caller-selected, not inferred by this assessor."]
            ))
        }

        return VocalTestTakeAssessment(
            id: assessmentID,
            analysisVersion: sourceAware?.version ?? base.version,
            sourceClass: sourceClass,
            findings: findings,
            listeningOnlyJudgments: VocalListeningJudgment.allCases,
            measurementLimitations: [
                "No phoneme, lyric, plosive, sibilance, room, microphone, pitch, melody, or performance-emotion understanding is claimed.",
                "High- or low-frequency events may be described by other analyzers, but event identity remains a listening judgment here.",
                "Noise risk below is explicitly heuristic and cannot identify a noise source or determine acceptability.",
            ]
        )
    }

    private struct ActiveStatistics {
        var share: Double
        var activeValues: [Double]
        var inactiveValues: [Double]
        var loudest: Double
        var confidence: Double
    }

    private func activeWindowStatistics(_ series: MetricSeries?) -> ActiveStatistics {
        guard let series, !series.values.isEmpty else {
            return ActiveStatistics(share: 0, activeValues: [], inactiveValues: [], loudest: -240, confidence: 0)
        }
        let finite = series.values.filter(\.isFinite)
        guard let loudest = finite.max(), loudest > -160 else {
            return ActiveStatistics(share: 0, activeValues: [], inactiveValues: finite, loudest: loudestOrFloor(finite), confidence: 0)
        }
        let floor = max(-160, loudest - 40)
        let active = finite.filter { $0 > floor }
        let inactive = finite.filter { $0 <= floor && $0 > -160 }
        return ActiveStatistics(
            share: Double(active.count) / Double(max(finite.count, 1)),
            activeValues: active,
            inactiveValues: inactive,
            loudest: loudest,
            confidence: series.confidence * Double(finite.count) / Double(max(series.values.count, 1))
        )
    }

    private func loudestOrFloor(_ values: [Double]) -> Double { values.max() ?? -240 }

    private func heuristicNoiseRisk(active: ActiveStatistics) -> VocalCaptureFinding {
        guard !active.inactiveValues.isEmpty, !active.activeValues.isEmpty else {
            return VocalCaptureFinding(
                kind: .heuristicNoiseRisk,
                severity: .information,
                statement: "Noise risk is unknown because the interval lacks enough separable quiet and active windows.",
                evidenceKind: .productHeuristic,
                value: nil,
                unit: "dB active-to-quiet separation",
                confidence: 0,
                limitations: ["No absence of noise is implied."]
            )
        }
        let activeMedian = percentile(active.activeValues, 0.50)
        let quietP90 = percentile(active.inactiveValues, 0.90)
        let separation = max(0, activeMedian - quietP90)
        let description: String
        let severity: VocalCaptureFindingSeverity
        if separation < 12 {
            description = "Heuristic noise risk is elevated because quiet-window level lies close to active-window level."
            severity = .caution
        } else if separation < 24 {
            description = "Heuristic noise risk is moderate from the active-to-quiet level separation."
            severity = .information
        } else {
            description = "Heuristic noise risk is lower from this interval's active-to-quiet level separation."
            severity = .information
        }
        return VocalCaptureFinding(
            kind: .heuristicNoiseRisk,
            severity: severity,
            statement: description,
            evidenceKind: .productHeuristic,
            metricIdentifier: "rms_dbfs_timeline",
            value: separation,
            unit: "dB active-to-quiet separation",
            confidence: active.confidence * min(1, Double(active.inactiveValues.count) / 4),
            limitations: [
                "Quiet windows can contain breaths, tails, edits, intended softness, or room tone.",
                "This cannot identify fan noise, preamp noise, reflections, microphone self-noise, or acceptability.",
            ]
        )
    }

    private func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = Int((Double(sorted.count - 1) * min(max(fraction, 0), 1)).rounded())
        return sorted[index]
    }
}

public enum VocalListeningRating: String, Codable, CaseIterable, Sendable {
    case better
    case same
    case worse
    case notSure
    case notAssessed
}

public enum VocalProximityFeedback: String, Codable, CaseIterable, Sendable {
    case tooClose
    case balanced
    case tooDistant
    case notSure
    case notAssessed
}

public struct VocalCaptureListeningFeedback: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var wordClarity: VocalListeningRating
    public var breathBlastOrPlosiveRisk: VocalListeningRating
    public var sharpHighFrequencyEvents: VocalListeningRating
    public var roomOrReflectionImpression: VocalListeningRating
    public var betweenPhraseNoise: VocalListeningRating
    public var performanceComfort: VocalListeningRating
    public var voiceNaturalness: VocalListeningRating
    public var proximity: VocalProximityFeedback
    public var note: String?
    public var explicitlyConfirmAsPreference: Bool

    public init(
        version: VocalSchemaVersion = .v1,
        wordClarity: VocalListeningRating = .notAssessed,
        breathBlastOrPlosiveRisk: VocalListeningRating = .notAssessed,
        sharpHighFrequencyEvents: VocalListeningRating = .notAssessed,
        roomOrReflectionImpression: VocalListeningRating = .notAssessed,
        betweenPhraseNoise: VocalListeningRating = .notAssessed,
        performanceComfort: VocalListeningRating = .notAssessed,
        voiceNaturalness: VocalListeningRating = .notAssessed,
        proximity: VocalProximityFeedback = .notAssessed,
        note: String? = nil,
        explicitlyConfirmAsPreference: Bool = false
    ) {
        self.version = version
        self.wordClarity = wordClarity
        self.breathBlastOrPlosiveRisk = breathBlastOrPlosiveRisk
        self.sharpHighFrequencyEvents = sharpHighFrequencyEvents
        self.roomOrReflectionImpression = roomOrReflectionImpression
        self.betweenPhraseNoise = betweenPhraseNoise
        self.performanceComfort = performanceComfort
        self.voiceNaturalness = voiceNaturalness
        self.proximity = proximity
        self.note = note
        self.explicitlyConfirmAsPreference = explicitlyConfirmAsPreference
    }
}

public struct VocalConfirmedCapturePreference: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var id: UUID
    public var interpretationID: UUID
    public var confirmedAt: Date
    public var feedback: VocalCaptureListeningFeedback

    public init(
        version: VocalSchemaVersion = .v1,
        id: UUID,
        interpretationID: UUID,
        confirmedAt: Date,
        feedback: VocalCaptureListeningFeedback
    ) {
        self.version = version
        self.id = id
        self.interpretationID = interpretationID
        self.confirmedAt = confirmedAt
        self.feedback = feedback
    }
}

public struct VocalCaptureRevisionResult: Codable, Equatable, Sendable {
    public var version: VocalSchemaVersion
    public var revisedInterpretation: VocalCaptureInterpretation
    public var assessmentID: UUID
    public var appliedReasons: [String]
    public var confirmedPreference: VocalConfirmedCapturePreference?

    public init(
        version: VocalSchemaVersion = .v1,
        revisedInterpretation: VocalCaptureInterpretation,
        assessmentID: UUID,
        appliedReasons: [String],
        confirmedPreference: VocalConfirmedCapturePreference?
    ) {
        self.version = version
        self.revisedInterpretation = revisedInterpretation
        self.assessmentID = assessmentID
        self.appliedReasons = appliedReasons
        self.confirmedPreference = confirmedPreference
    }
}

public struct VocalCapturePlanReviser: Sendable {
    public init() {}

    public func revise(
        selected: VocalCaptureInterpretation,
        assessment: VocalTestTakeAssessment,
        feedback: VocalCaptureListeningFeedback,
        revisedInterpretationID: UUID,
        revisionID: UUID,
        preferenceID: UUID,
        revisedAt: Date
    ) -> VocalCaptureRevisionResult {
        var revised = selected
        revised.id = revisedInterpretationID
        revised.parentInterpretationID = selected.id
        revised.revisionID = revisionID
        revised.ancestry = selected.ancestry + [selected.id]
        var reasons: [String] = []

        if assessment.findings.contains(where: { $0.kind == .clipping }) {
            revised.gainAndHeadroom.direction = .reduceOneSmallStep
            revised.gainAndHeadroom.instruction = "Lower input gain one small marked step, repeat the loudest pass, and accept the change only when no sample or meter indication clips."
            reasons.append("Measured clipping requires a lower-gain retake before any tone comparison.")
        } else if assessment.findings.contains(where: { $0.kind == .veryLowLevel }) {
            revised.gainAndHeadroom.direction = .increaseOneSmallStep
            revised.gainAndHeadroom.instruction = "If the normal take remains clean and monitoring is safe, raise input gain one small marked step and repeat; never chase an exact knob position."
            reasons.append("Very-low-level heuristic triggered one bounded gain experiment.")
        }

        if feedback.breathBlastOrPlosiveRisk == .worse {
            revised.placement.angle = .moderatelyOffAxis
            revised.placement.boundedAdjustment = "Keep distance fixed and increase off-axis angle one bounded step; roll back if diction or tone worsens."
            reasons.append("Listening feedback reported worse breath-blast/plosive risk; no phoneme detection is claimed.")
        }
        if feedback.roomOrReflectionImpression == .worse {
            revised.roomPosition = .faceTowardSofterIrregularArea
            if revised.placement.distance == .farther || revised.placement.distance == .moderate {
                revised.placement.distance = .close
            }
            reasons.append("Listening feedback reported a worse room/reflection impression, so the revision tests a higher direct-sound share and one softer orientation.")
        }
        if feedback.wordClarity == .worse,
           feedback.breathBlastOrPlosiveRisk != .worse {
            revised.placement.angle = .slightlyOffAxis
            revised.placement.height = .mouthLevel
            reasons.append("Listening feedback reported worse word clarity; the revision backs off the stronger off-axis/height choice while preserving distance.")
        }
        switch feedback.proximity {
        case .tooClose:
            revised.placement.distance = revised.placement.distance == .veryClose ? .close : .moderate
            reasons.append("Listening feedback reported excessive proximity character; distance moves one relative step farther.")
        case .tooDistant:
            revised.placement.distance = revised.placement.distance == .farther ? .moderate : .close
            reasons.append("Listening feedback reported excessive distance; distance moves one relative step closer.")
        case .balanced, .notSure, .notAssessed:
            break
        }
        if feedback.performanceComfort == .worse || feedback.voiceNaturalness == .worse {
            revised.placement = selected.placement
            revised.roomPosition = selected.roomPosition
            reasons.append("Performance comfort or voice naturalness worsened, so placement rolls back exactly to the selected ancestor.")
        }

        revised.comparison.testTakeLabel = "vocal-capture-revision-\(revisionID.uuidString.lowercased())"
        revised.comparison.exactProcedure.insert(
            "Retain and label the parent take \(selected.id.uuidString.lowercased()); the revised take is \(revised.id.uuidString.lowercased()).",
            at: 0
        )
        revised.comparison.rollbackInstructions.insert(
            "Exact rollback target: interpretation \(selected.id.uuidString.lowercased()), including its marked distance, height, angle, room position, gain, and monitoring state.",
            at: 0
        )
        revised.provenance.append(VocalProvenance(
            identifier: "capture-revision-\(revisionID.uuidString.lowercased())",
            evidenceKind: .userReported,
            statement: "Revision uses compact user listening feedback plus bounded measurement findings.",
            limitations: ["Listening labels are not acoustic classification."],
            confidence: 1
        ))

        let confirmed = feedback.explicitlyConfirmAsPreference
            ? VocalConfirmedCapturePreference(
                id: preferenceID,
                interpretationID: revised.id,
                confirmedAt: revisedAt,
                feedback: feedback
            )
            : nil
        return VocalCaptureRevisionResult(
            revisedInterpretation: revised,
            assessmentID: assessment.id,
            appliedReasons: reasons.isEmpty ? ["No supported deterministic capture adjustment was indicated; ancestry and comparison instructions were preserved."] : reasons,
            confirmedPreference: confirmed
        )
    }
}
