import Foundation
import TutorConversation
import TutorLogicObserver

@main
struct LogicTutorObservationProbe {
    @MainActor
    static func main() {
        let query = CommandLine.arguments.dropFirst().joined(separator: " ")
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let object: [String: Any] = [
                "error": "Provide a semantic control query, for example: swift run LogicTutorObservationProbe channel EQ",
                "read_only": true,
                "mutation_capability": false,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([0x0A]))
            }
            return
        }

        do {
            let observation: TutorLogicObservation = LogicReadOnlyObserver().observe(query: query)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(observation)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
        } catch {
            FileHandle.standardError.write(Data("Observation encoding failed.\n".utf8))
        }
    }
}
