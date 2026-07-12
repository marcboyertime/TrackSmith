import Foundation
import PlanSchema

public enum DSPError: Error, Equatable, CustomStringConvertible {
    case unsupportedNode(NodeType)
    case channelFormatChanged(expected: Int, actual: Int)
    case sampleRateChanged(expected: Double, actual: Double)

    public var description: String {
        switch self {
        case let .unsupportedNode(type): "DSP module \(type.rawValue) is not implemented in this milestone."
        case let .channelFormatChanged(expected, actual): "Graph was prepared for \(expected) channels, received \(actual)."
        case let .sampleRateChanged(expected, actual): "Graph was prepared at \(expected) Hz, received \(actual) Hz."
        }
    }
}

public struct CompiledGraph: Sendable {
    private var nodes: [CompiledNode]
    public let sampleRate: Double
    public let channelCount: Int
    public let sourcePlan: ProcessingPlan

    public init(plan: ProcessingPlan, sampleRate: Double, channelCount: Int) throws {
        try PlanValidator().validate(plan)
        precondition(channelCount == 1 || channelCount == 2)
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sourcePlan = plan
        self.nodes = try plan.nodes.compactMap { node throws -> CompiledNode? in
            guard node.enabled else { return nil }
            switch node.type {
            case .inputTrim, .outputTrim, .loudnessMatch:
                return .gain(GainNode(decibels: node.parameters[.gainDB, default: 0], sampleRate: sampleRate))
            case .polarity:
                return .polarity
            case .highPass:
                return .biquad(BiquadNode(kind: .highPass, frequency: node.parameters[.frequencyHz, default: 80], q: node.parameters[.q, default: 0.707], gainDB: 0, sampleRate: sampleRate, channelCount: channelCount))
            case .lowPass:
                return .biquad(BiquadNode(kind: .lowPass, frequency: node.parameters[.frequencyHz, default: 18_000], q: node.parameters[.q, default: 0.707], gainDB: 0, sampleRate: sampleRate, channelCount: channelCount))
            case .parametricEQ:
                return .biquad(BiquadNode(kind: .peaking, frequency: node.parameters[.frequencyHz, default: 1_000], q: node.parameters[.q, default: 1], gainDB: node.parameters[.gainDB, default: 0], sampleRate: sampleRate, channelCount: channelCount))
            case .compressor:
                return .compressor(CompressorNode(parameters: node.parameters, sampleRate: sampleRate, channelCount: channelCount))
            case .softClipper, .saturation:
                return .saturator(SaturatorNode(driveDB: node.parameters[.driveDB, default: 0], mix: node.parameters[.mix, default: 1]))
            case .stereoWidth:
                return .width(WidthNode(width: node.parameters[.width, default: 1], mix: node.parameters[.mix, default: 1]))
            case .limiter:
                return .limiter(LimiterNode(ceilingDB: node.parameters[.ceilingDB, default: -1]))
            case .meter:
                return nil
            default:
                throw DSPError.unsupportedNode(node.type)
            }
        }
    }

    public mutating func reset() {
        for index in nodes.indices { nodes[index].reset() }
    }

    /// Processes a preallocated buffer in place. No file I/O, locks, logging, or heap allocation occurs here.
    public mutating func process(_ buffer: inout AudioBuffer) throws {
        guard buffer.channelCount == channelCount else { throw DSPError.channelFormatChanged(expected: channelCount, actual: buffer.channelCount) }
        guard buffer.sampleRate == sampleRate else { throw DSPError.sampleRateChanged(expected: sampleRate, actual: buffer.sampleRate) }
        for index in nodes.indices { nodes[index].process(&buffer) }
        sanitize(&buffer)
    }

    private func sanitize(_ buffer: inout AudioBuffer) {
        for channel in buffer.channels.indices {
            for frame in buffer.channels[channel].indices {
                let sample = buffer.channels[channel][frame]
                if !sample.isFinite { buffer.channels[channel][frame] = 0 }
                else if abs(sample) < 1e-30 { buffer.channels[channel][frame] = 0 }
                else { buffer.channels[channel][frame] = min(max(sample, -8), 8) }
            }
        }
    }
}

private enum CompiledNode: Sendable {
    case gain(GainNode)
    case polarity
    case biquad(BiquadNode)
    case compressor(CompressorNode)
    case saturator(SaturatorNode)
    case width(WidthNode)
    case limiter(LimiterNode)

    mutating func process(_ buffer: inout AudioBuffer) {
        switch self {
        case var .gain(node): node.process(&buffer); self = .gain(node)
        case .polarity:
            for channel in buffer.channels.indices { for frame in buffer.channels[channel].indices { buffer.channels[channel][frame] = -buffer.channels[channel][frame] } }
        case var .biquad(node): node.process(&buffer); self = .biquad(node)
        case var .compressor(node): node.process(&buffer); self = .compressor(node)
        case let .saturator(node): node.process(&buffer)
        case let .width(node): node.process(&buffer)
        case let .limiter(node): node.process(&buffer)
        }
    }

    mutating func reset() {
        switch self {
        case var .biquad(node): node.reset(); self = .biquad(node)
        case var .compressor(node): node.reset(); self = .compressor(node)
        default: break
        }
    }
}

private struct GainNode: Sendable {
    private var current: Double = 1
    private let target: Double
    private let coefficient: Double

    init(decibels: Double, sampleRate: Double) {
        target = pow(10, decibels / 20)
        coefficient = exp(-1 / (0.01 * sampleRate))
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            current = target + coefficient * (current - target)
            let gain = Float(current)
            for channel in buffer.channels.indices { buffer.channels[channel][frame] *= gain }
        }
    }
}

private enum BiquadKind: Sendable { case highPass, lowPass, peaking }

private struct BiquadState: Sendable { var x1 = 0.0; var x2 = 0.0; var y1 = 0.0; var y2 = 0.0 }

private struct BiquadNode: Sendable {
    private let b0, b1, b2, a1, a2: Double
    private var states: [BiquadState]

    init(kind: BiquadKind, frequency: Double, q: Double, gainDB: Double, sampleRate: Double, channelCount: Int) {
        let f = min(max(frequency, 10), sampleRate * 0.49)
        let omega = 2 * Double.pi * f / sampleRate
        let cosine = cos(omega)
        let sine = sin(omega)
        let alpha = sine / (2 * q)
        var cb0, cb1, cb2, ca0, ca1, ca2: Double
        switch kind {
        case .highPass:
            cb0 = (1 + cosine) / 2; cb1 = -(1 + cosine); cb2 = (1 + cosine) / 2
            ca0 = 1 + alpha; ca1 = -2 * cosine; ca2 = 1 - alpha
        case .lowPass:
            cb0 = (1 - cosine) / 2; cb1 = 1 - cosine; cb2 = (1 - cosine) / 2
            ca0 = 1 + alpha; ca1 = -2 * cosine; ca2 = 1 - alpha
        case .peaking:
            let amplitude = pow(10, gainDB / 40)
            cb0 = 1 + alpha * amplitude; cb1 = -2 * cosine; cb2 = 1 - alpha * amplitude
            ca0 = 1 + alpha / amplitude; ca1 = -2 * cosine; ca2 = 1 - alpha / amplitude
        }
        b0 = cb0 / ca0; b1 = cb1 / ca0; b2 = cb2 / ca0; a1 = ca1 / ca0; a2 = ca2 / ca0
        states = Array(repeating: BiquadState(), count: channelCount)
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for channel in buffer.channels.indices {
            for frame in buffer.channels[channel].indices {
                let input = Double(buffer.channels[channel][frame])
                let output = b0 * input + b1 * states[channel].x1 + b2 * states[channel].x2 - a1 * states[channel].y1 - a2 * states[channel].y2
                states[channel].x2 = states[channel].x1; states[channel].x1 = input
                states[channel].y2 = states[channel].y1; states[channel].y1 = output
                buffer.channels[channel][frame] = Float(output)
            }
        }
    }

    mutating func reset() { for index in states.indices { states[index] = BiquadState() } }
}

private struct CompressorNode: Sendable {
    private let thresholdDB, ratio, attackCoefficient, releaseCoefficient, makeup, mix: Double
    private var envelopes: [Double]

    init(parameters: [ParameterID: Double], sampleRate: Double, channelCount: Int) {
        thresholdDB = parameters[.thresholdDB, default: -18]
        ratio = parameters[.ratio, default: 2]
        let attack = parameters[.attackMS, default: 20] / 1_000
        let release = parameters[.releaseMS, default: 120] / 1_000
        attackCoefficient = exp(-1 / max(attack * sampleRate, 1))
        releaseCoefficient = exp(-1 / max(release * sampleRate, 1))
        makeup = pow(10, parameters[.makeupGainDB, default: 0] / 20)
        mix = parameters[.mix, default: 1]
        envelopes = Array(repeating: 0, count: channelCount)
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            var linkedLevel = 0.0
            for channel in buffer.channels.indices { linkedLevel = max(linkedLevel, abs(Double(buffer.channels[channel][frame]))) }
            for channel in envelopes.indices {
                let coefficient = linkedLevel > envelopes[channel] ? attackCoefficient : releaseCoefficient
                envelopes[channel] = linkedLevel + coefficient * (envelopes[channel] - linkedLevel)
            }
            let envelope = envelopes.max() ?? 0
            let inputDB = 20 * log10(max(envelope, 1e-12))
            let gainReductionDB = inputDB > thresholdDB ? (thresholdDB + (inputDB - thresholdDB) / ratio) - inputDB : 0
            let wetGain = pow(10, gainReductionDB / 20) * makeup
            let gain = Float((1 - mix) + mix * wetGain)
            for channel in buffer.channels.indices { buffer.channels[channel][frame] *= gain }
        }
    }

    mutating func reset() { for index in envelopes.indices { envelopes[index] = 0 } }
}

private struct SaturatorNode: Sendable {
    let drive: Float
    let normalization: Float
    let mix: Float
    init(driveDB: Double, mix: Double) {
        drive = Float(pow(10, driveDB / 20)); normalization = max(tanh(drive), 1e-6); self.mix = Float(mix)
    }
    func process(_ buffer: inout AudioBuffer) {
        for channel in buffer.channels.indices { for frame in buffer.channels[channel].indices {
            let dry = buffer.channels[channel][frame]
            let wet = tanh(dry * drive) / normalization
            buffer.channels[channel][frame] = dry * (1 - mix) + wet * mix
        }}
    }
}

private struct WidthNode: Sendable {
    let width: Float
    let mix: Float
    init(width: Double, mix: Double) { self.width = Float(width); self.mix = Float(mix) }
    func process(_ buffer: inout AudioBuffer) {
        guard buffer.channelCount == 2 else { return }
        for frame in 0..<buffer.frameCount {
            let left = buffer.channels[0][frame], right = buffer.channels[1][frame]
            let mid = 0.5 * (left + right), side = 0.5 * (left - right) * width
            let wetL = mid + side, wetR = mid - side
            buffer.channels[0][frame] = left * (1 - mix) + wetL * mix
            buffer.channels[1][frame] = right * (1 - mix) + wetR * mix
        }
    }
}

private struct LimiterNode: Sendable {
    let ceiling: Float
    init(ceilingDB: Double) { ceiling = Float(pow(10, ceilingDB / 20)) }
    func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            var peak: Float = 0
            for channel in buffer.channels.indices { peak = max(peak, abs(buffer.channels[channel][frame])) }
            let gain = peak > ceiling ? ceiling / max(peak, 1e-12) : 1
            for channel in buffer.channels.indices { buffer.channels[channel][frame] *= gain }
        }
    }
}
