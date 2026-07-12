import Foundation
import LogicBridge

@main
enum LogicIntegrationProbe {
    static func main() async throws {
        let adapter = MockLogicAdapter()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(await adapter.capabilities()), as: UTF8.self))
    }
}
