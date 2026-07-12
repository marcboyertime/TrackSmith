import AgentCore
import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer
import PreviewWorkflow
import SharedIPC
import StateStore

@main
enum TestRunner {
    static func main() async {
        let tests = Harness()
        await tests.run("plan validation and Codable round trip") {
            let plan = makePlan(nodes: [.init(type: .parametricEQ, parameters: [.frequencyHz: 300, .q: 1, .gainDB: -2], rationale: "test", confidence: 0.8, category: .corrective)])
            try PlanValidator().validate(plan)
            let encoded = try JSONEncoder().encode(plan)
            let decoded = try JSONDecoder().decode(ProcessingPlan.self, from: encoded)
            try tests.expect(decoded == plan, "plan changed during serialization")
        }
        await tests.run("plan bounds fail closed") {
            let plan = makePlan(nodes: [.init(type: .compressor, parameters: [.ratio: 100], rationale: "bad", confidence: 1, category: .corrective)])
            try tests.expectThrows("out-of-range ratio was accepted") { try PlanValidator().validate(plan) }
            let unsupported = makePlan(nodes: [.init(type: .reverb, parameters: [.mix: 0.2], rationale: "future", confidence: 1, category: .creative)])
            try tests.expectThrows("unimplemented module was accepted") { try PlanValidator().validate(unsupported) }
        }
        await tests.run("DSP bypass is bit exact") {
            var buffer = AudioBuffer(channels: [[0, 0.1, -0.2, 0.3]], sampleRate: 48_000), graph = try CompiledGraph(plan: makePlan(), sampleRate: 48_000, channelCount: 1)
            let original = buffer; try graph.process(&buffer); try tests.expect(buffer == original, "bypass changed samples")
        }
        await tests.run("limiter and nonfinite safety") {
            let node = ProcessingNode(type: .limiter, parameters: [.ceilingDB: -6], rationale: "test", confidence: 1, category: .loudness)
            var buffer = AudioBuffer(channels: [[2, -2, .nan, .infinity]], sampleRate: 48_000), graph = try CompiledGraph(plan: makePlan(nodes: [node]), sampleRate: 48_000, channelCount: 1)
            try graph.process(&buffer)
            try tests.expect((buffer.channels[0].map(abs).max() ?? 1) <= 0.502, "limiter exceeded ceiling")
            try tests.expect(buffer.channels[0].allSatisfy(\.isFinite), "nonfinite sample escaped")
        }
        await tests.run("realtime pointer DSP matches offline graph across host blocks") {
            let nodes = [
                ProcessingNode(type: .inputTrim, parameters: [.gainDB: -1.5], rationale: "test", confidence: 1, category: .corrective),
                ProcessingNode(type: .highPass, parameters: [.frequencyHz: 70, .q: 0.707], rationale: "test", confidence: 1, category: .corrective),
                ProcessingNode(type: .parametricEQ, parameters: [.frequencyHz: 2_500, .q: 1.1, .gainDB: 2], rationale: "test", confidence: 1, category: .corrective),
                ProcessingNode(type: .compressor, parameters: [.thresholdDB: -20, .ratio: 2.5, .attackMS: 15, .releaseMS: 100, .makeupGainDB: 1, .kneeDB: 6, .mix: 0.8], rationale: "test", confidence: 1, category: .corrective),
                ProcessingNode(type: .saturation, parameters: [.driveDB: 2, .mix: 0.15], rationale: "test", confidence: 1, category: .creative),
                ProcessingNode(type: .stereoWidth, parameters: [.width: 1.15, .mix: 0.7], rationale: "test", confidence: 1, category: .creative),
                ProcessingNode(type: .limiter, parameters: [.ceilingDB: -1], rationale: "test", confidence: 1, category: .loudness),
            ]
            let rate = 48_000.0
            let left = (0..<4_097).map { Float(0.35 * sin(2 * .pi * 220 * Double($0) / rate)) }
            let right = (0..<4_097).map { Float(0.28 * sin(2 * .pi * 330 * Double($0) / rate + 0.2)) }
            let plan = makePlan(nodes: nodes)
            var offline = AudioBuffer(channels: [left, right], sampleRate: rate)
            var offlineGraph = try CompiledGraph(plan: plan, sampleRate: rate, channelCount: 2)
            try offlineGraph.process(&offline)

            var realtimeLeft = left
            var realtimeRight = right
            var realtimeGraph = try CompiledGraph(plan: plan, sampleRate: rate, channelCount: 2)
            let blockSizes = [32, 64, 127, 256, 511, 1_024]
            var offset = 0
            var blockIndex = 0
            while offset < realtimeLeft.count {
                let count = min(blockSizes[blockIndex % blockSizes.count], realtimeLeft.count - offset)
                let status = realtimeLeft.withUnsafeMutableBufferPointer { leftBuffer in
                    realtimeRight.withUnsafeMutableBufferPointer { rightBuffer in
                        realtimeGraph.processRealtime(
                            left: leftBuffer.baseAddress!.advanced(by: offset),
                            right: rightBuffer.baseAddress!.advanced(by: offset),
                            frameCount: count
                        )
                    }
                }
                try tests.expect(status == .processed, "pointer graph rejected a valid stereo block")
                offset += count
                blockIndex += 1
            }
            for frame in realtimeLeft.indices {
                try tests.expect(abs(realtimeLeft[frame] - offline.channels[0][frame]) < 1e-6, "left output diverged at frame \(frame)")
                try tests.expect(abs(realtimeRight[frame] - offline.channels[1][frame]) < 1e-6, "right output diverged at frame \(frame)")
            }
        }
        await tests.run("realtime pointer DSP fails dry on layout mismatch") {
            var samples: [Float] = [0.25, -0.5, 0.75]
            let original = samples
            var graph = try CompiledGraph(plan: makePlan(), sampleRate: 48_000, channelCount: 2)
            let status = samples.withUnsafeMutableBufferPointer {
                graph.processRealtime(left: $0.baseAddress!, frameCount: $0.count)
            }
            try tests.expect(status == .channelMismatch, "stereo graph accepted a missing right channel")
            try tests.expect(samples == original, "failed pointer processing changed dry audio")
        }
        await tests.run("required rates and buffer sizes") {
            let node = ProcessingNode(type: .compressor, parameters: [.thresholdDB: -18, .ratio: 3, .attackMS: 10, .releaseMS: 100, .makeupGainDB: 1, .kneeDB: 6, .mix: 1], rationale: "test", confidence: 1, category: .corrective)
            for rate in [44_100.0, 48_000, 88_200, 96_000, 192_000] { for frames in [32, 64, 128, 256, 512, 1_024] {
                var buffer = AudioBuffer(channels: [Array(repeating: 0.5, count: frames), Array(repeating: -0.5, count: frames)], sampleRate: rate)
                var graph = try CompiledGraph(plan: makePlan(nodes: [node]), sampleRate: rate, channelCount: 2); try graph.process(&buffer)
                try tests.expect(buffer.channels.flatMap { $0 }.allSatisfy(\.isFinite), "nonfinite output at \(rate)/\(frames)")
            }}
        }
        await tests.run("Float32 WAV round trip") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav"); defer { try? FileManager.default.removeItem(at: url) }
            let original = AudioBuffer(channels: [[0, 0.25, -0.25], [0.5, -0.5, 0]], sampleRate: 48_000)
            try WAVFile.writeFloat32(original, url: url)
            let decoded = try WAVFile.read(url: url)
            try tests.expect(decoded == original, "WAV samples changed")
        }
        await tests.run("PCM24 WAV round trip") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav"); defer { try? FileManager.default.removeItem(at: url) }
            let original = AudioBuffer(channels: [[-1, -0.25, 0, 0.25, 0.999]], sampleRate: 44_100)
            try WAVFile.writePCM24(original, url: url)
            let decoded = try WAVFile.read(url: url)
            for index in original.channels[0].indices {
                try tests.expect(abs(decoded.channels[0][index] - original.channels[0][index]) <= 1.3e-7, "PCM24 sample outside quantization tolerance")
            }
        }
        await tests.run("known sine analysis") {
            let rate = 48_000.0, frames = 2_048
            let samples = (0..<frames).map { Float(0.5 * sin(2 * .pi * 1_000 * Double($0) / rate)) }
            let report = AudioAnalyzer().analyze(AudioBuffer(channels: [samples], sampleRate: rate))
            try tests.expect(abs(report.metrics["peak_dbfs"]!.value + 6.0206) < 0.02, "peak inaccurate")
            try tests.expect(abs(report.metrics["rms_dbfs"]!.value + 9.03) < 0.1, "RMS inaccurate")
            try tests.expect(abs(report.metrics["spectral_centroid_hz"]!.value - 1_000) < 60, "centroid inaccurate")
            try tests.expect(report.metrics["spectral_flatness"]!.value < 0.01, "sine was not spectrally tonal")
        }
        await tests.run("time-averaged spectrum distinguishes noise and tone") {
            let rate = 48_000.0
            var state: UInt64 = 0x1234_5678_9ABC_DEF0
            let noise: [Float] = (0..<16_384).map { _ in
                state = state &* 6_364_136_223_846_793_005 &+ 1
                let unit = Double(state >> 11) / Double(UInt64.max >> 11)
                return Float((unit * 2 - 1) * 0.2)
            }
            let tone: [Float] = (0..<16_384).map { Float(0.2 * sin(2 * .pi * 1_000 * Double($0) / rate)) }
            let noiseReport = AudioAnalyzer().analyze(AudioBuffer(channels: [noise], sampleRate: rate))
            let toneReport = AudioAnalyzer().analyze(AudioBuffer(channels: [tone], sampleRate: rate))
            try tests.expect(noiseReport.metrics["spectral_flatness"]!.value > 0.45, "white noise flatness too low")
            try tests.expect(noiseReport.metrics["spectral_flatness"]!.value > toneReport.metrics["spectral_flatness"]!.value + 0.4, "flatness did not separate noise and tone")
        }
        await tests.run("BS.1770 full-scale 997 Hz calibration") {
            let rate = 48_000.0
            let samples = (0..<Int(rate * 3)).map { Float(sin(2 * .pi * 997 * Double($0) / rate)) }
            let measurement = BS1770Meter().measure(AudioBuffer(channels: [samples], sampleRate: rate))
            guard let loudness = measurement.integratedLUFS else { throw CheckFailure(message: "integrated loudness missing") }
            try tests.expect(abs(loudness + 3.01) < 0.08, "997 Hz calibration was \(loudness) LUFS")
            try tests.expect(abs(measurement.truePeakDBTP) < 0.08, "full-scale sine true peak was \(measurement.truePeakDBTP) dBTP")
        }
        await tests.run("BS.1770 relative gate rejects quiet tail") {
            let rate = 48_000.0
            let frames = Int(rate * 6)
            let samples = (0..<frames).map { index -> Float in
                let amplitude = index < frames / 2 ? 0.1 : 0.001
                return Float(amplitude * sin(2 * .pi * 997 * Double(index) / rate))
            }
            let measurement = BS1770Meter().measure(AudioBuffer(channels: [samples], sampleRate: rate))
            guard let loudness = measurement.integratedLUFS else { throw CheckFailure(message: "gated loudness missing") }
            try tests.expect(abs(loudness + 23.01) < 0.35, "relative gate produced \(loudness) LUFS")
            try tests.expect(measurement.includedBlockCount < measurement.gatingBlockCount, "relative gate included the quiet tail")
        }
        await tests.run("true-peak estimator detects inter-sample peak") {
            let rate = 48_000.0
            let angularFrequency = 2 * Double.pi * 12_000 / rate
            let phase = Double.pi / 4
            let samples: [Float] = (0..<4_800).map { index in
                Float(0.99 * sin(angularFrequency * Double(index) + phase))
            }
            let buffer = AudioBuffer(channels: [samples], sampleRate: rate)
            let samplePeak = samples.map(abs).max() ?? 0
            let truePeakDB = BS1770Meter().measure(buffer).truePeakDBTP
            let samplePeakDB = 20 * log10(Double(samplePeak))
            let expectedTruePeakDB = 20 * log10(0.99)
            try tests.expect(truePeakDB > samplePeakDB + 2.5, "inter-sample peak was not detected")
            try tests.expect(abs(truePeakDB - expectedTruePeakDB) < 0.2, "true peak estimate was \(truePeakDB) dBTP")
        }
        await tests.run("capture ring bounded chronology") {
            let ring = CaptureRingBuffer(capacityFrames: 4, channelCount: 1, sampleRate: 48_000)
            ring.write(AudioBuffer(channels: [[1, 2, 3]], sampleRate: 48_000)); ring.write(AudioBuffer(channels: [[4, 5, 6]], sampleRate: 48_000))
            try tests.expect(ring.snapshot().channels[0] == [3, 4, 5, 6], "ring did not retain latest frames")
        }
        await tests.run("three deterministic variants and revision") {
            let scope = ProcessingScope(kind: .pluginInput, channelFormat: .mono, sourceType: .vocal)
            let variants = try DeterministicPlanner().variants(prompt: "Make this clearer and more controlled", sourceSnapshotID: UUID(), scope: scope)
            try tests.expect(variants.map(\.strength) == [.conservative, .balanced, .strong], "missing variants")
            let revised = try PlanRevisionEngine().revise(variants[1].plan, request: "undo only the compression")
            try tests.expect(!revised.nodes.contains(where: { $0.type == .compressor }), "compressor remained")
        }
        await tests.run("adversarial planner prompts fail closed") {
            try tests.expectThrows("shell request accepted") { _ = try DeterministicPlanner().parseGoals(prompt: "run this shell command", sourceType: .vocal) }
            try tests.expectThrows("destructive request accepted") { _ = try DeterministicPlanner().parseGoals(prompt: "delete the original", sourceType: .vocal) }
        }
        await tests.run("loudness-matched preview preserves source") {
            let samples = (0..<4_096).map { Float(0.2 * sin(2 * .pi * 440 * Double($0) / 48_000)) }
            let source = AudioBuffer(channels: [samples], sampleRate: 48_000), node = ProcessingNode(type: .outputTrim, parameters: [.gainDB: 6], rationale: "test", confidence: 1, category: .loudness)
            let preview = try PreviewRenderer().render(plan: makePlan(nodes: [node]), source: source)
            try tests.expect(preview.status == .valid, "preview rejected")
            try tests.expect(abs(preview.analysis.metrics["rms_dbfs"]!.value + 16.99) < 0.3, "preview not level matched")
        }
        await tests.run("long preview uses BS.1770 loudness matching") {
            let rate = 48_000.0
            let samples = (0..<Int(rate * 3)).map { Float(0.2 * sin(2 * .pi * 997 * Double($0) / rate)) }
            let source = AudioBuffer(channels: [samples], sampleRate: rate)
            let node = ProcessingNode(type: .outputTrim, parameters: [.gainDB: 6], rationale: "test", confidence: 1, category: .loudness)
            let preview = try PreviewRenderer().render(plan: makePlan(nodes: [node]), source: source)
            try tests.expect(preview.loudnessMatchMethod == .bs1770Integrated, "long preview fell back from BS.1770")
            try tests.expect(abs(preview.loudnessMatchGainDB + 6) < 0.1, "BS.1770 match gain was \(preview.loudnessMatchGainDB) dB")
        }
        await tests.run("audible preview export preserves input and reloads outputs") {
            try testAudiblePreviewExport(tests)
        }
        await tests.run("snapshot undo and redo") {
            let store = SnapshotStore(), plan = makePlan()
            let root = ProcessingSnapshot(parentID: nil, plan: plan, analysisVersion: "1", sourceIdentity: "plugin", structuredGoals: [], commitStatus: .committed)
            let child = ProcessingSnapshot(parentID: root.id, plan: plan, analysisVersion: "1", sourceIdentity: "plugin", structuredGoals: [], commitStatus: .proposed)
            await store.add(root); await store.add(child)
            let undone = try await store.undo()
            let redone = try await store.redo()
            try tests.expect(undone.id == root.id, "undo target wrong"); try tests.expect(redone.id == child.id, "redo target wrong")
        }
        await tests.run("IPC message round trip") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: directory) }
            let exchange = try FileExchange(directory: directory), message = ExchangeMessage(kind: .pluginHeartbeat, instanceID: UUID(), text: "ready")
            try exchange.send(message)
            let received = try exchange.receive(id: message.id)
            try tests.expect(received == message, "message changed")
        }
        tests.finish()
    }

    private static func makePlan(nodes: [ProcessingNode] = []) -> ProcessingPlan {
        ProcessingPlan(sourceSnapshotID: UUID(), scope: .init(kind: .pluginInput, channelFormat: .mono, sourceType: .vocal), goals: [], nodes: nodes)
    }

    @MainActor private static func testAudiblePreviewExport(_ tests: Harness) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let input = root.appendingPathComponent("input.wav")
        let output = root.appendingPathComponent("previews", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let samples = (0..<8_192).map { index -> Float in
            let time = Double(index) / 48_000
            return Float(0.25 * sin(2 * .pi * 220 * time) + 0.08 * sin(2 * .pi * 3_200 * time))
        }
        let buffer = AudioBuffer(channels: [samples], sampleRate: 48_000)
        try WAVFile.writePCM24(buffer, url: input)
        let sourceBytes = try Data(contentsOf: input)
        let exporter = PreviewSessionExporter()
        let result = try exporter.export(inputURL: input, prompt: "make this clearer and more controlled", sourceType: .vocal, outputDirectory: output)
        try tests.expect(result.manifest.validVariantCount == 3, "expected three valid audible previews")
        let outputIsHidden = try output.resourceValues(forKeys: [.isHiddenKey]).isHidden ?? false
        try tests.expect(!outputIsHidden, "published preview directory is hidden")
        let sourceBytesAfterExport = try Data(contentsOf: input)
        try tests.expect(sourceBytesAfterExport == sourceBytes, "input WAV was modified")
        let originalURL = output.appendingPathComponent(result.manifest.originalAudioFileName)
        let original = try WAVFile.read(url: originalURL)
        try tests.expect(original.frameCount == samples.count, "exported original length changed")
        for variant in result.manifest.variants {
            guard let fileName = variant.audioFileName else { throw CheckFailure(message: "valid preview file missing") }
            let renderedURL = output.appendingPathComponent(fileName)
            let rendered = try WAVFile.read(url: renderedURL)
            try tests.expect(rendered.frameCount == samples.count, "preview length changed")
            let renderedIsHidden = try renderedURL.resourceValues(forKeys: [.isHiddenKey]).isHidden ?? false
            try tests.expect(!renderedIsHidden, "published preview file is hidden")
            let planURL = output.appendingPathComponent(variant.planFileName)
            try tests.expect(FileManager.default.fileExists(atPath: planURL.path), "plan file missing")
        }
        let manifestData = try Data(contentsOf: output.appendingPathComponent("manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedManifest = try decoder.decode(PreviewSessionManifest.self, from: manifestData)
        try tests.expect(decodedManifest.sourceFingerprint == result.manifest.sourceFingerprint, "manifest changed on disk")
        let loadedSession = try PreviewSessionLoader().load(directory: output)
        try tests.expect(loadedSession.auditionableVariants.count == 3, "safe session loader lost variants")
        try tests.expect(loadedSession.variants.allSatisfy { $0.planURL.deletingLastPathComponent() == output }, "loader escaped the session directory")

        var unsafeManifest = decodedManifest
        unsafeManifest.originalAudioFileName = "../escape.wav"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(unsafeManifest).write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
        try tests.expectThrows("unsafe manifest path was accepted") {
            _ = try PreviewSessionLoader().load(directory: output)
        }

        try encoder.encode(decodedManifest).write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
        let linkedPlanName = decodedManifest.variants[0].planFileName
        let linkedPlanURL = output.appendingPathComponent(linkedPlanName)
        try FileManager.default.removeItem(at: linkedPlanURL)
        try FileManager.default.createSymbolicLink(at: linkedPlanURL, withDestinationURL: input)
        try tests.expectThrows("artifact symlink escape was accepted") {
            _ = try PreviewSessionLoader().load(directory: output)
        }
        try tests.expectThrows("existing output directory was accepted") {
            _ = try exporter.export(inputURL: input, prompt: "clearer", sourceType: .vocal, outputDirectory: output)
        }
    }
}

@MainActor private final class Harness {
    private(set) var passed = 0
    private(set) var failed = 0
    func run(_ name: String, _ body: () async throws -> Void) async {
        do { try await body(); passed += 1; print("PASS \(name)") }
        catch { failed += 1; print("FAIL \(name): \(error)") }
    }
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws { if !condition() { throw CheckFailure(message: message) } }
    func expectThrows(_ message: String, _ body: () throws -> Void) throws { do { try body(); throw CheckFailure(message: message) } catch is CheckFailure { throw CheckFailure(message: message) } catch {} }
    func finish() { print("SUMMARY passed=\(passed) failed=\(failed)"); if failed > 0 { exit(1) } }
}

private struct CheckFailure: Error, CustomStringConvertible { let message: String; var description: String { message } }
