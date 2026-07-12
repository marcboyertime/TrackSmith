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
        let spectrum = TimeAveragedSpectrumAnalyzer().analyze(buffer)
        let correlation = stereoCorrelation(buffer)
        let loudness = BS1770Meter().measure(buffer)
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
            "spectral_centroid_hz": metric("spectral_centroid_hz", .hertz, 0...(buffer.sampleRate / 2), spectrum.centroidHz, spectrum.confidence, "Mean power spectrum over Hann-windowed mono fold-down frames; source separation and masking are not represented."),
            "spectral_rolloff_85_hz": metric("spectral_rolloff_85_hz", .hertz, 0...(buffer.sampleRate / 2), spectrum.rolloff85Hz, spectrum.confidence, "Frequency below which 85% of averaged spectral energy lies."),
            "spectral_flatness": metric("spectral_flatness", .ratio, 0...1, spectrum.flatness, spectrum.confidence, "Geometric-to-arithmetic mean of the averaged power spectrum; not a direct noise or quality score."),
            "spectral_slope_db_per_octave": metric("spectral_slope_db_per_octave", .decibelsPerOctave, -100...100, spectrum.slopeDBPerOctave, spectrum.confidence, "Unweighted linear fit to log-frequency power; do not treat a particular slope as universally correct."),
            "low_band_ratio": metric("low_band_ratio", .ratio, 0...1, spectrum.lowRatio, spectrum.confidence, "Energy below 250 Hz in the time-averaged mono spectrum."),
            "mid_band_ratio": metric("mid_band_ratio", .ratio, 0...1, spectrum.midRatio, spectrum.confidence, "Energy from 250 Hz to 4 kHz in the time-averaged mono spectrum."),
            "high_band_ratio": metric("high_band_ratio", .ratio, 0...1, spectrum.highRatio, spectrum.confidence, "Energy above 4 kHz in the time-averaged mono spectrum."),
            "boxiness_band_ratio": metric("boxiness_band_ratio", .ratio, 0...1, spectrum.boxinessRatio, spectrum.confidence, "Energy ratio from 200-500 Hz. This is a descriptive band measure, not proof that the sound is boxy."),
            "harshness_band_ratio": metric("harshness_band_ratio", .ratio, 0...1, spectrum.harshnessRatio, spectrum.confidence, "Energy ratio from 2-5 kHz. Perceived harshness depends on source, level, masking, and time structure."),
            "sibilance_band_ratio": metric("sibilance_band_ratio", .ratio, 0...1, spectrum.sibilanceRatio, spectrum.confidence, "Energy ratio from 5-10 kHz. A vocal detector is required before interpreting it as sibilance."),
            "positive_spectral_flux": metric("positive_spectral_flux", .ratio, 0...10, spectrum.meanPositiveFlux, spectrum.analyzedWindowCount > 1 ? spectrum.confidence : 0, "Mean normalized positive magnitude change between adjacent analyzed frames."),
            "transient_density_per_second": metric("transient_density_per_second", .perSecond, 0...1_000, spectrum.transientDensityPerSecond, spectrum.analyzedWindowCount > 3 ? spectrum.confidence : 0, "Flux outlier count per second; tempo and event type are not inferred."),
            "true_peak_dbtp": metric("true_peak_dbtp", .decibelsTruePeak, -240...24, loudness.truePeakDBTP, 0.95, "ITU-R BS.1770-5 Annex 2 four-phase FIR estimate; 48 kHz is the normative coefficient set."),
        ]
        if let integrated = loudness.integratedLUFS {
            let duration = Double(buffer.frameCount) / buffer.sampleRate
            metrics["integrated_loudness_lufs"] = metric("integrated_loudness_lufs", .loudnessUnitsFullScale, -240...24, integrated, min(1, duration / 3), "ITU-R BS.1770-5 gated K-weighted programme loudness. Short isolated tracks can be perceptually atypical programme material.")
        }
        if let momentary = loudness.maximumMomentaryLUFS {
            metrics["maximum_momentary_loudness_lufs"] = metric("maximum_momentary_loudness_lufs", .loudnessUnitsFullScale, -240...24, momentary, loudness.gatingBlockCount > 0 ? 1 : 0, "Maximum of 400 ms K-weighted blocks; it is not a phrase-level or short-term 3 s measure.")
        }
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
