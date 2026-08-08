import Foundation

public enum MetricUnit: String, Codable, Sendable {
    case decibels, decibelsFS, decibelsTruePeak, loudnessUnitsFullScale, loudnessUnits
    case linear, hertz, count, ratio, seconds, perSecond, decibelsPerOctave
}

public struct MetricDefinition: Codable, Equatable, Sendable {
    public var identifier: String
    public var unit: MetricUnit
    public var validRange: ClosedRange<Double>
    public var windowSizeFrames: Int
    public var version: String
    public var limitation: String

    public init(identifier: String, unit: MetricUnit, validRange: ClosedRange<Double>, windowSizeFrames: Int, version: String = "1.0", limitation: String) {
        self.identifier = identifier; self.unit = unit; self.validRange = validRange
        self.windowSizeFrames = windowSizeFrames; self.version = version; self.limitation = limitation
    }
}

public struct MetricValue: Codable, Equatable, Sendable {
    public var definition: MetricDefinition
    public var value: Double
    public var confidence: Double

    public init(definition: MetricDefinition, value: Double, confidence: Double) {
        self.definition = definition; self.value = value; self.confidence = min(max(confidence, 0), 1)
    }
}

public struct MetricSeries: Codable, Equatable, Sendable {
    public var identifier: String
    public var unit: MetricUnit
    public var values: [Double]
    public var startSeconds: Double
    public var hopSeconds: Double
    public var windowSizeFrames: Int
    /// Optional only so manifests produced before analysis schema v1.1 still decode.
    public var validRange: ClosedRange<Double>?
    public var confidence: Double
    public var version: String
    public var limitation: String

    public init(
        identifier: String,
        unit: MetricUnit,
        values: [Double],
        startSeconds: Double,
        hopSeconds: Double,
        windowSizeFrames: Int,
        validRange: ClosedRange<Double>? = nil,
        confidence: Double,
        version: String = "1.0",
        limitation: String
    ) {
        self.identifier = identifier
        self.unit = unit
        // Series values must remain JSON-encodable. A legitimately silent
        // window makes a logarithmic metric -infinity (short-term LUFS over
        // digital silence is the observed case), and `JSONEncoder` refuses to
        // encode a nonfinite `Double`. Scalar metrics already sanitize; this
        // is the same guarantee for timelines. Nonfinite values are clamped to
        // the declared valid range when one exists so the floor stays
        // meaningful rather than becoming a fabricated zero.
        self.values = values.map { value in
            if value.isFinite {
                guard let validRange else { return value }
                return min(max(value, validRange.lowerBound), validRange.upperBound)
            }
            guard let validRange else { return 0 }
            return value == .infinity ? validRange.upperBound : validRange.lowerBound
        }
        self.startSeconds = startSeconds
        self.hopSeconds = hopSeconds
        self.windowSizeFrames = windowSizeFrames
        self.validRange = validRange
        self.confidence = min(max(confidence, 0), 1)
        self.version = version
        self.limitation = limitation
    }
}

public enum AnalysisWarning: String, Codable, Sendable { case clippingDetected, silence, possibleDCOffset, lowConfidenceSpectrum, monoIncompatible }

public struct AnalysisReport: Codable, Equatable, Sendable {
    public var version: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int
    public var metrics: [String: MetricValue]
    public var warnings: [AnalysisWarning]
    /// Optional for backwards-compatible decoding of preview manifests created before v1.1.
    public var series: [String: MetricSeries]?

    public init(version: String = "1.1", sampleRate: Double, channelCount: Int, frameCount: Int, metrics: [String: MetricValue], warnings: [AnalysisWarning], series: [String: MetricSeries]? = nil) {
        self.version = version; self.sampleRate = sampleRate; self.channelCount = channelCount
        self.frameCount = frameCount; self.metrics = metrics; self.warnings = warnings; self.series = series
    }
}
