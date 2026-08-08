import DSPCore
import Foundation

public enum SourceAnalysisClass: String, Codable, CaseIterable, Sendable {
    case vocal
    case drums
    case bass
    case guitar
    case synthKeys
    case fullStereoMix
}

public enum AnalysisEvidenceClass: String, Codable, CaseIterable, Sendable {
    case standardsBacked
    case peerReviewedResearchBacked
    case professionalPracticeHeuristic
    case productHeuristic
}

public struct AnalysisProvenance: Codable, Equatable, Sendable {
    public var sourceIdentity: String
    public var sourceVersion: String
    public var relevantSection: String
    public var evidenceClass: AnalysisEvidenceClass
    public var consequence: String

    public init(
        sourceIdentity: String,
        sourceVersion: String,
        relevantSection: String,
        evidenceClass: AnalysisEvidenceClass,
        consequence: String
    ) {
        self.sourceIdentity = sourceIdentity
        self.sourceVersion = sourceVersion
        self.relevantSection = relevantSection
        self.evidenceClass = evidenceClass
        self.consequence = consequence
    }
}

public struct SourceMetricDefinition: Codable, Equatable, Sendable {
    public var identifier: String
    public var unit: MetricUnit
    public var validRange: ClosedRange<Double>
    public var sourceApplicability: [SourceAnalysisClass]
    public var validConditions: [String]
    public var windowing: String
    public var aggregation: String
    public var knownFailureModes: [String]
    public var version: String
    public var provenance: [AnalysisProvenance]

    public init(
        identifier: String,
        unit: MetricUnit,
        validRange: ClosedRange<Double>,
        sourceApplicability: [SourceAnalysisClass],
        validConditions: [String],
        windowing: String,
        aggregation: String,
        knownFailureModes: [String],
        version: String = "1.0",
        provenance: [AnalysisProvenance]
    ) {
        self.identifier = identifier
        self.unit = unit
        self.validRange = validRange
        self.sourceApplicability = sourceApplicability
        self.validConditions = validConditions
        self.windowing = windowing
        self.aggregation = aggregation
        self.knownFailureModes = knownFailureModes
        self.version = version
        self.provenance = provenance
    }
}

public struct SourceMetricValue: Codable, Equatable, Sendable {
    public var definition: SourceMetricDefinition
    public var value: Double
    public var confidence: Double

    public init(definition: SourceMetricDefinition, value: Double, confidence: Double) {
        self.definition = definition
        self.value = value.isFinite ? value : 0
        self.confidence = min(max(confidence.isFinite ? confidence : 0, 0), 1)
    }
}

public struct SourceAwareAnalysisReport: Codable, Equatable, Sendable {
    public var version: String
    public var sourceClass: SourceAnalysisClass
    public var baseReport: AnalysisReport
    public var metrics: [String: SourceMetricValue]

    public init(
        version: String = "1.0",
        sourceClass: SourceAnalysisClass,
        baseReport: AnalysisReport,
        metrics: [String: SourceMetricValue]
    ) {
        self.version = version
        self.sourceClass = sourceClass
        self.baseReport = baseReport
        self.metrics = metrics
    }
}

public struct SourceAwareAudioAnalyzer: Sendable {
    public init() {}

    public func analyze(_ buffer: AudioBuffer, as sourceClass: SourceAnalysisClass) -> SourceAwareAnalysisReport {
        let base = AudioAnalyzer().analyze(buffer, measuresTruePeak: sourceClass == .fullStereoMix)
        let spectrum = TimeAveragedSpectrumAnalyzer().analyze(buffer)
        let dynamics = dynamicStatistics(base)
        let stereo = stereoStatistics(buffer)
        let durationConfidence = min(1, Double(buffer.frameCount) / max(buffer.sampleRate * 3, 1))
        let spectralConfidence = spectrum.confidence
        let dynamicConfidence = min(dynamics.confidence, durationConfidence)

        var metrics: [String: SourceMetricValue] = [:]

        func add(
            _ identifier: String,
            unit: MetricUnit,
            range: ClosedRange<Double>,
            value: Double,
            confidence: Double,
            applicability: [SourceAnalysisClass],
            valid: [String],
            windowing: String,
            aggregation: String,
            failures: [String],
            provenance: [AnalysisProvenance],
            version: String = "1.0"
        ) {
            let definition = SourceMetricDefinition(
                identifier: identifier,
                unit: unit,
                validRange: range,
                sourceApplicability: applicability,
                validConditions: valid,
                windowing: windowing,
                aggregation: aggregation,
                knownFailureModes: failures,
                version: version,
                provenance: provenance
            )
            metrics[identifier] = SourceMetricValue(definition: definition, value: value, confidence: confidence)
        }

        let fftWindow = "Hann-windowed 2048-sample mono fold-down; nominal 1024-sample hop, deterministically subsampled to at most 512 frames"
        let activeSignal = ["Finite PCM audio", "At least 64 frames", "Signal energy above numerical silence"]
        let spectrumFailures = [
            "Mono fold-down can cancel anti-phase stereo content",
            "No instrument or phoneme separation",
            "Result changes with arrangement, tuning, performance, capture chain, and existing processing",
        ]
        let descriptorProvenance = [Self.essentiaProvenance, Self.productionQualityCaution]
        let practiceProvenance = [Self.logicEffectsProvenance, Self.bestPracticeProvenance]

        switch sourceClass {
        case .vocal:
            add(
                "vocal_high_frequency_burst_density_per_second", unit: .perSecond, range: 0...1_000,
                value: spectrum.highFrequencyBurstDensityPerSecond, confidence: dynamicConfidence * spectralConfidence,
                applicability: [.vocal],
                valid: activeSignal + ["Predominantly isolated vocal", "5-10 kHz is represented by the sample rate"],
                windowing: fftWindow,
                aggregation: "Count of energetic positive-flux frames whose 5-10 kHz energy share exceeds a robust within-capture threshold, divided by capture duration",
                failures: spectrumFailures + ["Breaths, cymbal bleed, fricatives, distortion, and bright consonants can trigger", "Low-level or already de-essed sibilants can be missed"],
                provenance: [Self.logicDeEsserProvenance, Self.productBurstProvenance]
            )
            add(
                "vocal_low_frequency_burst_density_per_second", unit: .perSecond, range: 0...1_000,
                value: spectrum.lowFrequencyBurstDensityPerSecond, confidence: dynamicConfidence * spectralConfidence,
                applicability: [.vocal],
                valid: activeSignal + ["Predominantly isolated close-miked vocal"],
                windowing: fftWindow,
                aggregation: "Count of energetic positive-flux frames whose 20-200 Hz energy share exceeds a robust within-capture threshold, divided by capture duration",
                failures: spectrumFailures + ["Handling noise, kick/bass bleed, low vowels, wind, and proximity changes can trigger", "It is plosive evidence, not a phoneme classifier"],
                provenance: [Self.productBurstProvenance]
            )
            addLevelVariability(sourceClass, dynamics, &metrics)
            addBand("vocal_120_350_hz_energy_ratio", spectrum.lowMidRatio, [.vocal], "Low-mid/proximity-buildup evidence", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + practiceProvenance, &metrics)
            addBand("vocal_200_500_hz_energy_ratio", spectrum.boxinessRatio, [.vocal], "Overlapping low-mid concentration evidence; never a direct boxiness label", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.productionQualityCaution], &metrics)
            addBand("vocal_5_10_khz_energy_ratio", spectrum.sibilanceRatio, [.vocal], "Whole-capture high-band balance evidence; event evidence is reported separately", spectralConfidence, fftWindow, spectrumFailures, [Self.logicDeEsserProvenance, Self.productionQualityCaution], &metrics)
            addBand("vocal_10_20_khz_energy_ratio", spectrum.airRatio, [.vocal], "Air/upper-treble evidence", spectralConfidence, fftWindow, spectrumFailures + ["Microphone self-noise and sample-rate bandwidth can dominate"], descriptorProvenance + practiceProvenance, &metrics)

        case .drums:
            addTransientMetrics(sourceClass, spectrum, dynamics, spectralConfidence, dynamicConfidence, fftWindow, spectrumFailures, &metrics)
            addBand("drums_transient_20_200_hz_energy_ratio", spectrum.transientLowBandRatio, [.drums], "Low-frequency content at detected spectral-change events", dynamicConfidence * spectralConfidence, fftWindow, spectrumFailures + ["Cannot separate kick, tom, bass bleed, or room contribution"], descriptorProvenance + practiceProvenance, &metrics)
            addBand("drums_transient_5_10_khz_energy_ratio", spectrum.transientHighBandRatio, [.drums], "Cymbal/high-frequency content at detected spectral-change events", dynamicConfidence * spectralConfidence, fftWindow, spectrumFailures + ["Cannot identify cymbals or distinguish desirable attack from harshness"], descriptorProvenance + [Self.productionQualityCaution], &metrics)
            addBand("drums_2_5_khz_energy_ratio", spectrum.harshnessRatio, [.drums], "Presence-band evidence; never a direct harshness label", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.productionQualityCaution], &metrics)

        case .bass:
            let subBassShare = (spectrum.subRatio + spectrum.bassRatio) > 1e-20
                ? spectrum.subRatio / (spectrum.subRatio + spectrum.bassRatio)
                : 0
            addBand("bass_sub_share_20_120_hz", subBassShare, [.bass], "20-60 Hz share of combined 20-120 Hz energy", spectralConfidence, fftWindow, spectrumFailures + ["Fundamental range depends on tuning and part", "Monitoring and downstream filtering are not represented"], descriptorProvenance + practiceProvenance, &metrics)
            addBand("bass_120_350_hz_energy_ratio", spectrum.lowMidRatio, [.bass], "Low-mid concentration evidence", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + practiceProvenance, &metrics)
            addLevelVariability(sourceClass, dynamics, &metrics)
            add(
                "bass_positive_spectral_flux_p90", unit: .ratio, range: 0...10,
                value: spectrum.p90PositiveFlux, confidence: dynamicConfidence * spectralConfidence,
                applicability: [.bass], valid: activeSignal,
                windowing: fftWindow,
                aggregation: "Nearest-rank 90th percentile of normalized positive magnitude flux",
                failures: spectrumFailures + ["Pitch changes, distortion, and fret noise can resemble transient definition"],
                provenance: [Self.compressorAutomationProvenance, Self.essentiaProvenance]
            )
            add(
                "bass_crest_factor_p90", unit: .ratio, range: 0...1_000,
                value: dynamics.crestP90, confidence: dynamicConfidence,
                applicability: [.bass], valid: activeSignal,
                windowing: "200 ms windows with 50% nominal overlap, bounded to at most 2048 windows",
                aggregation: "90th percentile sample-peak/RMS ratio over active windows only",
                failures: ["Click noise, clipping, and sparse notes can dominate", "Windows more than 40 dB below the loudest window are excluded, so this is the performance's crest, not the capture's", "Does not by itself measure tightness or transient definition"],
                provenance: [Self.compressorAutomationProvenance]
            )

        case .guitar, .synthKeys:
            let applicable: [SourceAnalysisClass] = [.guitar, .synthKeys]
            addBand("spectral_occupied_bin_fraction", spectrum.occupiedBandFraction, applicable, "Spectral-density evidence relative to the capture's strongest bin", spectralConfidence, fftWindow, spectrumFailures + ["Noise, distortion, and long ambience increase occupancy"], descriptorProvenance, &metrics)
            addBand("maximum_third_octave_concentration_ratio", spectrum.maximumThirdOctaveConcentrationRatio, applicable, "Strongest one-third-octave energy concentration", spectralConfidence, fftWindow, spectrumFailures + ["A harmonic, note, or intentional voicing can dominate", "Concentration does not prove masking"], descriptorProvenance + [Self.bestPracticeProvenance], &metrics)
            addBand("source_2_5_khz_energy_ratio", spectrum.harshnessRatio, applicable, "Presence-band evidence; never a direct harshness label", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.productionQualityCaution], &metrics)
            addLevelVariability(sourceClass, dynamics, &metrics)
            add(
                "source_positive_spectral_flux_p90", unit: .ratio, range: 0...10,
                value: spectrum.p90PositiveFlux, confidence: dynamicConfidence * spectralConfidence,
                applicability: applicable, valid: activeSignal,
                windowing: fftWindow,
                aggregation: "Nearest-rank 90th percentile normalized positive magnitude flux",
                failures: spectrumFailures + ["Arpeggiation, filter motion, modulation, pick attack, and note changes are conflated"],
                provenance: [Self.compressorAutomationProvenance, Self.essentiaProvenance]
            )
            addStereoMetrics(sourceClass, buffer, stereo, &metrics)

        case .fullStereoMix:
            addBand("mix_below_250_hz_energy_ratio", spectrum.lowRatio, [.fullStereoMix], "Broad low-band balance evidence", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.automaticEQProvenance], &metrics)
            addBand("mix_250_hz_4_khz_energy_ratio", spectrum.midRatio, [.fullStereoMix], "Broad mid-band balance evidence", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.automaticEQProvenance], &metrics)
            addBand("mix_above_4_khz_energy_ratio", spectrum.highRatio, [.fullStereoMix], "Broad high-band balance evidence", spectralConfidence, fftWindow, spectrumFailures, descriptorProvenance + [Self.automaticEQProvenance], &metrics)
            add(
                "mix_spectral_slope_db_per_octave", unit: .decibelsPerOctave, range: -100...100,
                value: spectrum.slopeDBPerOctave, confidence: spectralConfidence,
                applicability: [.fullStereoMix], valid: activeSignal,
                windowing: fftWindow,
                aggregation: "Unweighted least-squares fit of log-power against log2 frequency above 20 Hz",
                failures: spectrumFailures + ["No universal target slope exists", "Arrangement and genre dominate broad slope"],
                provenance: [Self.bestPracticeProvenance, Self.automaticEQProvenance]
            )
            addLevelVariability(sourceClass, dynamics, &metrics)
            add(
                "mix_crest_factor_p90", unit: .ratio, range: 0...1_000,
                value: dynamics.crestP90, confidence: dynamicConfidence,
                applicability: [.fullStereoMix], valid: activeSignal,
                windowing: "200 ms windows with 50% nominal overlap, bounded to at most 2048 windows",
                aggregation: "90th percentile sample-peak/RMS ratio over active windows only",
                failures: ["Sparse peaks and fades can dominate", "Windows more than 40 dB below the loudest window are excluded, so this is the programme's crest, not the capture's", "Does not prove punch, dynamics, or quality"],
                provenance: [Self.compressorAutomationProvenance, Self.productionQualityCaution]
            )
            copyStandardsMetric("maximum_short_term_loudness_lufs", from: base, sourceClass: sourceClass, into: &metrics)
            copyStandardsMetric("loudness_range_lu", from: base, sourceClass: sourceClass, into: &metrics)
            copyStandardsMetric("integrated_loudness_lufs", from: base, sourceClass: sourceClass, into: &metrics)
            copyStandardsMetric("true_peak_dbtp", from: base, sourceClass: sourceClass, into: &metrics)
            addStereoMetrics(sourceClass, buffer, stereo, &metrics)
        }

        return SourceAwareAnalysisReport(sourceClass: sourceClass, baseReport: base, metrics: metrics)
    }

    private struct DynamicStatistics {
        var levelP90P10DB: Double
        var crestP90: Double
        var confidence: Double
    }

    /// Windows quieter than this many dB below the loudest window are treated as non-signal.
    ///
    /// This mirrors how the rest of the analysis treats silence: `TimeAveragedSpectrumAnalyzer`
    /// gates onsets and bin occupancy at `maximum * 0.0001`, which is the same -40 dB
    /// relative-to-capture-maximum floor expressed in power. A relative floor is used rather than
    /// an absolute dBFS threshold because captures arrive at arbitrary gain, so any fixed dBFS
    /// number would either pass a quiet capture's silence or discard a quiet capture's signal.
    /// `isFinite` alone is not enough: `amplitudeToDB` clamps digital silence to -240 dBFS rather
    /// than -inf, so silent gaps survive the filter and drag P10 down to the clamp, which is how
    /// this metric could report level variability wider than the format's own dynamic range.
    private static let activeWindowFloorDB = 40.0

    /// Absolute numerical-silence floor, below the least significant bit of 24-bit PCM (-144 dBFS)
    /// and above the -240 dBFS clamp. The relative floor alone cannot reject a capture that is
    /// silent throughout, because there is no loud window for it to be relative to.
    private static let numericalSilenceDBFS = -160.0

    private struct StereoStatistics {
        var sideEnergyShare: Double
        var monoSumEnergyRatio: Double
        var lowBandSideEnergyShare: Double
        var confidence: Double
    }

    private func dynamicStatistics(_ report: AnalysisReport) -> DynamicStatistics {
        let rms = report.series?["rms_dbfs_timeline"]?.values ?? []
        let crest = report.series?["crest_factor_timeline"]?.values ?? []
        let seriesConfidence = min(
            report.series?["rms_dbfs_timeline"]?.confidence ?? 0,
            report.series?["crest_factor_timeline"]?.confidence ?? 0
        )
        let finiteRMS = rms.filter { $0.isFinite }
        guard let loudest = finiteRMS.max() else {
            return DynamicStatistics(levelP90P10DB: 0, crestP90: 0, confidence: 0)
        }
        // Both timelines come from the same window starts, so gate by index and keep them aligned.
        // Crest has the same exposure: `dynamicsSeries` reports 0 for windows whose RMS is below
        // 1e-12, so silent gaps inject a run of zeroes that shifts every percentile rank.
        let activeFloor = max(loudest - Self.activeWindowFloorDB, Self.numericalSilenceDBFS)
        let activeIndices = rms.indices.filter { rms[$0].isFinite && rms[$0] > activeFloor }
        let activeRMS = activeIndices.map { rms[$0] }
        let activeCrest = activeIndices.compactMap { index in
            index < crest.count && crest[index].isFinite ? crest[index] : nil
        }
        // The metric needs at least two active windows to describe a range at all, and confidence
        // is scaled by the share of windows that survived gating so a value derived from a handful
        // of active windows in a mostly silent capture is not reported as strongly evidenced.
        guard activeRMS.count >= 2 else {
            return DynamicStatistics(levelP90P10DB: 0, crestP90: percentile(activeCrest, 0.90), confidence: 0)
        }
        let activeShare = Double(activeIndices.count) / Double(max(rms.count, 1))
        let p10 = percentile(activeRMS, 0.10)
        let p90 = percentile(activeRMS, 0.90)
        return DynamicStatistics(
            levelP90P10DB: max(0, p90 - p10),
            crestP90: percentile(activeCrest, 0.90),
            confidence: seriesConfidence * activeShare
        )
    }

    private func stereoStatistics(_ buffer: AudioBuffer) -> StereoStatistics {
        guard buffer.channelCount == 2, buffer.frameCount > 0 else {
            return StereoStatistics(sideEnergyShare: 0, monoSumEnergyRatio: 0, lowBandSideEnergyShare: 0, confidence: 0)
        }
        var midEnergy = 0.0
        var sideEnergy = 0.0
        var inputEnergy = 0.0
        var lowLeft = 0.0
        var lowRight = 0.0
        var lowMidEnergy = 0.0
        var lowSideEnergy = 0.0
        let cutoff = min(180.0, buffer.sampleRate * 0.1)
        let coefficient = 1 - exp(-2 * Double.pi * cutoff / buffer.sampleRate)
        for frame in 0..<buffer.frameCount {
            let rawLeft = buffer.channels[0][frame]
            let rawRight = buffer.channels[1][frame]
            let left = rawLeft.isFinite ? Double(rawLeft) : 0
            let right = rawRight.isFinite ? Double(rawRight) : 0
            let mid = (left + right) / sqrt(2)
            let side = (left - right) / sqrt(2)
            midEnergy += mid * mid
            sideEnergy += side * side
            inputEnergy += left * left + right * right
            lowLeft += coefficient * (left - lowLeft)
            lowRight += coefficient * (right - lowRight)
            let lowMid = (lowLeft + lowRight) / sqrt(2)
            let lowSide = (lowLeft - lowRight) / sqrt(2)
            lowMidEnergy += lowMid * lowMid
            lowSideEnergy += lowSide * lowSide
        }
        let stereoEnergy = midEnergy + sideEnergy
        let lowEnergy = lowMidEnergy + lowSideEnergy
        let confidence = min(1, Double(buffer.frameCount) / max(buffer.sampleRate, 1))
        return StereoStatistics(
            sideEnergyShare: stereoEnergy > 1e-20 ? sideEnergy / stereoEnergy : 0,
            monoSumEnergyRatio: inputEnergy > 1e-20 ? midEnergy / inputEnergy : 0,
            lowBandSideEnergyShare: lowEnergy > 1e-20 ? lowSideEnergy / lowEnergy : 0,
            confidence: confidence
        )
    }

    private func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let index = Int((Double(sorted.count - 1) * min(max(fraction, 0), 1)).rounded())
        return sorted[index]
    }

    private func addLevelVariability(
        _ sourceClass: SourceAnalysisClass,
        _ dynamics: DynamicStatistics,
        _ metrics: inout [String: SourceMetricValue]
    ) {
        let definition = SourceMetricDefinition(
            identifier: "level_variability_p90_p10_db",
            unit: .decibels,
            validRange: 0...240,
            sourceApplicability: SourceAnalysisClass.allCases,
            validConditions: ["Finite PCM audio", "At least two active 200 ms windows"],
            windowing: "200 ms RMS windows with 50% nominal overlap, bounded to at most 2048 windows, restricted to windows within 40 dB of the loudest window",
            aggregation: "Difference between 90th and 10th percentile RMS levels in dB over active windows only; confidence is scaled by the share of windows that survived gating",
            knownFailureModes: ["Fades, sparse notes, edits, and arrangement changes inflate the result", "Quiet performed material within 40 dB of the loudest window is measured, but anything below that floor is discarded with the room tone and silence", "It is level variability, not proof of inconsistent performance or a compression requirement"],
            version: "1.1",
            provenance: [Self.compressorAutomationProvenance, Self.multitrackCompressionProvenance]
        )
        metrics[definition.identifier] = SourceMetricValue(definition: definition, value: dynamics.levelP90P10DB, confidence: dynamics.confidence)
    }

    private func addTransientMetrics(
        _ sourceClass: SourceAnalysisClass,
        _ spectrum: SpectrumSummary,
        _ dynamics: DynamicStatistics,
        _ spectralConfidence: Double,
        _ dynamicConfidence: Double,
        _ windowing: String,
        _ spectrumFailures: [String],
        _ metrics: inout [String: SourceMetricValue]
    ) {
        func store(_ id: String, _ unit: MetricUnit, _ range: ClosedRange<Double>, _ value: Double, _ confidence: Double, _ aggregation: String, _ failures: [String]) {
            let definition = SourceMetricDefinition(
                identifier: id, unit: unit, validRange: range, sourceApplicability: [.drums],
                validConditions: ["Finite PCM audio", "At least four spectral frames", "Predominantly drum or drum-bus material"],
                windowing: windowing, aggregation: aggregation, knownFailureModes: failures,
                provenance: [Self.compressorAutomationProvenance, Self.logicEnvelopeProvenance, Self.essentiaProvenance]
            )
            metrics[id] = SourceMetricValue(definition: definition, value: value, confidence: confidence)
        }
        store("drums_positive_spectral_flux_p90", .ratio, 0...10, spectrum.p90PositiveFlux, dynamicConfidence * spectralConfidence, "90th percentile normalized positive magnitude flux", spectrumFailures + ["Flux indicates change, not drum identity or preferred punch"])
        store("drums_onset_candidate_density_per_second", .perSecond, 0...1_000, spectrum.transientDensityPerSecond, dynamicConfidence * spectralConfidence, "Positive-flux outliers above an adaptive within-capture threshold per second", spectrumFailures + ["Rolls, ambience, bleed, and edits can merge or create candidates"])
        store("drums_crest_factor_p90", .ratio, 0...1_000, dynamics.crestP90, dynamicConfidence, "90th percentile 200 ms sample-peak/RMS ratio over active windows only", ["Clipping and isolated clicks can dominate", "Windows more than 40 dB below the loudest window are excluded, so this is the performance's crest, not the capture's", "Does not prove punch"])
        store("drums_post_onset_sustain_ratio", .ratio, 0...10, spectrum.postOnsetSustainRatio, dynamicConfidence * spectralConfidence, "Median RMS-energy ratio roughly 40-190 ms after detected change relative to the event frame", spectrumFailures + ["Tempo, rolls, room decay, overlapping hits, and compression confound sustain"])
    }

    private func addBand(
        _ identifier: String,
        _ value: Double,
        _ applicability: [SourceAnalysisClass],
        _ interpretationBoundary: String,
        _ confidence: Double,
        _ windowing: String,
        _ failures: [String],
        _ provenance: [AnalysisProvenance],
        _ metrics: inout [String: SourceMetricValue]
    ) {
        let definition = SourceMetricDefinition(
            identifier: identifier,
            unit: .ratio,
            validRange: 0...1,
            sourceApplicability: applicability,
            validConditions: ["Finite PCM audio", "At least 64 frames", "Signal energy above numerical silence"],
            windowing: windowing,
            aggregation: "Energy in the named band or feature divided by the documented reference energy. \(interpretationBoundary).",
            knownFailureModes: failures,
            provenance: provenance
        )
        metrics[identifier] = SourceMetricValue(definition: definition, value: min(max(value, 0), 1), confidence: confidence)
    }

    private func addStereoMetrics(
        _ sourceClass: SourceAnalysisClass,
        _ buffer: AudioBuffer,
        _ stereo: StereoStatistics,
        _ metrics: inout [String: SourceMetricValue]
    ) {
        let applicable: [SourceAnalysisClass] = [.guitar, .synthKeys, .fullStereoMix]
        let commonFailures = ["Stereo balance, panning, decorrelation, delay, and ambience are conflated", "Windowed or frequency-local cancellation can be hidden by a whole-capture value", "Listening position and playback renderer are not represented"]
        func store(_ id: String, _ value: Double, _ aggregation: String, _ failures: [String]) {
            let definition = SourceMetricDefinition(
                identifier: id, unit: .ratio, validRange: 0...1,
                sourceApplicability: applicable,
                validConditions: ["Exactly two finite PCM channels", "At least one second is preferred", "Signal energy above numerical silence"],
                windowing: id == "low_band_side_energy_share" ? "Whole capture after linked one-pole low-pass at 180 Hz" : "Whole capture",
                aggregation: aggregation,
                knownFailureModes: failures,
                provenance: [Self.logicImagingProvenance, Self.bestPracticeProvenance, Self.productionQualityCaution]
            )
            metrics[id] = SourceMetricValue(definition: definition, value: min(max(value, 0), 1), confidence: buffer.channelCount == 2 ? stereo.confidence : 0)
        }
        store("side_energy_share", stereo.sideEnergyShare, "Side energy divided by orthonormal mid-plus-side energy", commonFailures + ["A wider value is not automatically better"])
        store("mono_sum_energy_ratio", stereo.monoSumEnergyRatio, "Energy of orthonormal mono sum divided by original two-channel energy", commonFailures + ["A value near one does not prove a good mono mix"])
        store("low_band_side_energy_share", stereo.lowBandSideEnergyShare, "Low-passed side energy divided by low-passed mid-plus-side energy", commonFailures + ["Crossover is a TrackSmith product heuristic, not a universal mono-bass boundary"])
    }

    private func copyStandardsMetric(
        _ identifier: String,
        from base: AnalysisReport,
        sourceClass: SourceAnalysisClass,
        into metrics: inout [String: SourceMetricValue]
    ) {
        guard let source = base.metrics[identifier] else { return }
        let provenance: [AnalysisProvenance]
        switch identifier {
        case "loudness_range_lu": provenance = [Self.lraProvenance]
        case "maximum_short_term_loudness_lufs": provenance = [Self.shortTermProvenance]
        default: provenance = [Self.bs1770Provenance]
        }
        let definition = SourceMetricDefinition(
            identifier: identifier,
            unit: source.definition.unit,
            validRange: source.definition.validRange,
            sourceApplicability: [.fullStereoMix],
            validConditions: identifier == "loudness_range_lu"
                ? ["Programme-like material", "At least one minute recommended by EBU R 128"]
                : ["Mono or stereo programme-like material", "Finite PCM audio"],
            windowing: source.definition.limitation,
            aggregation: "Standards-derived behavior documented in docs/LOUDNESS_STANDARDS_TRACEABILITY.md",
            knownFailureModes: ["Does not measure production quality or semantic intent", "Short isolated stems can be atypical programme material"],
            version: "1.0-standards-traceable",
            provenance: provenance
        )
        metrics[identifier] = SourceMetricValue(definition: definition, value: source.value, confidence: source.confidence)
    }

    private static let logicEffectsProvenance = AnalysisProvenance(
        sourceIdentity: "Apple, Logic Pro Effects for Mac",
        sourceVersion: "current guide downloaded 2026-07-14, SHA-256 b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819",
        relevantSection: "Dynamics, EQ, imaging, reverb, distortion, and metering chapters",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Use documented processor behavior to generate candidate strategies, never fixed semantic diagnoses."
    )

    private static let logicDeEsserProvenance = AnalysisProvenance(
        sourceIdentity: "Apple, Logic Pro Effects for Mac",
        sourceVersion: "current guide downloaded 2026-07-14",
        relevantSection: "DeEsser 2, pp. 95-97",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Use relative, event-aware 5-10 kHz evidence and bounded reduction; preserve natural consonants."
    )

    private static let logicEnvelopeProvenance = AnalysisProvenance(
        sourceIdentity: "Apple, Logic Pro Effects for Mac",
        sourceVersion: "current guide downloaded 2026-07-14",
        relevantSection: "Enveloper, pp. 97-98",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Represent attack and post-onset sustain separately."
    )

    private static let logicImagingProvenance = AnalysisProvenance(
        sourceIdentity: "Apple, Logic Pro Effects for Mac",
        sourceVersion: "current guide downloaded 2026-07-14",
        relevantSection: "Direction Mixer, Stereo Spread, Correlation Meter",
        evidenceClass: .professionalPracticeHeuristic,
        consequence: "Use mid/side, low-band side, mono-sum, and correlation evidence before widening."
    )

    private static let productBurstProvenance = AnalysisProvenance(
        sourceIdentity: "TrackSmith source-aware analysis design",
        sourceVersion: "1.0, 2026-07-14",
        relevantSection: "Robust within-capture transient-band event heuristic",
        evidenceClass: .productHeuristic,
        consequence: "Expose low/high burst evidence with failure modes; never emit plosive or sibilant as an automatic verdict."
    )

    private static let essentiaProvenance = AnalysisProvenance(
        sourceIdentity: "Bogdanov et al., Essentia: An Audio Analysis Library for MIR",
        sourceVersion: "ISMIR 2013, full paper SHA-256 ff3cf5310d0dc3fdb51355525437a5ca8c19ff3a510f1318dc495c179cd574f8",
        relevantSection: "Spectral, temporal, SFX descriptors and aggregation",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Low-level descriptors are implementable evidence; library inclusion does not validate a production meaning."
    )

    private static let productionQualityCaution = AnalysisProvenance(
        sourceIdentity: "Wilson and Fazenda, Perception & Evaluation of Audio Quality in Music Production",
        sourceVersion: "DAFx-13, full paper SHA-256 6809079a119e9d78e47d408223c49b66425ec450f8811260d1826728a0d5b2dd",
        relevantSection: "Feature construction, post-hoc 2-5 kHz band, results, limitations",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Band energy, crest, and width are descriptive only; do not infer harshness, quality, or an optimum."
    )

    private static let bestPracticeProvenance = AnalysisProvenance(
        sourceIdentity: "Pestana and Reiss, Intelligent Audio Production Strategies Informed by Best Practices",
        sourceVersion: "AES 53rd Conference 2014, SHA-256 5cb46304f10419c7f936d787fdc34ddef07a64d397cacc184288d8b34fb43b19",
        relevantSection: "EQ/masking, panning/mono compatibility, temporal effects, dynamics",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Use source/context-dependent evidence and reject blind high-pass, fixed low-mid cuts, or universal compressor timing."
    )

    private static let compressorAutomationProvenance = AnalysisProvenance(
        sourceIdentity: "Giannoulis, Massberg, and Reiss, Parameter Automation in a Dynamic Range Compressor",
        sourceVersion: "JAES 61(10), 2013, SHA-256 d1ac2af3fb7238bafa8c861edc5a907a286983dabffcdbc2e4cbb2f4a29d9bb8",
        relevantSection: "Crest factor, positive spectral flux, timing experiment, limitations",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Crest and flux may support timing hypotheses, but do not prescribe attack/release or compression need."
    )

    private static let multitrackCompressionProvenance = AnalysisProvenance(
        sourceIdentity: "Ma et al., Intelligent Multitrack Dynamic Range Compression",
        sourceVersion: "JAES 63(6), 2015, SHA-256 46852ebccfe3504ae4892c5fa89b6bd2e0ca8c4a0bc425b82e6f2b78e903b6d4",
        relevantSection: "Feature analysis, regression, evaluation, isolated-track limitations",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Level fluctuation is supporting evidence only; EBU LRA is weak for isolated-track compression choice."
    )

    private static let automaticEQProvenance = AnalysisProvenance(
        sourceIdentity: "Mockenhaupt, Rieber, and Nercessian, Automatic Equalization for Individual Instrument Tracks Using CNNs",
        sourceVersion: "DAFx-24/arXiv:2407.16691v1, SHA-256 b4926354e71ad2d620107f69dbfbf9227f84cef567bc6049fd9bc67247370a06",
        relevantSection: "Instrument classification, class-conditioned target construction, evaluation, limitations",
        evidenceClass: .peerReviewedResearchBacked,
        consequence: "Condition spectral hypotheses on source class; do not force one class-average or universal target."
    )

    private static let bs1770Provenance = AnalysisProvenance(
        sourceIdentity: "ITU-R BS.1770-5",
        sourceVersion: "11/2023, SHA-256 eefb926f72f72a96b96f251067bfee0650a0f29a26f60661d354162038b041ad",
        relevantSection: "Annexes 1-2",
        evidenceClass: .standardsBacked,
        consequence: "Use exact supported loudness/true-peak algorithms without treating them as quality metrics."
    )

    private static let shortTermProvenance = AnalysisProvenance(
        sourceIdentity: "EBU Tech 3341 v4",
        sourceVersion: "11/2023, SHA-256 dd5a7b0b611024e616b86a42c89eed0ded33f3129afc1994204885216fa1619e",
        relevantSection: "Section 2.2 and minimum requirements",
        evidenceClass: .standardsBacked,
        consequence: "Short-term loudness is ungated over a rectangular 3 s window at at least 10 Hz."
    )

    private static let lraProvenance = AnalysisProvenance(
        sourceIdentity: "EBU Tech 3342 v4 and EBU R 128 v5",
        sourceVersion: "11/2023, SHA-256 a12cb59fa4a8258d400bc931c7a79326a83a27c1cfd7b38220bc85ba5cfa89d8 / 4292cd2396e4cb386c3a6c1412cb4370fc108ef50956e78a24fbd8657ce2ca28",
        relevantSection: "Tech 3342 algorithm and R 128 short-program warning",
        evidenceClass: .standardsBacked,
        consequence: "Expose gated 10th-to-95th percentile LRA and reduce confidence below one minute."
    )
}
