import SharedIPC
import SwiftUI

@main
struct CompanionMacApp: App {
    var body: some Scene { WindowGroup { ContentView() }.defaultSize(width: 980, height: 680) }
}

struct ContentView: View {
    @State private var prompt = "Make this clearer and more controlled"
    @State private var status = "Waiting for an Audio Unit instance"

    var body: some View {
        NavigationSplitView {
            List { Label("Current Session", systemImage: "waveform"); Label("Snapshots", systemImage: "clock.arrow.circlepath") }
                .navigationTitle("Sessions")
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Circle().fill(.orange).frame(width: 10, height: 10); Text(status); Spacer(); Text("CPU —  Latency —") }
                RoundedRectangle(cornerRadius: 8).fill(.quaternary).overlay { Text("Waveform appears after bounded plug-in capture").foregroundStyle(.secondary) }.frame(height: 190)
                HStack { Button("Capture Next Playback") { status = "Capture request queued" }; Button("Analyze Recent Playback") { status = "Analysis request queued" }; Toggle("Level match", isOn: .constant(true)) }
                TextField("Describe the result", text: $prompt, axis: .vertical).textFieldStyle(.roundedBorder)
                HStack { ForEach(["Conservative", "Balanced", "Strong"], id: \.self) { Text($0).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 6)) } }
                GroupBox("Applied changes") { Text("No committed processing graph").frame(maxWidth: .infinity, alignment: .leading).padding(8) }
                HStack { Button("Original / Result") {}; Button("Undo") {}; Button("Redo") {}; Spacer(); Button("Revert") {}; Button("Commit") {}.buttonStyle(.borderedProminent) }
            }.padding(20).navigationTitle("Logic Audio Assistant")
        }
    }
}
