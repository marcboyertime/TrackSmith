import Foundation

public enum MetricUnit: String, Codable, Sendable {
    case decibelsFS, decibelsTruePeak, loudnessUnitsFullScale
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

public enum AnalysisWarning: String, Codable, Sendable { case clippingDetected, silence, possibleDCOffset, lowConfidenceSpectrum, monoIncompatible }

public struct AnalysisReport: Codable, Equatable, Sendable {
    public var version: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int
    public var metrics: [String: MetricValue]
    public var warnings: [AnalysisWarning]

    public init(version: String = "1.0", sampleRate: Double, channelCount: Int, frameCount: Int, metrics: [String: MetricValue], warnings: [AnalysisWarning]) {
        self.version = version; self.sampleRate = sampleRate; self.channelCount = channelCount
        self.frameCount = frameCount; self.metrics = metrics; self.warnings = warnings
    }
}
