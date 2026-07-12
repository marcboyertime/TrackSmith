import AgentCore
import AudioAnalysis
import DSPCore
import Foundation
import PlanSchema
import PreviewRenderer
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
        await tests.run("required rates and buffer sizes") {
            let node = ProcessingNode(type: .compressor, parameters: [.thresholdDB: -18, .ratio: 3, .attackMS: 10, .releaseMS: 100, .makeupGainDB: 1, .mix: 1], rationale: "test", confidence: 1, category: .corrective)
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
        await tests.run("known sine analysis") {
            let rate = 48_000.0, frames = 2_048
            let samples = (0..<frames).map { Float(0.5 * sin(2 * .pi * 1_000 * Double($0) / rate)) }
            let report = AudioAnalyzer().analyze(AudioBuffer(channels: [samples], sampleRate: rate))
            try tests.expect(abs(report.metrics["peak_dbfs"]!.value + 6.0206) < 0.02, "peak inaccurate")
            try tests.expect(abs(report.metrics["rms_dbfs"]!.value + 9.03) < 0.1, "RMS inaccurate")
            try tests.expect(abs(report.metrics["spectral_centroid_hz"]!.value - 1_000) < 60, "centroid inaccurate")
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
