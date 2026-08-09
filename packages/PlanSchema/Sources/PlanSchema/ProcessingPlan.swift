import Foundation

public enum SchemaVersion: String, Codable, CaseIterable, Sendable { case v1 = "1.0" }

public enum ChannelFormat: String, Codable, CaseIterable, Sendable { case mono, stereo }

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case vocal, vocalBus, drums, drumBus, bass, guitar, keyboard, synth, fullMix, reference, unknown
}

public enum ScopeKind: String, Codable, CaseIterable, Sendable { case pluginInput, importedFile }

public struct TimeRangeSeconds: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) { self.start = start; self.end = end }
}

public struct ProcessingScope: Codable, Equatable, Sendable {
    public var kind: ScopeKind
    public var channelFormat: ChannelFormat
    public var sourceType: SourceType
    public var timeRangeSeconds: TimeRangeSeconds?

    public init(kind: ScopeKind, channelFormat: ChannelFormat, sourceType: SourceType, timeRangeSeconds: TimeRangeSeconds? = nil) {
        self.kind = kind
        self.channelFormat = channelFormat
        self.sourceType = sourceType
        self.timeRangeSeconds = timeRangeSeconds
    }
}

public enum GoalAttribute: String, Codable, CaseIterable, Sendable {
    case clarity, warmth, brightness, harshness, muddiness, punch, closeness, width
    case dynamicControl, sibilance, backgroundNoise, tonalBalance, loudness, cymbalHarshness, lowEnd
}

public enum GoalDirection: String, Codable, CaseIterable, Sendable { case increase, decrease, preserve, doNotIncrease, doNotDecrease }

public struct ProcessingGoal: Codable, Equatable, Sendable {
    public var attribute: GoalAttribute
    public var direction: GoalDirection
    public var strength: Double
    public var locked: Bool

    public init(attribute: GoalAttribute, direction: GoalDirection, strength: Double, locked: Bool = false) {
        self.attribute = attribute
        self.direction = direction
        self.strength = strength
        self.locked = locked
    }
}

public enum NodeType: String, Codable, CaseIterable, Sendable {
    case inputTrim, polarity, highPass, lowPass, parametricEQ, compressor, expander, deEsser
    case softClipper, saturation, transientShaper, stereoWidth, midSideEQ, delay, modulatedDelay, reverb, limiter
    case outputTrim, loudnessMatch, meter
}

public enum ParameterID: String, Codable, CaseIterable, Sendable {
    case gainDB, frequencyHz, q, thresholdDB, ratio, attackMS, releaseMS, makeupGainDB
    case ceilingDB, kneeDB, mix, width, driveDB, enabled, lookaheadMS
    case algorithmVersion, delayTimeMS, feedback, damping, stereoCrossfeed
    case modulationDepthMS, modulationRateHz, stereoPhaseDegrees
    case preDelayMS, decayTimeSeconds, roomSize, diffusion
    case holdMS, hysteresisDB, rangeDB
}

public enum ChangeCategory: String, Codable, CaseIterable, Sendable { case corrective, creative, loudness }

public struct ProcessingNode: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var type: NodeType
    public var enabled: Bool
    public var parameters: [ParameterID: Double]
    public var rationale: String
    public var confidence: Double
    public var category: ChangeCategory
    public var locked: Bool

    public init(
        id: UUID = UUID(),
        type: NodeType,
        enabled: Bool = true,
        parameters: [ParameterID: Double] = [:],
        rationale: String,
        confidence: Double,
        category: ChangeCategory,
        locked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.enabled = enabled
        self.parameters = parameters
        self.rationale = rationale
        self.confidence = confidence
        self.category = category
        self.locked = locked
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, enabled, parameters, rationale, confidence, category, locked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(NodeType.self, forKey: .type)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        rationale = try container.decode(String.self, forKey: .rationale)
        confidence = try container.decode(Double.self, forKey: .confidence)
        category = try container.decode(ChangeCategory.self, forKey: .category)
        locked = try container.decode(Bool.self, forKey: .locked)

        if let rawParameters = try? container.decode([String: Double].self, forKey: .parameters) {
            var typedParameters: [ParameterID: Double] = [:]
            typedParameters.reserveCapacity(rawParameters.count)
            for (rawKey, value) in rawParameters {
                guard let key = ParameterID(rawValue: rawKey) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .parameters,
                        in: container,
                        debugDescription: "Unknown processing parameter: \(rawKey)"
                    )
                }
                typedParameters[key] = value
            }
            parameters = typedParameters
        } else {
            // Swift synthesized dictionaries with enum keys as alternating JSON
            // key/value arrays in early development builds. Decode that form so
            // saved project state and preview plans migrate without state loss.
            parameters = try container.decode([ParameterID: Double].self, forKey: .parameters)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(
            Dictionary(uniqueKeysWithValues: parameters.map { ($0.key.rawValue, $0.value) }),
            forKey: .parameters
        )
        try container.encode(rationale, forKey: .rationale)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(category, forKey: .category)
        try container.encode(locked, forKey: .locked)
    }
}

public struct OutputConstraints: Codable, Equatable, Sendable {
    public var maxTruePeakDB: Double
    public var loudnessMatchPreview: Bool
    public var preserveMonoCompatibility: Bool
    public var maxAddedGainDB: Double

    public init(maxTruePeakDB: Double = -1, loudnessMatchPreview: Bool = true, preserveMonoCompatibility: Bool = true, maxAddedGainDB: Double = 12) {
        self.maxTruePeakDB = maxTruePeakDB
        self.loudnessMatchPreview = loudnessMatchPreview
        self.preserveMonoCompatibility = preserveMonoCompatibility
        self.maxAddedGainDB = maxAddedGainDB
    }
}

public struct ProcessingPlan: Codable, Equatable, Sendable {
    public var schemaVersion: SchemaVersion
    public var requestID: UUID
    public var sourceSnapshotID: UUID
    public var scope: ProcessingScope
    public var goals: [ProcessingGoal]
    public var nodes: [ProcessingNode]
    public var outputConstraints: OutputConstraints

    public init(
        schemaVersion: SchemaVersion = .v1,
        requestID: UUID = UUID(),
        sourceSnapshotID: UUID,
        scope: ProcessingScope,
        goals: [ProcessingGoal],
        nodes: [ProcessingNode],
        outputConstraints: OutputConstraints = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.sourceSnapshotID = sourceSnapshotID
        self.scope = scope
        self.goals = goals
        self.nodes = nodes
        self.outputConstraints = outputConstraints
    }
}
