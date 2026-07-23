import Foundation
import DSPCore

public struct AudioAnalyzer: Sendable {
    public init() {}

    public func analyze(_ buffer: AudioBuffer, measuresTruePeak: Bool = true) -> AnalysisReport {
        let samples = buffer.channels.flatMap { channel in
            channel.map { $0.isFinite ? Double($0) : 0 }
        }
        let count = max(samples.count, 1)
        let peak = samples.map(abs).max() ?? 0
        let mean = samples.reduce(0, +) / Double(count)
        let squareMean = samples.reduce(0) { $0 + $1 * $1 } / Double(count)
        let rms = sqrt(squareMean)
        let clippingCount = samples.reduce(0) { $0 + (abs($1) >= 1 ? 1 : 0) }
        let crest = rms > 1e-12 ? peak / rms : 0
        let spectrum = TimeAveragedSpectrumAnalyzer().analyze(buffer)
        let correlation = stereoCorrelation(buffer)
        let loudness = BS1770Meter(measuresTruePeak: measuresTruePeak).measure(buffer)
        let sibilanceDetectorRMS = linkedUpperBandRMS(buffer, frequencyHz: 6_500)
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
            "sibilance_detector_rms_dbfs": metric("sibilance_detector_rms_dbfs", .decibelsFS, -240...24, amplitudeToDB(sibilanceDetectorRMS), spectrum.confidence, "Whole-interval RMS of the same linked complementary 6.5 kHz upper split used by the deterministic de-esser. It calibrates detector level but does not identify phonemes or prove sibilance."),
            "positive_spectral_flux": metric("positive_spectral_flux", .ratio, 0...10, spectrum.meanPositiveFlux, spectrum.analyzedWindowCount > 1 ? spectrum.confidence : 0, "Mean normalized positive magnitude change between adjacent analyzed frames."),
            "transient_density_per_second": metric("transient_density_per_second", .perSecond, 0...1_000, spectrum.transientDensityPerSecond, spectrum.analyzedWindowCount > 3 ? spectrum.confidence : 0, "Flux outlier count per second; tempo and event type are not inferred."),
        ]
        if measuresTruePeak {
            metrics["true_peak_dbtp"] = metric("true_peak_dbtp", .decibelsTruePeak, -240...24, loudness.truePeakDBTP, 0.95, "ITU-R BS.1770-5 Annex 2 FIR at 48 kHz; other rates use a bounded windowed-sinc estimate at >=192 kHz and >=2x. The meter is not formally conformance-tested and can under-read between evaluated phases.")
        }
        if let integrated = loudness.integratedLUFS {
            let duration = Double(buffer.frameCount) / buffer.sampleRate
            metrics["integrated_loudness_lufs"] = metric("integrated_loudness_lufs", .loudnessUnitsFullScale, -240...24, integrated, min(1, duration / 3), "ITU-R BS.1770-5 gated K-weighted programme loudness. Short isolated tracks can be perceptually atypical programme material.")
        }
        if let momentary = loudness.maximumMomentaryLUFS {
            metrics["maximum_momentary_loudness_lufs"] = metric("maximum_momentary_loudness_lufs", .loudnessUnitsFullScale, -240...24, momentary, loudness.gatingBlockCount > 0 ? 1 : 0, "Maximum of 400 ms K-weighted blocks; it is not a phrase-level or short-term 3 s measure.")
        }
        if let shortTerm = loudness.maximumShortTermLUFS {
            metrics["maximum_short_term_loudness_lufs"] = metric(
                "maximum_short_term_loudness_lufs",
                .loudnessUnitsFullScale,
                -240...24,
                shortTerm,
                1,
                "Maximum ungated 3 s rectangular-window loudness at 10 Hz, per EBU Tech 3341 v4 section 2.2. It is not Integrated Loudness or a quality score."
            )
        }
        if let lra = loudness.loudnessRangeLU {
            let duration = Double(buffer.frameCount) / buffer.sampleRate
            metrics["loudness_range_lu"] = metric(
                "loudness_range_lu",
                .loudnessUnits,
                0...240,
                lra,
                min(1, duration / 60),
                "EBU Tech 3342 v4 LRA: gated 10th-to-95th percentile range of 3 s loudness. EBU R 128 does not recommend LRA for programmes under one minute; it is not crest factor, peak-to-floor range, or a quality score."
            )
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
        var series = dynamicsSeries(buffer)
        if !loudness.shortTermLUFSSeries.isEmpty {
            series["short_term_loudness_lufs_timeline"] = MetricSeries(
                identifier: "short_term_loudness_lufs_timeline",
                unit: .loudnessUnitsFullScale,
                values: loudness.shortTermLUFSSeries,
                startSeconds: 0,
                hopSeconds: 0.1,
                windowSizeFrames: max(1, Int((3 * buffer.sampleRate).rounded())),
                validRange: -240...24,
                confidence: 1,
                version: "1.0-ebu-tech-3341-v4",
                limitation: "Ungated rectangular 3 s windows starting at the reported timestamps. Values describe level over time; source context and listening remain necessary."
            )
        }
        if !spectrum.positiveFluxTimeline.isEmpty {
            series["positive_spectral_flux_timeline"] = MetricSeries(
                identifier: "positive_spectral_flux_timeline",
                unit: .ratio,
                values: spectrum.positiveFluxTimeline,
                startSeconds: Double(spectrum.timelineHopSize) / buffer.sampleRate,
                hopSeconds: Double(spectrum.timelineHopSize) / buffer.sampleRate,
                windowSizeFrames: spectrum.windowSize,
                validRange: 0...10,
                confidence: spectrum.confidence,
                limitation: "Normalized positive magnitude flux on selected Hann-windowed mono fold-down frames. Long captures use a larger effective hop, and anti-phase stereo can cancel; it indicates change, not event identity or quality."
            )
        }
        return AnalysisReport(
            sampleRate: buffer.sampleRate,
            channelCount: buffer.channelCount,
            frameCount: buffer.frameCount,
            metrics: metrics,
            warnings: warnings,
            series: series
        )
    }

    private func amplitudeToDB(_ value: Double) -> Double { 20 * log10(max(value, 1e-12)) }

    private func stereoCorrelation(_ buffer: AudioBuffer) -> Double? {
        guard buffer.channelCount == 2, buffer.frameCount > 1 else { return nil }
        let left = buffer.channels[0].map { $0.isFinite ? Double($0) : 0 }
        let right = buffer.channels[1].map { $0.isFinite ? Double($0) : 0 }
        let leftMean = left.reduce(0, +) / Double(left.count), rightMean = right.reduce(0, +) / Double(right.count)
        var numerator = 0.0, leftEnergy = 0.0, rightEnergy = 0.0
        for index in left.indices {
            let l = left[index] - leftMean, r = right[index] - rightMean
            numerator += l * r; leftEnergy += l * l; rightEnergy += r * r
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        return denominator > 1e-20 ? numerator / denominator : 1
    }

    private func dynamicsSeries(_ buffer: AudioBuffer) -> [String: MetricSeries] {
        guard buffer.frameCount > 0 else { return [:] }
        let requestedWindow = Int((buffer.sampleRate * 0.2).rounded())
        let windowSize = min(buffer.frameCount, max(64, requestedWindow))
        let hopSize = max(1, windowSize / 2)
        let availableStarts = buffer.frameCount <= windowSize
            ? [0]
            : Array(stride(from: 0, through: buffer.frameCount - windowSize, by: hopSize))
        let selectionStride = max(1, Int(ceil(Double(availableStarts.count) / 2_048)))
        let starts = availableStarts.enumerated().compactMap { index, start in
            index.isMultiple(of: selectionStride) ? start : nil
        }
        var rmsValues: [Double] = []
        var crestValues: [Double] = []
        rmsValues.reserveCapacity(starts.count)
        crestValues.reserveCapacity(starts.count)
        for start in starts {
            let end = min(buffer.frameCount, start + windowSize)
            var peak = 0.0
            var squareSum = 0.0
            var sampleCount = 0
            for channel in buffer.channels {
                for frame in start..<end {
                    let raw = channel[frame]
                    let sample = raw.isFinite ? Double(raw) : 0
                    peak = max(peak, abs(sample))
                    squareSum += sample * sample
                    sampleCount += 1
                }
            }
            let rms = sampleCount > 0 ? sqrt(squareSum / Double(sampleCount)) : 0
            rmsValues.append(amplitudeToDB(rms))
            crestValues.append(rms > 1e-12 ? peak / rms : 0)
        }
        var coveredFrames = 0
        var coveredThrough = 0
        for start in starts {
            let end = min(buffer.frameCount, start + windowSize)
            coveredFrames += max(0, end - max(start, coveredThrough))
            coveredThrough = max(coveredThrough, end)
        }
        let confidence = min(1, Double(coveredFrames) / Double(max(buffer.frameCount, 1)))
        let hopSeconds = Double(hopSize * selectionStride) / buffer.sampleRate
        return [
            "rms_dbfs_timeline": MetricSeries(
                identifier: "rms_dbfs_timeline",
                unit: .decibelsFS,
                values: rmsValues,
                startSeconds: 0,
                hopSeconds: hopSeconds,
                windowSizeFrames: windowSize,
                validRange: -240...24,
                confidence: confidence,
                limitation: "200 ms windowed RMS with 50% nominal overlap; phrase and source interpretation require musical context."
            ),
            "crest_factor_timeline": MetricSeries(
                identifier: "crest_factor_timeline",
                unit: .ratio,
                values: crestValues,
                startSeconds: 0,
                hopSeconds: hopSeconds,
                windowSizeFrames: windowSize,
                validRange: 0...1_000,
                confidence: confidence,
                limitation: "Windowed sample-peak/RMS ratio; it does not by itself prove punch, over-compression, or quality."
            ),
        ]
    }

    private func linkedUpperBandRMS(_ buffer: AudioBuffer, frequencyHz: Double) -> Double {
        guard buffer.frameCount > 0 else { return 0 }
        let frequency = min(max(frequencyHz, 2_000), buffer.sampleRate * 0.45)
        let omega = 2 * Double.pi * frequency / buffer.sampleRate
        let distance = 1 - cos(omega)
        let coefficient = sqrt(distance * distance + 2 * distance) - distance
        var lowLeft = 0.0
        var lowRight = 0.0
        var squareSum = 0.0
        for frame in 0..<buffer.frameCount {
            let leftSample = buffer.channels[0][frame]
            let left = leftSample.isFinite ? Double(leftSample) : 0
            lowLeft += coefficient * (left - lowLeft)
            var linkedHigh = abs(left - lowLeft)
            if buffer.channelCount == 2 {
                let rightSample = buffer.channels[1][frame]
                let right = rightSample.isFinite ? Double(rightSample) : 0
                lowRight += coefficient * (right - lowRight)
                linkedHigh = max(linkedHigh, abs(right - lowRight))
            }
            squareSum += linkedHigh * linkedHigh
        }
        return sqrt(squareSum / Double(buffer.frameCount))
    }
}
