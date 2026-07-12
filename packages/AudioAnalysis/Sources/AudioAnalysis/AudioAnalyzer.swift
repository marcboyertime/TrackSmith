import Foundation
import DSPCore

public struct AudioAnalyzer: Sendable {
    public init() {}

    public func analyze(_ buffer: AudioBuffer) -> AnalysisReport {
        let samples = buffer.channels.flatMap { $0.map(Double.init) }
        let count = max(samples.count, 1)
        let peak = samples.map(abs).max() ?? 0
        let mean = samples.reduce(0, +) / Double(count)
        let squareMean = samples.reduce(0) { $0 + $1 * $1 } / Double(count)
        let rms = sqrt(squareMean)
        let clippingCount = samples.reduce(0) { $0 + (abs($1) >= 1 ? 1 : 0) }
        let crest = rms > 1e-12 ? peak / rms : 0
        let spectrum = spectrumMetrics(buffer)
        let correlation = stereoCorrelation(buffer)
        let window = min(buffer.frameCount, 2_048)

        func metric(_ id: String, _ unit: MetricUnit, _ range: ClosedRange<Double>, _ value: Double, _ confidence: Double = 1, _ limitation: String) -> MetricValue {
            MetricValue(definition: .init(identifier: id, unit: unit, validRange: range, windowSizeFrames: window, limitation: limitation), value: value, confidence: confidence)
        }

        var metrics: [String: MetricValue] = [
            "peak_dbfs": metric("peak_dbfs", .decibelsFS, -240...24, amplitudeToDB(peak), 1, "Sample peak, not oversampled true peak."),
            "rms_dbfs": metric("rms_dbfs", .decibelsFS, -240...24, amplitudeToDB(rms), 1, "Ungated whole-interval RMS; not integrated loudness."),
            "dc_offset": metric("dc_offset", .linear, -1...1, mean, 1, "Mean sample value across all channels."),
            "clipping_samples": metric("clipping_samples", .count, 0...Double(max(samples.count, 1)), Double(clippingCount), 1, "Counts samples at or beyond full scale; cannot identify upstream clipping below full scale."),
            "crest_factor": metric("crest_factor", .ratio, 0...1_000, crest, rms > 1e-12 ? 1 : 0, "Whole-interval sample-peak to RMS ratio."),
            "spectral_centroid_hz": metric("spectral_centroid_hz", .hertz, 0...(buffer.sampleRate / 2), spectrum.centroid, spectrum.confidence, "Single Hann-window DFT of a mono fold-down; not a time-varying timbre model."),
            "low_band_ratio": metric("low_band_ratio", .ratio, 0...1, spectrum.lowRatio, spectrum.confidence, "Energy below 250 Hz in one analysis window."),
            "mid_band_ratio": metric("mid_band_ratio", .ratio, 0...1, spectrum.midRatio, spectrum.confidence, "Energy from 250 Hz to 4 kHz in one analysis window."),
            "high_band_ratio": metric("high_band_ratio", .ratio, 0...1, spectrum.highRatio, spectrum.confidence, "Energy above 4 kHz in one analysis window."),
        ]
        if let correlation {
            metrics["stereo_correlation"] = metric("stereo_correlation", .linear, -1...1, correlation, buffer.frameCount > 1 ? 1 : 0, "Zero-lag whole-interval Pearson correlation; frequency-dependent phase is not represented.")
        }

        var warnings: [AnalysisWarning] = []
        if clippingCount > 0 { warnings.append(.clippingDetected) }
        if peak < 1e-8 { warnings.append(.silence) }
        if abs(mean) > 0.01 { warnings.append(.possibleDCOffset) }
        if spectrum.confidence < 0.5 { warnings.append(.lowConfidenceSpectrum) }
        if let correlation, correlation < -0.2 { warnings.append(.monoIncompatible) }
        return AnalysisReport(sampleRate: buffer.sampleRate, channelCount: buffer.channelCount, frameCount: buffer.frameCount, metrics: metrics, warnings: warnings)
    }

    private func amplitudeToDB(_ value: Double) -> Double { 20 * log10(max(value, 1e-12)) }

    private func spectrumMetrics(_ buffer: AudioBuffer) -> (centroid: Double, lowRatio: Double, midRatio: Double, highRatio: Double, confidence: Double) {
        let size = min(buffer.frameCount, 2_048)
        guard size >= 64 else { return (0, 0, 0, 0, 0) }
        var mono = Array(repeating: 0.0, count: size)
        for frame in 0..<size {
            for channel in buffer.channels { mono[frame] += Double(channel[frame]) / Double(buffer.channelCount) }
            mono[frame] *= 0.5 - 0.5 * cos(2 * Double.pi * Double(frame) / Double(size - 1))
        }
        var total = 0.0, weighted = 0.0, low = 0.0, mid = 0.0, high = 0.0
        for bin in 0...(size / 2) {
            var real = 0.0, imaginary = 0.0
            for index in 0..<size {
                let phase = -2 * Double.pi * Double(bin * index) / Double(size)
                real += mono[index] * cos(phase); imaginary += mono[index] * sin(phase)
            }
            let energy = real * real + imaginary * imaginary
            let frequency = Double(bin) * buffer.sampleRate / Double(size)
            total += energy; weighted += frequency * energy
            if frequency < 250 { low += energy } else if frequency < 4_000 { mid += energy } else { high += energy }
        }
        guard total > 1e-20 else { return (0, 0, 0, 0, 0) }
        return (weighted / total, low / total, mid / total, high / total, min(1, Double(size) / 2_048))
    }

    private func stereoCorrelation(_ buffer: AudioBuffer) -> Double? {
        guard buffer.channelCount == 2, buffer.frameCount > 1 else { return nil }
        let left = buffer.channels[0].map(Double.init), right = buffer.channels[1].map(Double.init)
        let leftMean = left.reduce(0, +) / Double(left.count), rightMean = right.reduce(0, +) / Double(right.count)
        var numerator = 0.0, leftEnergy = 0.0, rightEnergy = 0.0
        for index in left.indices {
            let l = left[index] - leftMean, r = right[index] - rightMean
            numerator += l * r; leftEnergy += l * l; rightEnergy += r * r
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        return denominator > 1e-20 ? numerator / denominator : 1
    }
}
