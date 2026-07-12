import DSPCore
import Foundation

/// Offline ITU-R BS.1770-5 loudness and true-peak measurements.
///
/// This type allocates working storage and is intentionally not suitable for an
/// Audio Unit render callback. The 400 ms/75%-overlap two-stage gate follows
/// Annex 1. The true-peak estimator uses the Annex 2 48-tap, four-phase FIR.
public struct LoudnessMeasurement: Equatable, Sendable {
    public var integratedLUFS: Double?
    public var absoluteGatedLUFS: Double?
    public var maximumMomentaryLUFS: Double?
    public var truePeakDBTP: Double
    public var gatingBlockCount: Int
    public var includedBlockCount: Int

    public init(
        integratedLUFS: Double?,
        absoluteGatedLUFS: Double?,
        maximumMomentaryLUFS: Double?,
        truePeakDBTP: Double,
        gatingBlockCount: Int,
        includedBlockCount: Int
    ) {
        self.integratedLUFS = integratedLUFS
        self.absoluteGatedLUFS = absoluteGatedLUFS
        self.maximumMomentaryLUFS = maximumMomentaryLUFS
        self.truePeakDBTP = truePeakDBTP
        self.gatingBlockCount = gatingBlockCount
        self.includedBlockCount = includedBlockCount
    }
}

public struct BS1770Meter: Sendable {
    public init() {}

    public func measure(_ buffer: AudioBuffer) -> LoudnessMeasurement {
        let frameCount = buffer.frameCount
        guard frameCount > 0 else {
            return .init(
                integratedLUFS: nil,
                absoluteGatedLUFS: nil,
                maximumMomentaryLUFS: nil,
                truePeakDBTP: -240,
                gatingBlockCount: 0,
                includedBlockCount: 0
            )
        }

        var filtered = buffer.channels.map { _ in Array(repeating: 0.0, count: frameCount) }
        for channel in buffer.channels.indices {
            var weighting = KWeighting(sampleRate: buffer.sampleRate)
            for frame in 0..<frameCount {
                filtered[channel][frame] = weighting.process(Double(buffer.channels[channel][frame]))
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

        return .init(
            integratedLUFS: integrated,
            absoluteGatedLUFS: absoluteGated.isFinite ? absoluteGated : nil,
            maximumMomentaryLUFS: maximumMomentary,
            truePeakDBTP: truePeakDBTP(buffer),
            gatingBlockCount: blockEnergies.count,
            includedBlockCount: includedCount
        )
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
            for sample in channel { peak = max(peak, abs(Double(sample))) }
            guard !channel.isEmpty else { continue }
            for inputIndex in 0..<(channel.count + Self.truePeakTapsPerPhase - 1) {
                for phase in Self.truePeakPhases {
                    var output = 0.0
                    for tap in phase.indices {
                        let sourceIndex = inputIndex - tap
                        if sourceIndex >= 0, sourceIndex < channel.count {
                            output += Double(channel[sourceIndex]) * phase[tap]
                        }
                    }
                    peak = max(peak, abs(output))
                }
            }
        }
        return peak > 0 ? 20 * log10(peak) : -240
    }

    private static let truePeakTapsPerPhase = 12

    // ITU-R BS.1770-5 Annex 2: order-48, four-phase FIR interpolator.
    private static let truePeakPhases: [[Double]] = [
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
