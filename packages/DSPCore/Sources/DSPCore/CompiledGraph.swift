import Foundation
import PlanSchema

public enum DSPError: Error, Equatable, CustomStringConvertible {
    case unsupportedNode(NodeType)
    case channelFormatChanged(expected: Int, actual: Int)
    case sampleRateChanged(expected: Double, actual: Double)
    case unsupportedSampleRate(Double)
    case parameterInvalidForSampleRate(ParameterID, value: Double, sampleRate: Double)

    public var description: String {
        switch self {
        case let .unsupportedNode(type): "DSP module \(type.rawValue) is not implemented in this milestone."
        case let .channelFormatChanged(expected, actual): "Graph was prepared for \(expected) channels, received \(actual)."
        case let .sampleRateChanged(expected, actual): "Graph was prepared at \(expected) Hz, received \(actual) Hz."
        case let .unsupportedSampleRate(sampleRate): "Sample rate \(sampleRate) Hz is outside the supported 8 kHz...192 kHz allocation bound."
        case let .parameterInvalidForSampleRate(parameter, value, sampleRate): "\(parameter.rawValue)=\(value) is invalid at \(sampleRate) Hz."
        }
    }
}

/// Status returned by the allocation-free pointer processing path used by audio hosts.
/// Invalid buffers are deliberately left unchanged so a host can continue with dry audio.
public enum RealtimeProcessStatus: Int32, Equatable, Sendable {
    case processed = 0
    case invalidFrameCount
    case channelMismatch
}

public struct CompiledGraph: Sendable {
    private var nodes: [CompiledNode]
    public let sampleRate: Double
    public let channelCount: Int
    public let sourcePlan: ProcessingPlan

    public init(plan: ProcessingPlan, sampleRate: Double, channelCount: Int) throws {
        try PlanValidator().validate(plan)
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate) else {
            throw DSPError.unsupportedSampleRate(sampleRate)
        }
        precondition(channelCount == 1 || channelCount == 2)
        let expectedFormat: ChannelFormat = channelCount == 1 ? .mono : .stereo
        guard plan.scope.channelFormat == expectedFormat else {
            throw DSPError.channelFormatChanged(
                expected: plan.scope.channelFormat == .mono ? 1 : 2,
                actual: channelCount
            )
        }
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
                return .biquad(try BiquadNode(kind: .highPass, frequency: node.parameters[.frequencyHz, default: 80], q: node.parameters[.q, default: 0.707], gainDB: 0, sampleRate: sampleRate, channelCount: channelCount))
            case .lowPass:
                return .biquad(try BiquadNode(kind: .lowPass, frequency: node.parameters[.frequencyHz, default: 18_000], q: node.parameters[.q, default: 0.707], gainDB: 0, sampleRate: sampleRate, channelCount: channelCount))
            case .parametricEQ:
                return .biquad(try BiquadNode(kind: .peaking, frequency: node.parameters[.frequencyHz, default: 1_000], q: node.parameters[.q, default: 1], gainDB: node.parameters[.gainDB, default: 0], sampleRate: sampleRate, channelCount: channelCount))
            case .compressor:
                return .compressor(CompressorNode(parameters: node.parameters, sampleRate: sampleRate, channelCount: channelCount))
            case .expander:
                return .expander(ExpanderNode(parameters: node.parameters, sampleRate: sampleRate))
            case .deEsser:
                return .deEsser(try DeEsserNode(parameters: node.parameters, sampleRate: sampleRate, channelCount: channelCount))
            case .softClipper:
                return .softClipper(SoftClipperNode(
                    driveDB: node.parameters[.driveDB, default: 0],
                    ceilingDB: node.parameters[.ceilingDB, default: -1],
                    mix: node.parameters[.mix, default: 1]
                ))
            case .saturation:
                return .saturator(SaturatorNode(driveDB: node.parameters[.driveDB, default: 0], mix: node.parameters[.mix, default: 1]))
            case .stereoWidth:
                return .width(WidthNode(width: node.parameters[.width, default: 1], mix: node.parameters[.mix, default: 1]))
            case .delay:
                return .delay(DelayNode(parameters: node.parameters, sampleRate: sampleRate, channelCount: channelCount))
            case .reverb:
                return .reverb(ReverbNode(parameters: node.parameters, sampleRate: sampleRate, channelCount: channelCount))
            case .limiter:
                return .limiter(LimiterNode(
                    ceilingDB: node.parameters[.ceilingDB, default: -1],
                    releaseMS: node.parameters[.releaseMS, default: 80],
                    sampleRate: sampleRate
                ))
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
        sanitize(&buffer)
        for index in nodes.indices { nodes[index].process(&buffer) }
        sanitize(&buffer)
    }

    /// Processes noninterleaved Float32 host buffers in place without allocating, locking, or throwing.
    /// The graph must have been compiled off the render thread for the current sample rate and layout.
    public mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>? = nil,
        frameCount: Int
    ) -> RealtimeProcessStatus {
        guard frameCount >= 0 else { return .invalidFrameCount }
        guard (channelCount == 1 && right == nil) || (channelCount == 2 && right != nil) else {
            return .channelMismatch
        }
        sanitizeRealtime(left: left, right: right, frameCount: frameCount)
        for index in nodes.indices {
            nodes[index].processRealtime(left: left, right: right, frameCount: frameCount)
        }
        sanitizeRealtime(left: left, right: right, frameCount: frameCount)
        return .processed
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


    private func sanitizeRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            left[frame] = safeSample(left[frame])
            if let right { right[frame] = safeSample(right[frame]) }
        }
    }

    private func safeSample(_ sample: Float) -> Float {
        if !sample.isFinite || abs(sample) < 1e-30 { return 0 }
        return min(max(sample, -8), 8)
    }
}

private enum CompiledNode: Sendable {
    case gain(GainNode)
    case polarity
    case biquad(BiquadNode)
    case compressor(CompressorNode)
    case expander(ExpanderNode)
    case deEsser(DeEsserNode)
    case softClipper(SoftClipperNode)
    case saturator(SaturatorNode)
    case width(WidthNode)
    case delay(DelayNode)
    case reverb(ReverbNode)
    case limiter(LimiterNode)

    mutating func process(_ buffer: inout AudioBuffer) {
        switch self {
        case var .gain(node): node.process(&buffer); self = .gain(node)
        case .polarity:
            for channel in buffer.channels.indices { for frame in buffer.channels[channel].indices { buffer.channels[channel][frame] = -buffer.channels[channel][frame] } }
        case var .biquad(node): node.process(&buffer); self = .biquad(node)
        case var .compressor(node): node.process(&buffer); self = .compressor(node)
        case var .expander(node): node.process(&buffer); self = .expander(node)
        case var .deEsser(node): node.process(&buffer); self = .deEsser(node)
        case let .softClipper(node): node.process(&buffer)
        case let .saturator(node): node.process(&buffer)
        case let .width(node): node.process(&buffer)
        case let .delay(node): node.process(&buffer)
        case let .reverb(node): node.process(&buffer)
        case var .limiter(node): node.process(&buffer); self = .limiter(node)
        }
    }


    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        switch self {
        case var .gain(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .gain(node)
        case .polarity:
            for frame in 0..<frameCount {
                left[frame] = -left[frame]
                if let right { right[frame] = -right[frame] }
            }
        case var .biquad(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .biquad(node)
        case var .compressor(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .compressor(node)
        case var .expander(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .expander(node)
        case var .deEsser(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .deEsser(node)
        case let .softClipper(node): node.processRealtime(left: left, right: right, frameCount: frameCount)
        case let .saturator(node): node.processRealtime(left: left, right: right, frameCount: frameCount)
        case let .width(node): node.processRealtime(left: left, right: right, frameCount: frameCount)
        case let .delay(node): node.processRealtime(left: left, right: right, frameCount: frameCount)
        case let .reverb(node): node.processRealtime(left: left, right: right, frameCount: frameCount)
        case var .limiter(node): node.processRealtime(left: left, right: right, frameCount: frameCount); self = .limiter(node)
        }
    }

    mutating func reset() {
        switch self {
        case var .gain(node): node.reset(); self = .gain(node)
        case var .biquad(node): node.reset(); self = .biquad(node)
        case var .compressor(node): node.reset(); self = .compressor(node)
        case var .expander(node): node.reset(); self = .expander(node)
        case var .deEsser(node): node.reset(); self = .deEsser(node)
        case let .delay(node): node.reset()
        case let .reverb(node): node.reset()
        case var .limiter(node): node.reset(); self = .limiter(node)
        default: break
        }
    }
}

/// A preallocated delay line whose reset is constant-time. Generation tags
/// prevent stale samples from being observed after reset without clearing a
/// potentially large buffer on the render callback.
private final class GenerationDelayLine: @unchecked Sendable {
    private let samples: UnsafeMutablePointer<Float>
    private let capacity: Int
    private let delaySamples: Int
    private var writeIndex = 0
    private var validSampleCount = 0

    init(delaySamples: Int) {
        self.delaySamples = max(1, delaySamples)
        capacity = self.delaySamples + 1
        samples = .allocate(capacity: capacity)
        samples.initialize(repeating: 0, count: capacity)
    }

    deinit {
        samples.deinitialize(count: capacity)
        samples.deallocate()
    }

    @inline(__always)
    @_optimize(speed)
    func read() -> Float {
        guard validSampleCount == delaySamples else { return 0 }
        let readIndex = writeIndex >= delaySamples
            ? writeIndex - delaySamples
            : writeIndex + capacity - delaySamples
        return samples[readIndex]
    }

    @inline(__always)
    @_optimize(speed)
    func write(_ sample: Float) {
        samples[writeIndex] = sample
        writeIndex += 1
        if writeIndex == capacity { writeIndex = 0 }
        if validSampleCount < delaySamples { validSampleCount += 1 }
    }

    func reset() {
        writeIndex = 0
        // No old sample can be read until every reachable delayed position has
        // been overwritten after reset, so reset remains constant-time without
        // a per-cell generation sidecar in the render callback.
        validSampleCount = 0
    }
}

/// Version-1 linked downward expander/gate. Hysteresis and hold protect musical
/// tails from threshold chatter; range bounds the maximum attenuation.
private struct ExpanderNode: Sendable {
    private let thresholdDB: Double
    private let thresholdLinear: Double
    private let closeThresholdLinear: Double
    private let ratio: Double
    private let rangeDB: Double
    private let detectorAttackCoefficient: Double
    private let detectorReleaseCoefficient: Double
    private let gainOpenCoefficient: Double
    private let gainCloseCoefficient: Double
    private let holdSamples: Int
    private let mix: Double
    private var detectorEnvelope = 0.0
    private var gainReductionDB: Double
    private var holdRemaining = 0
    private var isOpen = false

    init(parameters: [ParameterID: Double], sampleRate: Double) {
        thresholdDB = parameters[.thresholdDB, default: -42]
        thresholdLinear = pow(10, thresholdDB / 20)
        closeThresholdLinear = pow(
            10,
            (thresholdDB - parameters[.hysteresisDB, default: 6]) / 20
        )
        ratio = parameters[.ratio, default: 4]
        rangeDB = parameters[.rangeDB, default: 30]
        let attackSeconds = parameters[.attackMS, default: 5] / 1_000
        let releaseSeconds = parameters[.releaseMS, default: 180] / 1_000
        detectorAttackCoefficient = exp(-1 / max(attackSeconds * sampleRate, 1))
        detectorReleaseCoefficient = exp(-1 / max(releaseSeconds * sampleRate, 1))
        gainOpenCoefficient = detectorAttackCoefficient
        gainCloseCoefficient = detectorReleaseCoefficient
        holdSamples = Int((parameters[.holdMS, default: 80] * sampleRate / 1_000).rounded())
        mix = parameters[.mix, default: 1]
        gainReductionDB = parameters[.rangeDB, default: 30]
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            var linkedLevel = abs(Double(buffer.channels[0][frame]))
            if buffer.channelCount == 2 {
                linkedLevel = max(linkedLevel, abs(Double(buffer.channels[1][frame])))
            }
            let gain = Float(updateGain(linkedLevel: linkedLevel))
            buffer.channels[0][frame] *= gain
            if buffer.channelCount == 2 { buffer.channels[1][frame] *= gain }
        }
    }

    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            var linkedLevel = abs(Double(left[frame]))
            if let right { linkedLevel = max(linkedLevel, abs(Double(right[frame]))) }
            let gain = Float(updateGain(linkedLevel: linkedLevel))
            left[frame] *= gain
            if let right { right[frame] *= gain }
        }
    }

    @inline(__always)
    private mutating func updateGain(linkedLevel: Double) -> Double {
        let detectorCoefficient = linkedLevel > detectorEnvelope
            ? detectorAttackCoefficient
            : detectorReleaseCoefficient
        detectorEnvelope = linkedLevel + detectorCoefficient * (detectorEnvelope - linkedLevel)
        if abs(detectorEnvelope) < 1e-30 { detectorEnvelope = 0 }

        if detectorEnvelope >= thresholdLinear {
            isOpen = true
            holdRemaining = holdSamples
        } else if isOpen {
            if detectorEnvelope >= closeThresholdLinear {
                holdRemaining = holdSamples
            } else if holdRemaining > 0 {
                holdRemaining -= 1
            } else {
                isOpen = false
            }
        }

        let targetReductionDB: Double
        if ratio <= 1 || isOpen {
            targetReductionDB = 0
        } else {
            let levelDB = 20 * log10(max(detectorEnvelope, 1e-12))
            targetReductionDB = min(rangeDB, max(0, (thresholdDB - levelDB) * (ratio - 1)))
        }
        let coefficient = targetReductionDB < gainReductionDB
            ? gainOpenCoefficient
            : gainCloseCoefficient
        gainReductionDB = targetReductionDB + coefficient * (gainReductionDB - targetReductionDB)
        if abs(gainReductionDB) < 1e-12 { gainReductionDB = 0 }
        if gainReductionDB == 0 { return 1 }
        let wetGain = pow(10, -gainReductionDB / 20)
        return (1 - mix) + mix * wetGain
    }

    mutating func reset() {
        detectorEnvelope = 0
        gainReductionDB = rangeDB
        holdRemaining = 0
        isOpen = false
    }
}

/// Version-1 fixed-time feedback delay. All storage is allocated while the
/// graph is compiled. Damping and cross-feedback are bounded and deterministic.
private final class DelayNode: @unchecked Sendable {
    private let leftLine: GenerationDelayLine
    private let rightLine: GenerationDelayLine?
    private let feedback: Float
    private let dampingPole: Float
    private let stereoCrossfeed: Float
    private let mix: Float
    private var filteredLeft: Float = 0
    private var filteredRight: Float = 0

    init(parameters: [ParameterID: Double], sampleRate: Double, channelCount: Int) {
        let delaySamples = max(
            1,
            Int((parameters[.delayTimeMS, default: 250] * sampleRate / 1_000).rounded())
        )
        leftLine = GenerationDelayLine(delaySamples: delaySamples)
        rightLine = channelCount == 2 ? GenerationDelayLine(delaySamples: delaySamples) : nil
        feedback = Float(parameters[.feedback, default: 0.25])
        dampingPole = Float(parameters[.damping, default: 0.35] * 0.995)
        stereoCrossfeed = Float(parameters[.stereoCrossfeed, default: 0])
        mix = Float(parameters[.mix, default: 0.2])
    }

    func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            let right = buffer.channelCount == 2 ? buffer.channels[1][frame] : nil
            let output = processSample(left: buffer.channels[0][frame], right: right)
            buffer.channels[0][frame] = output.0
            if let processedRight = output.1 { buffer.channels[1][frame] = processedRight }
        }
    }

    func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            let output = processSample(left: left[frame], right: right?[frame])
            left[frame] = output.0
            if let right, let processedRight = output.1 { right[frame] = processedRight }
        }
    }

    @inline(__always)
    private func processSample(left dryLeft: Float, right dryRight: Float?) -> (Float, Float?) {
        let delayedLeft = leftLine.read()
        let delayedRight = rightLine?.read() ?? 0
        filteredLeft = delayedLeft + dampingPole * (filteredLeft - delayedLeft)
        filteredRight = delayedRight + dampingPole * (filteredRight - delayedRight)
        if abs(filteredLeft) < 1e-30 { filteredLeft = 0 }
        if abs(filteredRight) < 1e-30 { filteredRight = 0 }

        if let dryRight, let rightLine {
            let feedbackLeft = filteredLeft * (1 - stereoCrossfeed) + filteredRight * stereoCrossfeed
            let feedbackRight = filteredRight * (1 - stereoCrossfeed) + filteredLeft * stereoCrossfeed
            leftLine.write(dryLeft + feedback * feedbackLeft)
            rightLine.write(dryRight + feedback * feedbackRight)
            return (
                dryLeft * (1 - mix) + delayedLeft * mix,
                dryRight * (1 - mix) + delayedRight * mix
            )
        }

        leftLine.write(dryLeft + feedback * filteredLeft)
        return (dryLeft * (1 - mix) + delayedLeft * mix, nil)
    }

    func reset() {
        leftLine.reset()
        rightLine?.reset()
        filteredLeft = 0
        filteredRight = 0
    }
}

private final class FeedbackComb: @unchecked Sendable {
    private let line: GenerationDelayLine
    private let feedback: Float
    private let dampingPole: Float
    private var dampingMemory: Float = 0

    init(delaySamples: Int, delaySeconds: Double, decaySeconds: Double, damping: Double) {
        line = GenerationDelayLine(delaySamples: delaySamples)
        feedback = Float(min(0.98, pow(10, -3 * delaySeconds / decaySeconds)))
        dampingPole = Float(damping * 0.995)
    }

    @inline(__always)
    @_optimize(speed)
    func process(_ input: Float) -> Float {
        let delayed = line.read()
        dampingMemory = delayed + dampingPole * (dampingMemory - delayed)
        if abs(dampingMemory) < 1e-30 { dampingMemory = 0 }
        line.write(input + feedback * dampingMemory)
        return delayed
    }

    func reset() {
        line.reset()
        dampingMemory = 0
    }
}

private struct ScalarDiffusionAllpass: Sendable {
    private let feedback: Float
    private var memory: Float = 0

    init(feedback: Double) {
        self.feedback = Float(feedback)
    }

    @inline(__always)
    mutating func process(_ input: Float) -> Float {
        let output = memory - feedback * input
        memory = input + feedback * output
        if abs(memory) < 1e-30 { memory = 0 }
        return output
    }

    mutating func reset() { memory = 0 }
}

/// Version-1 TrackSmith algorithmic room. This is a documented, bounded
/// compact Schroeder-style topology, not a clone or measurement model of a
/// Logic reverb. Two unequal feedback combs per channel establish the tail;
/// one allocation-free one-sample allpass per channel provides bounded phase
/// diffusion.
private final class ReverbNode: @unchecked Sendable {
    private let leftCombs: [FeedbackComb]
    private let rightCombs: [FeedbackComb]
    private var leftDiffusionA: ScalarDiffusionAllpass
    private var rightDiffusionA: ScalarDiffusionAllpass
    private let mix: Float

    init(parameters: [ParameterID: Double], sampleRate: Double, channelCount: Int) {
        let preDelaySeconds = parameters[.preDelayMS, default: 18] / 1_000
        let roomScale = 0.75 + 0.5 * parameters[.roomSize, default: 0.5]
        let decaySeconds = parameters[.decayTimeSeconds, default: 1.2]
        let damping = parameters[.damping, default: 0.45]
        let diffusionFeedback = 0.3 + 0.4 * parameters[.diffusion, default: 0.65]
        let leftCombMS = [29.7, 41.1]
        let rightCombMS = [30.8, 43.4]

        leftCombs = leftCombMS.map { milliseconds in
            let seconds = milliseconds * roomScale / 1_000 + preDelaySeconds
            return FeedbackComb(
                delaySamples: max(1, Int((seconds * sampleRate).rounded())),
                delaySeconds: seconds,
                decaySeconds: decaySeconds,
                damping: damping
            )
        }
        rightCombs = channelCount == 2
            ? rightCombMS.map { milliseconds in
                let seconds = milliseconds * roomScale / 1_000 + preDelaySeconds
                return FeedbackComb(
                    delaySamples: max(1, Int((seconds * sampleRate).rounded())),
                    delaySeconds: seconds,
                    decaySeconds: decaySeconds,
                    damping: damping
                )
            }
            : []
        leftDiffusionA = ScalarDiffusionAllpass(feedback: diffusionFeedback)
        rightDiffusionA = ScalarDiffusionAllpass(feedback: diffusionFeedback * 0.91)
        mix = Float(parameters[.mix, default: 0.15])
    }

    func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            let right = buffer.channelCount == 2 ? buffer.channels[1][frame] : nil
            let output = processSample(left: buffer.channels[0][frame], right: right)
            buffer.channels[0][frame] = output.0
            if let processedRight = output.1 { buffer.channels[1][frame] = processedRight }
        }
    }

    @_optimize(speed)
    func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            let output = processSample(left: left[frame], right: right?[frame])
            left[frame] = output.0
            if let right, let processedRight = output.1 { right[frame] = processedRight }
        }
    }

    @inline(__always)
    @_optimize(speed)
    private func processSample(left dryLeft: Float, right dryRight: Float?) -> (Float, Float?) {
        var wetLeft: Float = 0
        for comb in leftCombs { wetLeft += comb.process(dryLeft * 0.22) }
        wetLeft *= 0.5
        wetLeft = leftDiffusionA.process(wetLeft)

        guard let dryRight else {
            return (dryLeft * (1 - mix) + wetLeft * mix, nil)
        }
        var wetRight: Float = 0
        for comb in rightCombs { wetRight += comb.process(dryRight * 0.22) }
        wetRight *= 0.5
        wetRight = rightDiffusionA.process(wetRight)
        return (
            dryLeft * (1 - mix) + wetLeft * mix,
            dryRight * (1 - mix) + wetRight * mix
        )
    }

    func reset() {
        for comb in leftCombs { comb.reset() }
        for comb in rightCombs { comb.reset() }
        leftDiffusionA.reset()
        rightDiffusionA.reset()
    }
}

/// Linked split-band de-esser. A one-pole crossover isolates the upper band for
/// detection and gain reduction while leaving the lower band at unity gain.
private struct DeEsserNode: Sendable {
    private let crossoverCoefficient: Double
    private let thresholdDB: Double
    private let ratio: Double
    private let attackCoefficient: Double
    private let releaseCoefficient: Double
    private let mix: Double
    private var lowPassLeft = 0.0
    private var lowPassRight = 0.0
    private var envelope = 0.0

    init(parameters: [ParameterID: Double], sampleRate: Double, channelCount: Int) throws {
        let frequency = parameters[.frequencyHz, default: 6_500]
        guard (2_000...(sampleRate * 0.45)).contains(frequency) else {
            throw DSPError.parameterInvalidForSampleRate(.frequencyHz, value: frequency, sampleRate: sampleRate)
        }
        let omega = 2 * Double.pi * frequency / sampleRate
        let distance = 1 - cos(omega)
        crossoverCoefficient = sqrt(distance * distance + 2 * distance) - distance
        thresholdDB = parameters[.thresholdDB, default: -28]
        ratio = parameters[.ratio, default: 3]
        let attackSeconds = parameters[.attackMS, default: 1.5] / 1_000
        let releaseSeconds = parameters[.releaseMS, default: 70] / 1_000
        attackCoefficient = exp(-1 / max(attackSeconds * sampleRate, 1))
        releaseCoefficient = exp(-1 / max(releaseSeconds * sampleRate, 1))
        mix = parameters[.mix, default: 1]
        _ = channelCount
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        if buffer.channelCount == 1 {
            for frame in 0..<buffer.frameCount {
                let dry = Double(buffer.channels[0][frame])
                lowPassLeft += crossoverCoefficient * (dry - lowPassLeft)
                let high = dry - lowPassLeft
                let gain = detectorGain(linkedHigh: abs(high))
                let wet = lowPassLeft + high * gain
                buffer.channels[0][frame] = Float(dry * (1 - mix) + wet * mix)
            }
        } else {
            for frame in 0..<buffer.frameCount {
                let left = Double(buffer.channels[0][frame])
                let right = Double(buffer.channels[1][frame])
                lowPassLeft += crossoverCoefficient * (left - lowPassLeft)
                lowPassRight += crossoverCoefficient * (right - lowPassRight)
                let highLeft = left - lowPassLeft
                let highRight = right - lowPassRight
                let gain = detectorGain(linkedHigh: max(abs(highLeft), abs(highRight)))
                let wetLeft = lowPassLeft + highLeft * gain
                let wetRight = lowPassRight + highRight * gain
                buffer.channels[0][frame] = Float(left * (1 - mix) + wetLeft * mix)
                buffer.channels[1][frame] = Float(right * (1 - mix) + wetRight * mix)
            }
        }
    }

    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            let dryLeft = Double(left[frame])
            lowPassLeft += crossoverCoefficient * (dryLeft - lowPassLeft)
            let highLeft = dryLeft - lowPassLeft
            if let right {
                let dryRight = Double(right[frame])
                lowPassRight += crossoverCoefficient * (dryRight - lowPassRight)
                let highRight = dryRight - lowPassRight
                let gain = detectorGain(linkedHigh: max(abs(highLeft), abs(highRight)))
                left[frame] = Float(dryLeft * (1 - mix) + (lowPassLeft + highLeft * gain) * mix)
                right[frame] = Float(dryRight * (1 - mix) + (lowPassRight + highRight * gain) * mix)
            } else {
                let gain = detectorGain(linkedHigh: abs(highLeft))
                left[frame] = Float(dryLeft * (1 - mix) + (lowPassLeft + highLeft * gain) * mix)
            }
        }
    }

    private mutating func detectorGain(linkedHigh: Double) -> Double {
        let coefficient = linkedHigh > envelope ? attackCoefficient : releaseCoefficient
        envelope = linkedHigh + coefficient * (envelope - linkedHigh)
        let levelDB = 20 * log10(max(envelope, 1e-12))
        let overDB = max(0, levelDB - thresholdDB)
        let gainReductionDB = (1 / ratio - 1) * overDB
        return pow(10, gainReductionDB / 20)
    }

    mutating func reset() {
        envelope = 0
        lowPassLeft = 0
        lowPassRight = 0
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


    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            current = target + coefficient * (current - target)
            let gain = Float(current)
            left[frame] *= gain
            if let right { right[frame] *= gain }
        }
    }

    mutating func reset() { current = 1 }
}

private enum BiquadKind: Sendable { case highPass, lowPass, peaking }

private struct BiquadState: Sendable { var x1 = 0.0; var x2 = 0.0; var y1 = 0.0; var y2 = 0.0 }

private struct BiquadNode: Sendable {
    private let b0, b1, b2, a1, a2: Double
    private var leftState = BiquadState()
    private var rightState = BiquadState()

    init(kind: BiquadKind, frequency: Double, q: Double, gainDB: Double, sampleRate: Double, channelCount: Int) throws {
        guard frequency <= sampleRate * 0.49 else {
            throw DSPError.parameterInvalidForSampleRate(
                .frequencyHz,
                value: frequency,
                sampleRate: sampleRate
            )
        }
        let omega = 2 * Double.pi * frequency / sampleRate
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
        _ = channelCount
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        processOfflineChannel(&buffer.channels[0], state: &leftState)
        if buffer.channelCount == 2 { processOfflineChannel(&buffer.channels[1], state: &rightState) }
    }


    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        Self.processChannel(left, frameCount: frameCount, state: &leftState, coefficients: (b0, b1, b2, a1, a2))
        if let right { Self.processChannel(right, frameCount: frameCount, state: &rightState, coefficients: (b0, b1, b2, a1, a2)) }
    }

    private func processOfflineChannel(_ samples: inout [Float], state: inout BiquadState) {
        for frame in samples.indices {
            let input = Double(samples[frame])
            let output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2
            state.x2 = state.x1
            state.x1 = input
            state.y2 = state.y1
            state.y1 = output
            samples[frame] = Float(output)
        }
    }

    private static func processChannel(
        _ samples: UnsafeMutablePointer<Float>,
        frameCount: Int,
        state: inout BiquadState,
        coefficients: (Double, Double, Double, Double, Double)
    ) {
        let (b0, b1, b2, a1, a2) = coefficients
        for frame in 0..<frameCount {
            let input = Double(samples[frame])
            let output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2
            state.x2 = state.x1
            state.x1 = input
            state.y2 = state.y1
            state.y1 = output
            samples[frame] = Float(output)
        }
    }

    mutating func reset() {
        leftState = BiquadState()
        rightState = BiquadState()
    }
}

private struct CompressorNode: Sendable {
    private let thresholdDB, ratio, kneeDB, attackCoefficient, releaseCoefficient, makeup, mix: Double
    /// Positive gain reduction in dB, smoothed after the gain computer.
    /// This is the log-domain detector placement analyzed in Giannoulis,
    /// Massberg, and Reiss (JAES 60(6), 2012, equation 23).
    private var gainReductionEnvelopeDB = 0.0

    init(parameters: [ParameterID: Double], sampleRate: Double, channelCount: Int) {
        thresholdDB = parameters[.thresholdDB, default: -18]
        ratio = parameters[.ratio, default: 2]
        kneeDB = parameters[.kneeDB, default: 0]
        let attack = parameters[.attackMS, default: 20] / 1_000
        let release = parameters[.releaseMS, default: 120] / 1_000
        attackCoefficient = exp(-1 / max(attack * sampleRate, 1))
        releaseCoefficient = exp(-1 / max(release * sampleRate, 1))
        makeup = pow(10, parameters[.makeupGainDB, default: 0] / 20)
        mix = parameters[.mix, default: 1]
        _ = channelCount
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            var linkedLevel = 0.0
            for channel in buffer.channels.indices { linkedLevel = max(linkedLevel, abs(Double(buffer.channels[channel][frame]))) }
            updateGainReduction(linkedLevel)
            let wetGain = pow(10, -gainReductionEnvelopeDB / 20) * makeup
            let gain = Float((1 - mix) + mix * wetGain)
            for channel in buffer.channels.indices { buffer.channels[channel][frame] *= gain }
        }
    }


    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            var linkedLevel = abs(Double(left[frame]))
            if let right { linkedLevel = max(linkedLevel, abs(Double(right[frame]))) }
            updateGainReduction(linkedLevel)
            let wetGain = pow(10, -gainReductionEnvelopeDB / 20) * makeup
            let gain = Float((1 - mix) + mix * wetGain)
            left[frame] *= gain
            if let right { right[frame] *= gain }
        }
    }

    private mutating func updateGainReduction(_ linkedLevel: Double) {
        let inputDB = 20 * log10(max(linkedLevel, 1e-12))
        let overDB = inputDB - thresholdDB
        let slope = 1 - 1 / ratio
        let targetGainReductionDB: Double
        if kneeDB <= 0 {
            targetGainReductionDB = overDB > 0 ? slope * overDB : 0
        } else if overDB <= -kneeDB / 2 {
            targetGainReductionDB = 0
        } else if overDB >= kneeDB / 2 {
            targetGainReductionDB = slope * overDB
        } else {
            let kneePosition = overDB + kneeDB / 2
            targetGainReductionDB = slope * kneePosition * kneePosition / (2 * kneeDB)
        }
        let coefficient = targetGainReductionDB > gainReductionEnvelopeDB
            ? attackCoefficient
            : releaseCoefficient
        gainReductionEnvelopeDB = targetGainReductionDB
            + coefficient * (gainReductionEnvelopeDB - targetGainReductionDB)
    }

    mutating func reset() { gainReductionEnvelopeDB = 0 }
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

    func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            left[frame] = processSample(left[frame])
            if let right { right[frame] = processSample(right[frame]) }
        }
    }

    private func processSample(_ dry: Float) -> Float {
        let wet = tanh(dry * drive) / normalization
        return dry * (1 - mix) + wet * mix
    }
}

/// Bounded waveshaping path distinct from normalized saturation. At full wet,
/// `ceiling` is a strict asymptotic bound; partial wet intentionally preserves
/// some dry signal and should be followed by the plan's final safety limiter.
private struct SoftClipperNode: Sendable {
    let drive: Float
    let ceiling: Float
    let mix: Float

    init(driveDB: Double, ceilingDB: Double, mix: Double) {
        drive = Float(pow(10, driveDB / 20))
        ceiling = Float(pow(10, ceilingDB / 20))
        self.mix = Float(mix)
    }

    func process(_ buffer: inout AudioBuffer) {
        for channel in buffer.channels.indices {
            for frame in buffer.channels[channel].indices {
                buffer.channels[channel][frame] = processSample(buffer.channels[channel][frame])
            }
        }
    }

    func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            left[frame] = processSample(left[frame])
            if let right { right[frame] = processSample(right[frame]) }
        }
    }

    private func processSample(_ dry: Float) -> Float {
        let wet = ceiling * tanh(dry * drive / max(ceiling, 1e-6))
        return dry * (1 - mix) + wet * mix
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

    func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        guard let right else { return }
        for frame in 0..<frameCount {
            let dryLeft = left[frame], dryRight = right[frame]
            let mid = 0.5 * (dryLeft + dryRight)
            let side = 0.5 * (dryLeft - dryRight) * width
            left[frame] = dryLeft * (1 - mix) + (mid + side) * mix
            right[frame] = dryRight * (1 - mix) + (mid - side) * mix
        }
    }
}

private struct LimiterNode: Sendable {
    let ceiling: Float
    let releaseCoefficient: Float
    private var gain: Float = 1

    init(ceilingDB: Double, releaseMS: Double, sampleRate: Double) {
        ceiling = Float(pow(10, ceilingDB / 20))
        let releaseSeconds = max(releaseMS / 1_000, 1 / sampleRate)
        releaseCoefficient = Float(exp(-1 / (releaseSeconds * sampleRate)))
    }

    mutating func process(_ buffer: inout AudioBuffer) {
        for frame in 0..<buffer.frameCount {
            var peak: Float = 0
            for channel in buffer.channels.indices { peak = max(peak, abs(buffer.channels[channel][frame])) }
            updateGain(forPeak: peak)
            for channel in buffer.channels.indices { buffer.channels[channel][frame] *= gain }
        }
    }

    mutating func processRealtime(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>?,
        frameCount: Int
    ) {
        for frame in 0..<frameCount {
            var peak = abs(left[frame])
            if let right { peak = max(peak, abs(right[frame])) }
            updateGain(forPeak: peak)
            left[frame] *= gain
            if let right { right[frame] *= gain }
        }
    }

    private mutating func updateGain(forPeak peak: Float) {
        let target: Float = peak > ceiling ? ceiling / max(peak, 1e-12) : 1
        if target < gain {
            gain = target
        } else {
            gain = target + releaseCoefficient * (gain - target)
        }
    }

    mutating func reset() { gain = 1 }
}
