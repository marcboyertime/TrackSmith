import DSPCore
import Foundation

struct SpectrumSummary: Sendable {
    var centroidHz: Double
    var rolloff85Hz: Double
    var flatness: Double
    var slopeDBPerOctave: Double
    var lowRatio: Double
    var midRatio: Double
    var highRatio: Double
    var boxinessRatio: Double
    var harshnessRatio: Double
    var sibilanceRatio: Double
    var subRatio: Double
    var bassRatio: Double
    var lowMidRatio: Double
    var airRatio: Double
    var occupiedBandFraction: Double
    var maximumThirdOctaveConcentrationRatio: Double
    var meanPositiveFlux: Double
    var p90PositiveFlux: Double
    var positiveFluxTimeline: [Double]
    var timelineHopSize: Int
    var transientDensityPerSecond: Double
    var lowFrequencyBurstDensityPerSecond: Double
    var highFrequencyBurstDensityPerSecond: Double
    var transientLowBandRatio: Double
    var transientHighBandRatio: Double
    var postOnsetSustainRatio: Double
    var windowSize: Int
    var analyzedWindowCount: Int
    var confidence: Double
}

struct TimeAveragedSpectrumAnalyzer: Sendable {
    private let fftSize = 2_048
    private let hopSize = 1_024
    private let maximumWindows = 512

    func analyze(_ buffer: AudioBuffer) -> SpectrumSummary {
        guard buffer.frameCount >= 64 else { return empty(windowSize: min(buffer.frameCount, fftSize)) }
        let availableStarts: [Int]
        if buffer.frameCount <= fftSize {
            availableStarts = [0]
        } else {
            availableStarts = Array(stride(from: 0, through: buffer.frameCount - fftSize, by: hopSize))
        }
        let selectionStride = max(1, Int(ceil(Double(availableStarts.count) / Double(maximumWindows))))
        let starts = availableStarts.enumerated().compactMap { offset, value in
            offset.isMultiple(of: selectionStride) ? value : nil
        }

        let binCount = fftSize / 2 + 1
        var accumulatedPower = Array(repeating: 0.0, count: binCount)
        var fluxValues: [Double] = []
        var framePowers: [Double] = []
        var frameLowRatios: [Double] = []
        var frameHighRatios: [Double] = []
        var previousMagnitudes: [Double]?

        for start in starts {
            var real = Array(repeating: 0.0, count: fftSize)
            var imaginary = Array(repeating: 0.0, count: fftSize)
            let available = min(fftSize, buffer.frameCount - start)
            for offset in 0..<available {
                var mono = 0.0
                for channel in buffer.channels {
                    let sample = channel[start + offset]
                    mono += sample.isFinite ? Double(sample) : 0
                }
                mono /= Double(buffer.channelCount)
                let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(offset) / Double(fftSize - 1))
                real[offset] = mono * window
            }
            fft(real: &real, imaginary: &imaginary)
            var magnitudes = Array(repeating: 0.0, count: binCount)
            for bin in 0..<binCount {
                let power = real[bin] * real[bin] + imaginary[bin] * imaginary[bin]
                accumulatedPower[bin] += power
                magnitudes[bin] = sqrt(power)
            }
            let framePower = magnitudes.reduce(0) { $0 + $1 * $1 }
            framePowers.append(framePower)
            if framePower > 1e-20 {
                var lowPower = 0.0
                var highPower = 0.0
                for bin in 1..<binCount {
                    let hz = Double(bin) * buffer.sampleRate / Double(fftSize)
                    let power = magnitudes[bin] * magnitudes[bin]
                    if hz >= 20, hz < 200 { lowPower += power }
                    if hz >= 5_000, hz < min(10_000, buffer.sampleRate / 2 + 1) { highPower += power }
                }
                frameLowRatios.append(lowPower / framePower)
                frameHighRatios.append(highPower / framePower)
            } else {
                frameLowRatios.append(0)
                frameHighRatios.append(0)
            }
            if let previousMagnitudes {
                var increase = 0.0
                var currentTotal = 0.0
                for bin in 1..<binCount {
                    increase += max(0, magnitudes[bin] - previousMagnitudes[bin])
                    currentTotal += magnitudes[bin]
                }
                fluxValues.append(currentTotal > 1e-12 ? increase / currentTotal : 0)
            }
            previousMagnitudes = magnitudes
        }

        guard !starts.isEmpty else { return empty(windowSize: fftSize) }
        let inverseCount = 1 / Double(starts.count)
        accumulatedPower = accumulatedPower.map { $0 * inverseCount }
        let total = accumulatedPower.reduce(0, +)
        guard total > 1e-20 else { return empty(windowSize: fftSize) }

        func frequency(_ bin: Int) -> Double { Double(bin) * buffer.sampleRate / Double(fftSize) }
        func ratio(from lower: Double, to upper: Double) -> Double {
            var energy = 0.0
            for bin in accumulatedPower.indices {
                let hz = frequency(bin)
                if hz >= lower, hz < upper { energy += accumulatedPower[bin] }
            }
            return energy / total
        }

        var weightedFrequency = 0.0
        for bin in accumulatedPower.indices { weightedFrequency += frequency(bin) * accumulatedPower[bin] }

        let rolloffTarget = total * 0.85
        var cumulative = 0.0
        var rolloff = 0.0
        for bin in accumulatedPower.indices {
            cumulative += accumulatedPower[bin]
            if cumulative >= rolloffTarget { rolloff = frequency(bin); break }
        }

        let nonDC = accumulatedPower.dropFirst()
        let arithmeticMean = nonDC.reduce(0, +) / Double(max(nonDC.count, 1))
        let geometricMean = exp(nonDC.reduce(0.0) { $0 + log(max($1, 1e-30)) } / Double(max(nonDC.count, 1)))
        let flatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0

        var xSum = 0.0, ySum = 0.0, xxSum = 0.0, xySum = 0.0, slopeCount = 0.0
        for bin in 1..<binCount where frequency(bin) >= 20 {
            let x = log2(frequency(bin) / 1_000)
            let y = 10 * log10(max(accumulatedPower[bin], 1e-30))
            xSum += x; ySum += y; xxSum += x * x; xySum += x * y; slopeCount += 1
        }
        let denominator = slopeCount * xxSum - xSum * xSum
        let slope = abs(denominator) > 1e-12 ? (slopeCount * xySum - xSum * ySum) / denominator : 0

        let meanFlux = fluxValues.isEmpty ? 0 : fluxValues.reduce(0, +) / Double(fluxValues.count)
        let fluxVariance = fluxValues.isEmpty ? 0 : fluxValues.reduce(0) { $0 + ($1 - meanFlux) * ($1 - meanFlux) } / Double(fluxValues.count)
        let fluxThreshold = meanFlux + sqrt(fluxVariance)
        let activePowerThreshold = (framePowers.max() ?? 0) * 0.0001
        let onsetIndices = fluxValues.indices.compactMap { fluxIndex -> Int? in
            let frameIndex = fluxIndex + 1
            guard fluxValues[fluxIndex] > fluxThreshold,
                  frameIndex < framePowers.count,
                  framePowers[frameIndex] > activePowerThreshold else { return nil }
            return frameIndex
        }
        let transientCount = onsetIndices.count
        let duration = max(Double(buffer.frameCount) / buffer.sampleRate, 1e-9)
        let coveredFraction = min(1, Double(starts.count * fftSize) / Double(max(buffer.frameCount, 1)))
        let sortedFlux = fluxValues.sorted()
        let p90Flux = percentile(sortedFlux, fraction: 0.90)
        let lowMedian = percentile(frameLowRatios.sorted(), fraction: 0.50)
        let highMedian = percentile(frameHighRatios.sorted(), fraction: 0.50)
        let lowMAD = percentile(frameLowRatios.map { abs($0 - lowMedian) }.sorted(), fraction: 0.50)
        let highMAD = percentile(frameHighRatios.map { abs($0 - highMedian) }.sorted(), fraction: 0.50)
        let lowBurstThreshold = max(0.20, lowMedian + 3 * max(lowMAD, 0.01))
        let highBurstThreshold = max(0.08, highMedian + 3 * max(highMAD, 0.005))
        let lowBurstCount = onsetIndices.count { frameLowRatios[$0] > lowBurstThreshold }
        let highBurstCount = onsetIndices.count { frameHighRatios[$0] > highBurstThreshold }
        let transientLowRatio = onsetIndices.isEmpty ? 0 : onsetIndices.reduce(0) { $0 + frameLowRatios[$1] } / Double(onsetIndices.count)
        let transientHighRatio = onsetIndices.isEmpty ? 0 : onsetIndices.reduce(0) { $0 + frameHighRatios[$1] } / Double(onsetIndices.count)
        let sustainValues = onsetIndices.compactMap { onsetIndex -> Double? in
            let start = onsetIndex + 2
            let end = min(framePowers.count, onsetIndex + 9)
            guard start < end, framePowers[onsetIndex] > 1e-20 else { return nil }
            let tail = framePowers[start..<end].reduce(0, +) / Double(end - start)
            return sqrt(max(tail, 0) / framePowers[onsetIndex])
        }.sorted()
        let postOnsetSustain = percentile(sustainValues, fraction: 0.50)

        let nonDCMaximum = accumulatedPower.dropFirst().max() ?? 0
        let occupancyThreshold = nonDCMaximum * 0.0001
        let occupiedBins = accumulatedPower.dropFirst().count { $0 >= occupancyThreshold }
        let occupiedFraction = nonDCMaximum > 0
            ? Double(occupiedBins) / Double(max(accumulatedPower.count - 1, 1))
            : 0
        let maximumThirdOctaveConcentration = thirdOctaveMaximumRatio(
            power: accumulatedPower,
            sampleRate: buffer.sampleRate,
            total: total
        )

        return .init(
            centroidHz: weightedFrequency / total,
            rolloff85Hz: rolloff,
            flatness: min(max(flatness, 0), 1),
            slopeDBPerOctave: slope,
            lowRatio: ratio(from: 0, to: 250),
            midRatio: ratio(from: 250, to: 4_000),
            highRatio: ratio(from: 4_000, to: buffer.sampleRate / 2 + 1),
            boxinessRatio: ratio(from: 200, to: 500),
            harshnessRatio: ratio(from: 2_000, to: 5_000),
            sibilanceRatio: ratio(from: 5_000, to: min(10_000, buffer.sampleRate / 2 + 1)),
            subRatio: ratio(from: 20, to: 60),
            bassRatio: ratio(from: 60, to: 120),
            lowMidRatio: ratio(from: 120, to: 350),
            airRatio: ratio(from: 10_000, to: min(20_000, buffer.sampleRate / 2 + 1)),
            occupiedBandFraction: occupiedFraction,
            maximumThirdOctaveConcentrationRatio: maximumThirdOctaveConcentration,
            meanPositiveFlux: meanFlux,
            p90PositiveFlux: p90Flux,
            positiveFluxTimeline: fluxValues,
            timelineHopSize: hopSize * selectionStride,
            transientDensityPerSecond: Double(transientCount) / duration,
            lowFrequencyBurstDensityPerSecond: Double(lowBurstCount) / duration,
            highFrequencyBurstDensityPerSecond: Double(highBurstCount) / duration,
            transientLowBandRatio: transientLowRatio,
            transientHighBandRatio: transientHighRatio,
            postOnsetSustainRatio: postOnsetSustain,
            windowSize: fftSize,
            analyzedWindowCount: starts.count,
            confidence: min(1, max(Double(min(buffer.frameCount, fftSize)) / Double(fftSize), coveredFraction))
        )
    }

    private func empty(windowSize: Int) -> SpectrumSummary {
        .init(
            centroidHz: 0, rolloff85Hz: 0, flatness: 0, slopeDBPerOctave: 0,
            lowRatio: 0, midRatio: 0, highRatio: 0, boxinessRatio: 0,
            harshnessRatio: 0, sibilanceRatio: 0, subRatio: 0, bassRatio: 0,
            lowMidRatio: 0, airRatio: 0, occupiedBandFraction: 0,
            maximumThirdOctaveConcentrationRatio: 0, meanPositiveFlux: 0,
            p90PositiveFlux: 0,
            positiveFluxTimeline: [], timelineHopSize: hopSize,
            transientDensityPerSecond: 0, lowFrequencyBurstDensityPerSecond: 0,
            highFrequencyBurstDensityPerSecond: 0, transientLowBandRatio: 0,
            transientHighBandRatio: 0, postOnsetSustainRatio: 0,
            windowSize: windowSize,
            analyzedWindowCount: 0, confidence: 0
        )
    }

    private func percentile(_ sorted: [Double], fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = Int((Double(sorted.count - 1) * min(max(fraction, 0), 1)).rounded())
        return sorted[index]
    }

    private func thirdOctaveMaximumRatio(power: [Double], sampleRate: Double, total: Double) -> Double {
        guard total > 1e-20 else { return 0 }
        let nyquist = sampleRate / 2
        let centers: [Double] = [
            31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500,
            630, 800, 1_000, 1_250, 1_600, 2_000, 2_500, 3_150, 4_000,
            5_000, 6_300, 8_000, 10_000, 12_500, 16_000, 20_000,
        ]
        let edge = pow(2.0, 1.0 / 6.0)
        var maximum = 0.0
        for center in centers where center / edge < nyquist {
            let lower = center / edge
            let upper = min(center * edge, nyquist)
            var band = 0.0
            for bin in power.indices {
                let hz = Double(bin) * sampleRate / Double(fftSize)
                if hz >= lower, hz < upper { band += power[bin] }
            }
            maximum = max(maximum, band / total)
        }
        return maximum
    }

    private func fft(real: inout [Double], imaginary: inout [Double]) {
        let count = real.count
        var j = 0
        for index in 1..<count {
            var bit = count >> 1
            while j & bit != 0 { j ^= bit; bit >>= 1 }
            j ^= bit
            if index < j {
                real.swapAt(index, j)
                imaginary.swapAt(index, j)
            }
        }
        var length = 2
        while length <= count {
            let angle = -2 * Double.pi / Double(length)
            let stepReal = cos(angle)
            let stepImaginary = sin(angle)
            for start in stride(from: 0, to: count, by: length) {
                var twiddleReal = 1.0
                var twiddleImaginary = 0.0
                for offset in 0..<(length / 2) {
                    let even = start + offset
                    let odd = even + length / 2
                    let oddReal = real[odd] * twiddleReal - imaginary[odd] * twiddleImaginary
                    let oddImaginary = real[odd] * twiddleImaginary + imaginary[odd] * twiddleReal
                    real[odd] = real[even] - oddReal
                    imaginary[odd] = imaginary[even] - oddImaginary
                    real[even] += oddReal
                    imaginary[even] += oddImaginary
                    let nextReal = twiddleReal * stepReal - twiddleImaginary * stepImaginary
                    twiddleImaginary = twiddleReal * stepImaginary + twiddleImaginary * stepReal
                    twiddleReal = nextReal
                }
            }
            length <<= 1
        }
    }
}
