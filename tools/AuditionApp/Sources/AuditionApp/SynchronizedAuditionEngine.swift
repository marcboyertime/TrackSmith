@preconcurrency import AVFoundation
import Foundation

enum AuditionEngineError: Error, CustomStringConvertible {
    case noAudio
    case bufferAllocationFailed(String)

    var description: String {
        switch self {
        case .noAudio: "No preview audio is loaded."
        case let .bufferAllocationFailed(file): "Could not allocate an audition buffer for \(file)."
        }
    }
}

/// Runs every version simultaneously through one AVAudioEngine. Selection only
/// changes player gains, so A/B switches retain the same sample position.
@MainActor
final class SynchronizedAuditionEngine {
    private var engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [AVAudioPCMBuffer] = []
    private var selectedIndex = 0
    private var hasStarted = false

    var progress: Double {
        guard let player = players.first,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime),
              let buffer = buffers.first, buffer.frameLength > 0 else { return 0 }
        let position = playerTime.sampleTime % AVAudioFramePosition(buffer.frameLength)
        return min(max(Double(position) / Double(buffer.frameLength), 0), 1)
    }

    func load(urls: [URL]) throws {
        unload()
        guard !urls.isEmpty else { throw AuditionEngineError.noAudio }
        engine = AVAudioEngine()
        for url in urls {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { throw AuditionEngineError.bufferAllocationFailed(url.lastPathComponent) }
            try file.read(into: buffer)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            players.append(player)
            buffers.append(buffer)
        }
        selectedIndex = 0
        updateVolumes()
        engine.prepare()
        try engine.start()
        scheduleFromBeginning()
    }

    func unload() {
        for player in players { player.stop() }
        engine.stop()
        players = []
        buffers = []
        hasStarted = false
        selectedIndex = 0
    }

    func select(index: Int) {
        guard players.indices.contains(index) else { return }
        selectedIndex = index
        updateVolumes()
    }

    func play() throws {
        guard !players.isEmpty else { throw AuditionEngineError.noAudio }
        if !engine.isRunning { try engine.start() }
        if hasStarted {
            for player in players { player.play() }
        } else {
            let startTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.05)
            let time = AVAudioTime(hostTime: startTime)
            for player in players { player.play(at: time) }
            hasStarted = true
        }
    }

    func pause() {
        for player in players { player.pause() }
    }

    func stopAndRewind() {
        for player in players { player.stop() }
        scheduleFromBeginning()
        hasStarted = false
    }

    private func scheduleFromBeginning() {
        for (player, buffer) in zip(players, buffers) {
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        }
    }

    private func updateVolumes() {
        for index in players.indices { players[index].volume = index == selectedIndex ? 1 : 0 }
    }
}
