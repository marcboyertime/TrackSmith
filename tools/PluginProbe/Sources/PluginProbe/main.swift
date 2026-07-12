import Foundation
import SharedIPC

@main
enum PluginProbe {
    static func main() throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["LOGIC_ASSISTANT_EXCHANGE"] ?? "/tmp/logic-audio-assistant-exchange")
        let exchange = try FileExchange(directory: directory)
        let message = ExchangeMessage(kind: .pluginHeartbeat, instanceID: UUID(), text: "audio-unit-probe-ready")
        let url = try exchange.send(message)
        print("heartbeat_id=\(message.id.uuidString)")
        print("path=\(url.path)")
    }
}
