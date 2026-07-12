import AudioToolbox
import Cocoa

public final class AudioUnitViewController: NSViewController, AUAudioUnitFactory {
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try AssistantAudioUnit(componentDescription: componentDescription)
    }

    public override func loadView() {
        let label = NSTextField(labelWithString: "Logic Audio Assistant\nOpen the companion app for conversation, previews, and history.")
        label.alignment = .center; label.maximumNumberOfLines = 3
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 220))
        label.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor), label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20)])
        self.view = view
    }
}
