import DSPCore
import Foundation

/// Offline ITU-R BS.1770-5 loudness and true-peak measurements.
///
/// This type allocates working storage and is intentionally not suitable for an
/// Audio Unit render callback. The 400 ms/75%-overlap two-stage gate follows
/// Annex 1. At 48 kHz, the true-peak estimator uses the Annex 2 48-tap,
/// four-phase FIR. Other sample rates use a bounded windowed-sinc interpolator
/// whose integer ratio produces at least 192 kHz and is never below 2x.
///
/// This implementation has not passed a formal BS.1770 conformance suite. The
/// non-48 kHz path is an engineering estimate whose finite interpolation
/// window and phase grid can under-read a continuous-time peak between
/// evaluated phases.
public struct LoudnessMeasurement: Equatable, Sendable {
    public var integratedLUFS: Double?
    public var absoluteGatedLUFS: Double?
    public var maximumMomentaryLUFS: Double?
    public var maximumShortTermLUFS: Double?
    public var loudnessRangeLU: Double?
    public var loudnessRangeReliability: LoudnessRangeReliability
    public var shortTermLUFSSeries: [Double]
    public var truePeakDBTP: Double
    public var gatingBlockCount: Int
    public var includedBlockCount: Int
    public var loudnessRangeBlockCount: Int

    public init(
        integratedLUFS: Double?,
        absoluteGatedLUFS: Double?,
        maximumMomentaryLUFS: Double?,
        maximumShortTermLUFS: Double?,
        loudnessRangeLU: Double?,
        loudnessRangeReliability: LoudnessRangeReliability,
        shortTermLUFSSeries: [Double],
        truePeakDBTP: Double,
        gatingBlockCount: Int,
        includedBlockCount: Int,
        loudnessRangeBlockCount: Int
    ) {
        self.integratedLUFS = integratedLUFS
        self.absoluteGatedLUFS = absoluteGatedLUFS
        self.maximumMomentaryLUFS = maximumMomentaryLUFS
        self.maximumShortTermLUFS = maximumShortTermLUFS
        self.loudnessRangeLU = loudnessRangeLU
        self.loudnessRangeReliability = loudnessRangeReliability
        self.shortTermLUFSSeries = shortTermLUFSSeries
        self.truePeakDBTP = truePeakDBTP
        self.gatingBlockCount = gatingBlockCount
        self.includedBlockCount = includedBlockCount
        self.loudnessRangeBlockCount = loudnessRangeBlockCount
    }
}

/// EBU R 128 and Tech 3342 caution that LRA is unstable for short content and
/// recommend against using it for programmes shorter than one minute.
public enum LoudnessRangeReliability: String, Equatable, Sendable {
    case unavailableInsufficientDuration
    case unstableBelowSixtySeconds
    case measured
}

public struct BS1770Meter: Sendable {
    private let measuresTruePeak: Bool

    public init(measuresTruePeak: Bool = true) {
        self.measuresTruePeak = measuresTruePeak
    }

    public func measure(_ buffer: AudioBuffer) -> LoudnessMeasurement {
        let frameCount = buffer.frameCount
        guard frameCount > 0 else {
            return .init(
                integratedLUFS: nil,
                absoluteGatedLUFS: nil,
                maximumMomentaryLUFS: nil,
                maximumShortTermLUFS: nil,
                loudnessRangeLU: nil,
                loudnessRangeReliability: .unavailableInsufficientDuration,
                shortTermLUFSSeries: [],
                truePeakDBTP: -240,
                gatingBlockCount: 0,
                includedBlockCount: 0,
                loudnessRangeBlockCount: 0
            )
        }

        var filtered = buffer.channels.map { _ in Array(repeating: 0.0, count: frameCount) }
        for channel in buffer.channels.indices {
            var weighting = KWeighting(sampleRate: buffer.sampleRate)
            for frame in 0..<frameCount {
                let sample = buffer.channels[channel][frame]
                filtered[channel][frame] = weighting.process(sample.isFinite ? Double(sample) : 0)
            }
        }

        let blockFrames = max(1, Int((0.400 * buffer.sampleRate).rounded()))
        let stepFrames = max(1, Int((0.100 * buffer.sampleRate).rounded()))
        var blockEnergies: [Double] = []
        if frameCount >= blockFrames {
            var start = 0
            while start + blockFrames <= frameCount {
                var energy = 0.0
                for channel in filtered.indices {
                    var channelEnergy = 0.0
                    for frame in start..<(start + blockFrames) {
                        let value = filtered[channel][frame]
                        channelEnergy += value * value
                    }
                    // Mono, left, and right all have Gi = 1.0 in BS.1770.
                    energy += channelEnergy / Double(blockFrames)
                }
                blockEnergies.append(energy)
                start += stepFrames
            }
        }

        let blockLoudness = blockEnergies.map(loudness)
        let maximumMomentary = blockLoudness.filter(\.isFinite).max()
        let absoluteEnergies = zip(blockEnergies, blockLoudness)
            .filter { $0.1 > -70 }
            .map(\.0)
        let absoluteGated = loudness(mean(absoluteEnergies))

        let integrated: Double?
        let includedCount: Int
        if absoluteEnergies.isEmpty || !absoluteGated.isFinite {
            integrated = nil
            includedCount = 0
        } else {
            let relativeThreshold = absoluteGated - 10
            let included = zip(blockEnergies, blockLoudness)
                .filter { $0.1 > -70 && $0.1 > relativeThreshold }
                .map(\.0)
            let value = loudness(mean(included))
            integrated = value.isFinite ? value : nil
            includedCount = included.count
        }

        // EBU Tech 3341 v4 section 2.2 defines Short-term Loudness as an
        // ungated sliding rectangular 3 s window updated at least 10 Hz. This
        // is deliberately not the 400 ms Momentary series used by the
        // BS.1770 integrated gate.
        let combinedFrameEnergy = combinedEnergyTimeline(filtered)
        let prefixEnergy = prefixSums(combinedFrameEnergy)
        let shortTermFrames = max(1, Int((3.0 * buffer.sampleRate).rounded()))
        let shortTermHopFrames = max(1, Int((0.100 * buffer.sampleRate).rounded()))
        let shortTermSeries = windowedLoudness(
            prefixEnergy: prefixEnergy,
            originalFrameCount: frameCount,
            measurementFrameCount: frameCount,
            windowFrames: shortTermFrames,
            hopFrames: shortTermHopFrames
        )
        let maximumShortTerm = shortTermSeries.filter(\.isFinite).max()

        // EBU Tech 3342 v4 section 3.1 and its reference MATLAB code define
        // LRA over the 3 s series with a -70 LUFS absolute gate, a -20 LU
        // relative gate, and the 10th/95th percentiles. For a file
        // measurement, section 5 requires at least 1.5 s of trailing silence
        // before the final value is determined; zero padding here models that
        // file-meter tail without changing the source buffer.
        let durationSeconds = Double(frameCount) / buffer.sampleRate
        let lraMeasurementFrames = frameCount + Int((1.5 * buffer.sampleRate).rounded())
        let lraSeries = durationSeconds >= 3
            ? windowedLoudness(
                prefixEnergy: prefixEnergy,
                originalFrameCount: frameCount,
                measurementFrameCount: lraMeasurementFrames,
                windowFrames: shortTermFrames,
                hopFrames: shortTermHopFrames
            )
            : []
        let lraResult = loudnessRange(lraSeries)
        let lraReliability: LoudnessRangeReliability = if lraResult.value == nil {
            .unavailableInsufficientDuration
        } else if durationSeconds < 60 {
            .unstableBelowSixtySeconds
        } else {
            .measured
        }

        return .init(
            integratedLUFS: integrated,
            absoluteGatedLUFS: absoluteGated.isFinite ? absoluteGated : nil,
            maximumMomentaryLUFS: maximumMomentary,
            maximumShortTermLUFS: maximumShortTerm,
            loudnessRangeLU: lraResult.value,
            loudnessRangeReliability: lraReliability,
            shortTermLUFSSeries: shortTermSeries,
            truePeakDBTP: measuresTruePeak ? truePeakDBTP(buffer) : -240,
            gatingBlockCount: blockEnergies.count,
            includedBlockCount: includedCount,
            loudnessRangeBlockCount: lraResult.includedBlockCount
        )
    }

    private func combinedEnergyTimeline(_ filtered: [[Double]]) -> [Double] {
        guard let first = filtered.first else { return [] }
        var energy = Array(repeating: 0.0, count: first.count)
        for channel in filtered {
            for frame in channel.indices { energy[frame] += channel[frame] * channel[frame] }
        }
        return energy
    }

    private func prefixSums(_ values: [Double]) -> [Double] {
        var prefix = Array(repeating: 0.0, count: values.count + 1)
        for index in values.indices { prefix[index + 1] = prefix[index] + values[index] }
        return prefix
    }

    private func windowedLoudness(
        prefixEnergy: [Double],
        originalFrameCount: Int,
        measurementFrameCount: Int,
        windowFrames: Int,
        hopFrames: Int
    ) -> [Double] {
        guard measurementFrameCount >= windowFrames else { return [] }
        var values: [Double] = []
        var start = 0
        while start + windowFrames <= measurementFrameCount {
            let sourceStart = min(start, originalFrameCount)
            let sourceEnd = min(start + windowFrames, originalFrameCount)
            let energy = prefixEnergy[sourceEnd] - prefixEnergy[sourceStart]
            values.append(loudness(energy / Double(windowFrames)))
            start += hopFrames
        }
        return values
    }

    private func loudnessRange(_ shortTermLoudness: [Double]) -> (value: Double?, includedBlockCount: Int) {
        // The Tech 3342 reference code uses inclusive comparisons here,
        // unlike the strict greater-than comparisons in BS.1770's integrated
        // loudness gate.
        let absoluteGated = shortTermLoudness.filter { $0.isFinite && $0 >= -70 }
        guard !absoluteGated.isEmpty else { return (nil, 0) }
        let meanPower = absoluteGated.reduce(0.0) { $0 + pow(10, $1 / 10) }
            / Double(absoluteGated.count)
        let relativeThreshold = 10 * log10(meanPower) - 20
        let relativeGated = absoluteGated.filter { $0 >= relativeThreshold }.sorted()
        guard !relativeGated.isEmpty else { return (nil, 0) }
        let low = referencePercentile(relativeGated, percent: 10)
        let high = referencePercentile(relativeGated, percent: 95)
        let value = high - low
        return (value.isFinite ? value : nil, relativeGated.count)
    }

    private func referencePercentile(_ sorted: [Double], percent: Double) -> Double {
        // Direct zero-based translation of Tech 3342 section 5:
        // round((n - 1) * percent / 100 + 1) in MATLAB's one-based indexing.
        let oneBased = ((Double(sorted.count - 1) * percent / 100) + 1).rounded()
        let index = min(sorted.count - 1, max(0, Int(oneBased) - 1))
        return sorted[index]
    }

    private func loudness(_ energy: Double) -> Double {
        guard energy > 0 else { return -.infinity }
        return -0.691 + 10 * log10(energy)
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func truePeakDBTP(_ buffer: AudioBuffer) -> Double {
        var peak = 0.0
        for channel in buffer.channels {
            for sample in channel where sample.isFinite { peak = max(peak, abs(Double(sample))) }
            guard !channel.isEmpty else { continue }
            let interpolatedPeak = Self.usesAnnexTwoFilter(sampleRate: buffer.sampleRate)
                ? Self.annexTwoPeak(channel)
                : Self.sampleRateAwarePeak(channel, sampleRate: buffer.sampleRate)
            if interpolatedPeak.isFinite { peak = max(peak, interpolatedPeak) }
        }
        return peak > 0 ? 20 * log10(peak) : -240
    }

    private static func usesAnnexTwoFilter(sampleRate: Double) -> Bool {
        // Audio hardware rates are integral in practice. The small tolerance
        // avoids selecting a different estimator for harmless host rounding.
        abs(sampleRate - 48_000) < 0.5
    }

    private static func annexTwoPeak(_ channel: [Float]) -> Double {
        var peak = 0.0
        for inputIndex in 0..<(channel.count + truePeakTapsPerPhase - 1) {
            for phase in annexTwoPhases {
                var output = 0.0
                for tap in phase.indices {
                    let sourceIndex = inputIndex - tap
                    if sourceIndex >= 0, sourceIndex < channel.count {
                        let sample = channel[sourceIndex]
                        output += (sample.isFinite ? Double(sample) : 0) * phase[tap]
                    }
                }
                if output.isFinite { peak = max(peak, abs(output)) }
            }
        }
        return peak
    }

    private static func sampleRateAwarePeak(_ channel: [Float], sampleRate: Double) -> Double {
        guard channel.count > 1 else { return 0 }
        let phases = interpolationPhases(sampleRate: sampleRate)
        var peak = 0.0

        // Only interpolate intervals represented by adjacent input samples.
        // Sample peaks are measured separately by the caller. Samples outside
        // the finite capture are zero, matching a zero-state offline FIR.
        for baseIndex in 0..<(channel.count - 1) {
            for phase in phases {
                var output = 0.0
                for tap in phase.coefficients.indices {
                    let sourceIndex = baseIndex + phase.firstOffset + tap
                    if sourceIndex >= 0, sourceIndex < channel.count {
                        let sample = channel[sourceIndex]
                        output += (sample.isFinite ? Double(sample) : 0) * phase.coefficients[tap]
                    }
                }
                if output.isFinite { peak = max(peak, abs(output)) }
            }
        }
        return peak
    }

    private struct InterpolationPhase {
        var firstOffset: Int
        var coefficients: [Double]
    }

    private static func interpolationPhases(sampleRate: Double) -> [InterpolationPhase] {
        // BS.1770-5 Annex 2 calls for an oversampled rate of at least 192 kHz
        // and notes that higher-rate inputs need proportionally less
        // oversampling. A 2x floor retains an inter-sample check at 192 kHz.
        // The cap keeps malformed but positive AudioBuffer rates bounded; it
        // still reaches 192 kHz for the engine's supported >= 8 kHz range.
        let requiredRatio = (192_000 / max(sampleRate, 1)).rounded(.up)
        let ratio = min(24, max(2, Int(requiredRatio)))
        let radius = 16
        let firstOffset = -radius + 1

        return (1..<ratio).map { phaseIndex in
            let fraction = Double(phaseIndex) / Double(ratio)
            var coefficients: [Double] = []
            coefficients.reserveCapacity(radius * 2)
            for offset in firstOffset...radius {
                let distance = fraction - Double(offset)
                let sinc = abs(distance) < 1e-12
                    ? 1
                    : sin(.pi * distance) / (.pi * distance)
                let window = abs(distance) <= Double(radius)
                    ? 0.42
                        + 0.5 * cos(.pi * distance / Double(radius))
                        + 0.08 * cos(2 * .pi * distance / Double(radius))
                    : 0
                coefficients.append(sinc * window)
            }

            // Normalize each fractional phase for unity DC gain. This is done
            // before applying zero padding at capture boundaries.
            let sum = coefficients.reduce(0, +)
            if sum.isFinite, abs(sum) > 1e-12 {
                for index in coefficients.indices { coefficients[index] /= sum }
            }
            return InterpolationPhase(firstOffset: firstOffset, coefficients: coefficients)
        }
    }

    private static let truePeakTapsPerPhase = 12

    // ITU-R BS.1770-5 Annex 2: order-48, four-phase FIR interpolator for
    // 48 kHz input. It must not be reused as a fixed-rate filter elsewhere.
    private static let annexTwoPhases: [[Double]] = [
        [0.001708984375, 0.010986328125, -0.0196533203125, 0.033203125, -0.0594482421875, 0.1373291015625, 0.97216796875, -0.102294921875, 0.047607421875, -0.026611328125, 0.014892578125, -0.00830078125],
        [-0.0291748046875, 0.029296875, -0.0517578125, 0.089111328125, -0.16650390625, 0.465087890625, 0.77978515625, -0.2003173828125, 0.1015625, -0.0582275390625, 0.0330810546875, -0.0189208984375],
        [-0.0189208984375, 0.0330810546875, -0.0582275390625, 0.1015625, -0.2003173828125, 0.77978515625, 0.465087890625, -0.16650390625, 0.089111328125, -0.0517578125, 0.029296875, -0.0291748046875],
        [-0.00830078125, 0.014892578125, -0.026611328125, 0.047607421875, -0.102294921875, 0.97216796875, 0.1373291015625, -0.0594482421875, 0.033203125, -0.0196533203125, 0.010986328125, 0.001708984375],
    ]
}

private struct KWeighting {
    private var shelf: MeasurementBiquad
    private var highPass: MeasurementBiquad

    init(sampleRate: Double) {
        shelf = .highShelf(
            sampleRate: sampleRate,
            frequency: 1_681.974450955533,
            gainDB: 3.999843853973347,
            q: 0.7071752369554196
        )
        highPass = .highPass(
            sampleRate: sampleRate,
            frequency: 38.13547087602444,
            q: 0.5003270373238773
        )
    }

    mutating func process(_ input: Double) -> Double {
        highPass.process(shelf.process(input))
    }
}

private struct MeasurementBiquad {
    private let b0: Double
    private let b1: Double
    private let b2: Double
    private let a1: Double
    private let a2: Double
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    private init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    static func highShelf(sampleRate: Double, frequency: Double, gainDB: Double, q: Double) -> Self {
        let k = tan(Double.pi * frequency / sampleRate)
        let vh = pow(10, gainDB / 20)
        // The exponent is part of the BS.1770 reference coefficient derivation.
        let vb = pow(vh, 0.4996667741545416)
        let a0 = 1 + k / q + k * k
        return .init(
            b0: (vh + vb * k / q + k * k) / a0,
            b1: 2 * (k * k - vh) / a0,
            b2: (vh - vb * k / q + k * k) / a0,
            a1: 2 * (k * k - 1) / a0,
            a2: (1 - k / q + k * k) / a0
        )
    }

    static func highPass(sampleRate: Double, frequency: Double, q: Double) -> Self {
        let k = tan(Double.pi * frequency / sampleRate)
        let a0 = 1 + k / q + k * k
        // BS.1770 specifies b0=1, b1=-2, b2=1 at 48 kHz. Dividing
        // the bilinear-transform numerator by its b0 preserves that normalization.
        return .init(
            b0: 1,
            b1: -2,
            b2: 1,
            a1: 2 * (k * k - 1) / a0,
            a2: (1 - k / q + k * k) / a0
        )
    }

    mutating func process(_ input: Double) -> Double {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        return output.isFinite ? output : 0
    }
}
