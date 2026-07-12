@preconcurrency import AVFoundation
import AppKit
import Combine
import DSPCore
import Foundation
import PreviewWorkflow

struct AuditionChoice: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let audioURL: URL
    let variant: PreviewVariantManifest?
}

struct WaveformBin: Sendable {
    let minimum: Float
    let maximum: Float
}

@MainActor
final class AuditionModel: ObservableObject {
    @Published private(set) var session: LoadedPreviewSession?
    @Published private(set) var choices: [AuditionChoice] = []
    @Published private(set) var waveform: [WaveformBin] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var progress = 0.0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let engine = SynchronizedAuditionEngine()
    private var progressTimer: Timer?
    private var lastResultIndex = 1

    var selectedChoice: AuditionChoice? {
        choices.indices.contains(selectedIndex) ? choices[selectedIndex] : nil
    }

    var durationSeconds: Double { session?.manifest.durationSeconds ?? 0 }

    init(initialDirectory: URL?) {
        startProgressTimer()
        if let initialDirectory { Task { await load(directory: initialDirectory) } }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open a Logic Audio Assistant preview folder"
        panel.prompt = "Open Session"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { Task { await load(directory: url) } }
    }

    func load(directory: URL) async {
        isLoading = true
        errorMessage = nil
        isPlaying = false
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try PreviewSessionLoader().load(directory: directory)
            }.value
            let envelope = try await Task.detached(priority: .userInitiated) {
                try Self.makeWaveform(url: loaded.originalAudioURL, binCount: 900)
            }.value
            let newChoices = Self.makeChoices(session: loaded)
            guard newChoices.count >= 2 else {
                throw PreviewSessionLoadError.invalidManifest("the session has no valid rendered options")
            }
            try engine.load(urls: newChoices.map(\.audioURL))
            session = loaded
            choices = newChoices
            waveform = envelope
            selectedIndex = 0
            lastResultIndex = min(1, newChoices.count - 1)
            progress = 0
            engine.select(index: 0)
        } catch {
            engine.unload()
            session = nil
            choices = []
            waveform = []
            errorMessage = String(describing: error)
        }
        isLoading = false
    }

    func select(index: Int) {
        guard choices.indices.contains(index) else { return }
        selectedIndex = index
        if index > 0 { lastResultIndex = index }
        engine.select(index: index)
    }

    func toggleOriginalResult() {
        select(index: selectedIndex == 0 ? min(lastResultIndex, choices.count - 1) : 0)
    }

    func togglePlayback() {
        guard !choices.isEmpty else { return }
        do {
            if isPlaying { engine.pause() } else { try engine.play() }
            isPlaying.toggle()
        } catch {
            isPlaying = false
            errorMessage = String(describing: error)
        }
    }

    func stop() {
        engine.stopAndRewind()
        isPlaying = false
        progress = 0
    }

    func revealSession() {
        guard let directory = session?.directory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func clearError() { errorMessage = nil }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progress = self.engine.progress
            }
        }
    }

    nonisolated private static func makeChoices(session: LoadedPreviewSession) -> [AuditionChoice] {
        var result = [AuditionChoice(
            id: "original",
            title: "Original",
            subtitle: "Unprocessed source",
            audioURL: session.originalAudioURL,
            variant: nil
        )]
        for loaded in session.auditionableVariants {
            guard let audioURL = loaded.audioURL else { continue }
            let title = loaded.manifest.strength.rawValue.capitalized
            let delta = String(format: "%.1f dBFS delta", loaded.manifest.difference.differenceRMSDBFS)
            result.append(.init(
                id: loaded.manifest.previewID.uuidString,
                title: title,
                subtitle: delta,
                audioURL: audioURL,
                variant: loaded.manifest
            ))
        }
        return result
    }

    nonisolated private static func makeWaveform(url: URL, binCount: Int) throws -> [WaveformBin] {
        let audio = try WAVFile.read(url: url)
        guard audio.frameCount > 0 else { return [] }
        let bins = min(binCount, audio.frameCount)
        return (0..<bins).map { bin in
            let start = bin * audio.frameCount / bins
            let end = max(start + 1, (bin + 1) * audio.frameCount / bins)
            var minimum: Float = 1
            var maximum: Float = -1
            for frame in start..<min(end, audio.frameCount) {
                var mono: Float = 0
                for channel in audio.channels { mono += channel[frame] / Float(audio.channelCount) }
                minimum = min(minimum, mono)
                maximum = max(maximum, mono)
            }
            return .init(minimum: minimum, maximum: maximum)
        }
    }
}
