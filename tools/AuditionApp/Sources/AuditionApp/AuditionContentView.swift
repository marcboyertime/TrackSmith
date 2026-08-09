import PlanSchema
import PreviewWorkflow
import SwiftUI

struct AuditionContentView: View {
    @ObservedObject var model: AuditionModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            if let session = model.session {
                sessionView(session)
            } else {
                emptyView
            }
            if model.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView("Validating and loading session…").padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Cannot Open Preview Session", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.clearError() } }
        )) { Button("OK") { model.clearError() } } message: { Text(model.errorMessage ?? "Unknown error") }
    }

    private var emptyView: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.plus").font(.system(size: 54)).foregroundStyle(.secondary)
            Text("Audition a preview session").font(.title2.weight(.semibold))
            Text("Open a folder created by PreviewCLI. Every file and saved plan is validated before playback.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 520)
                Button("Open Preview Folder…") { model.chooseFolder() }.buttonStyle(.borderedProminent).controlSize(.large)
            Text("Or launch with: swift run -c release AuditionApp \"/path/to/preview folder\"")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
        }.padding(40)
    }

    private func sessionView(_ session: LoadedPreviewSession) -> some View {
        VStack(spacing: 0) {
            header(session)
            Divider()
            ScrollView {
                VStack(spacing: 18) {
                    WaveformPanel(bins: model.waveform, progress: model.progress, duration: model.durationSeconds)
                    transportAndChoices
                    details
                }.padding(20)
            }
        }
    }

    private func header(_ session: LoadedPreviewSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.directory.lastPathComponent).font(.headline)
                Text(session.manifest.prompt).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Label("Validated", systemImage: "checkmark.shield.fill").foregroundStyle(.green).font(.subheadline.weight(.medium))
            Text("\(session.manifest.channelCount == 1 ? "Mono" : "Stereo") • \(Int(session.manifest.sampleRate)) Hz")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Reveal", systemImage: "folder") { model.revealSession() }
            Button("Open…") { model.chooseFolder() }
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var transportAndChoices: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button { model.togglePlayback() } label: {
                    Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                }.buttonStyle(.borderedProminent).controlSize(.large)
                Button { model.stop() } label: { Image(systemName: "stop.fill") }.controlSize(.large)
                Button("A/B Original", systemImage: "arrow.left.arrow.right") { model.toggleOriginalResult() }
                    .controlSize(.large).help("Press A to toggle the selected result against the original")
                Spacer()
                Text("Space: play/pause   A: original/result   0–3: select")
                    .font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                ForEach(Array(model.choices.enumerated()), id: \.element.id) { index, choice in
                    ChoiceButton(choice: choice, index: index, selected: model.selectedIndex == index) {
                        model.select(index: index)
                    }
                }
            }
        }
    }

    @ViewBuilder private var details: some View {
        if let choice = model.selectedChoice {
            if let variant = choice.variant {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 12) {
                        MetricsCard(variant: variant)
                        if !variant.warnings.isEmpty { WarningCard(warnings: variant.warnings) }
                    }.frame(width: 300)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Processing chain").font(.headline)
                        ForEach(Array(variant.plan.nodes.enumerated()), id: \.element.id) { index, node in
                            ProcessingNodeCard(index: index + 1, node: node)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                GroupBox {
                    HStack {
                        Image(systemName: "waveform").foregroundStyle(.secondary)
                        Text("The original is playing with no processing. Choose a result, then press A for an instant sample-aligned comparison.")
                        Spacer()
                    }.padding(8)
                }
            }
        }
    }
}

private struct ChoiceButton: View {
    let choice: AuditionChoice
    let index: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(index)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(choice.title).font(.headline)
                    Spacer()
                    if selected { Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint) }
                }
                Text(choice.subtitle).font(.caption).foregroundStyle(.secondary)
            }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

private struct MetricsCard: View {
    let variant: PreviewVariantManifest
    var body: some View {
        GroupBox("Measured result") {
            VStack(spacing: 8) {
                metric("Match method", matchMethodName)
                metric("Match gain", String(format: "%+.2f dB", variant.loudnessMatchGainDB))
                metric("Audio delta", String(format: "%.1f dBFS", variant.difference.differenceRMSDBFS))
                metric("Crest change", String(format: "%+.2f dB", variant.difference.crestFactorDeltaDB))
                metric("Centroid change", String(format: "%+.0f Hz", variant.difference.spectralCentroidDeltaHz))
                if let loudness = variant.analysis.metrics["integrated_loudness_lufs"]?.value {
                    metric("Integrated", String(format: "%.2f LUFS", loudness))
                }
                if let peak = variant.analysis.metrics["true_peak_dbtp"]?.value {
                    metric("True peak", String(format: "%.2f dBTP", peak))
                }
            }.padding(.vertical, 6)
        }
    }
    private func metric(_ name: String, _ value: String) -> some View {
        HStack { Text(name).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }
            .font(.subheadline)
    }

    private var matchMethodName: String {
        switch variant.loudnessMatchMethod {
        case .bs1770Integrated: "BS.1770 integrated"
        case .rmsFallback: "RMS fallback"
        case .unavailable: "Unavailable"
        }
    }
}

private struct WarningCard: View {
    let warnings: [String]
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Analysis warnings", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.headline)
                ForEach(warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }
}

private struct ProcessingNodeCard: View {
    let index: Int
    let node: ProcessingNode

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("\(index)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(nodeDisplayName).font(.headline)
                    Text(node.category.rawValue.capitalized).font(.caption).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                    if node.locked { Label("Locked", systemImage: "lock.fill").font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Text("\(Int(node.confidence * 100))% confidence").font(.caption).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 6) {
                    ForEach(node.parameters.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { key in
                        HStack { Text(parameterDisplayName(key)).foregroundStyle(.secondary); Text(format(node.parameters[key] ?? 0, key: key)) }
                            .font(.caption.monospacedDigit())
                    }
                }
                Text(node.rationale).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(5)
        }
    }

    private var nodeDisplayName: String {
        switch node.type {
        case .inputTrim: "Input trim"
        case .polarity: "Polarity"
        case .highPass: "High-pass filter"
        case .lowPass: "Low-pass filter"
        case .parametricEQ: "Parametric EQ"
        case .compressor: "Compressor"
        case .expander: "Expander"
        case .deEsser: "De-esser"
        case .softClipper: "Soft clipper"
        case .saturation: "Saturation"
        case .transientShaper: "Transient shaper"
        case .stereoWidth: "Stereo width"
        case .midSideEQ: "Mid/side EQ"
        case .delay: "Delay"
        case .modulatedDelay: "Modulated delay"
        case .reverb: "Reverb"
        case .limiter: "Limiter"
        case .outputTrim: "Output trim"
        case .loudnessMatch: "Loudness match"
        case .meter: "Meter"
        }
    }

    private func parameterDisplayName(_ parameter: ParameterID) -> String {
        switch parameter {
        case .gainDB: "Gain"
        case .frequencyHz: "Frequency"
        case .q: "Q"
        case .thresholdDB: "Threshold"
        case .ratio: "Ratio"
        case .attackMS: "Attack"
        case .releaseMS: "Release"
        case .makeupGainDB: "Makeup gain"
        case .ceilingDB: "Ceiling"
        case .kneeDB: "Knee"
        case .mix: "Mix"
        case .width: "Width"
        case .driveDB: "Drive"
        case .enabled: "Enabled"
        case .lookaheadMS: "Lookahead"
        case .algorithmVersion: "Algorithm version"
        case .delayTimeMS: "Delay time"
        case .feedback: "Feedback"
        case .damping: "Damping"
        case .stereoCrossfeed: "Stereo crossfeed"
        case .modulationDepthMS: "Modulation depth"
        case .modulationRateHz: "Modulation rate"
        case .stereoPhaseDegrees: "Stereo phase"
        case .preDelayMS: "Predelay"
        case .decayTimeSeconds: "Decay time"
        case .roomSize: "Room size"
        case .diffusion: "Diffusion"
        case .holdMS: "Hold"
        case .hysteresisDB: "Hysteresis"
        case .rangeDB: "Range"
        }
    }

    private func format(_ value: Double, key: ParameterID) -> String {
        switch key {
        case .frequencyHz: value >= 1_000 ? String(format: "%.2f kHz", value / 1_000) : String(format: "%.0f Hz", value)
        case .attackMS, .releaseMS, .lookaheadMS, .delayTimeMS, .modulationDepthMS, .preDelayMS, .holdMS: String(format: "%.1f ms", value)
        case .thresholdDB, .makeupGainDB, .gainDB, .ceilingDB, .driveDB, .kneeDB, .hysteresisDB, .rangeDB: String(format: "%+.2f dB", value)
        case .decayTimeSeconds: String(format: "%.2f s", value)
        case .modulationRateHz: String(format: "%.2f Hz", value)
        case .stereoPhaseDegrees: String(format: "%.0f°", value)
        case .ratio: String(format: "%.2f:1", value)
        case .mix, .feedback, .damping, .stereoCrossfeed, .roomSize, .diffusion: String(format: "%.0f%%", value * 100)
        default: String(format: "%.3f", value)
        }
    }
}
