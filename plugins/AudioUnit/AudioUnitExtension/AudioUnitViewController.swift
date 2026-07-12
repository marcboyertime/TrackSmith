import AudioToolbox
import CoreAudioKit

@MainActor
public final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: AssistantAudioUnit?
    private var gainSlider: NSSlider!
    private var gainValueLabel: NSTextField!
    private var inputStatusLabel: NSTextField!
    private var refreshTimer: Timer?
    private var lastRenderCycleSeen: UInt64 = 0

    nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try DispatchQueue.main.sync {
            let unit = try AssistantAudioUnit(componentDescription: componentDescription)
            audioUnit = unit
            refreshControls()
            return unit
        }
    }

    public override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 250))
        let title = NSTextField(labelWithString: "Logic Audio Assistant")
        title.font = .systemFont(ofSize: 19, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Deterministic graph active · dry input retained in a bounded 30-second memory buffer")
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        inputStatusLabel = NSTextField(labelWithString: "Waiting for audio")
        inputStatusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)

        let gainTitle = NSTextField(labelWithString: "Output gain")
        gainSlider = NSSlider(value: 0, minValue: -24, maxValue: 12, target: self, action: #selector(gainChanged(_:)))
        gainSlider.isContinuous = true
        gainValueLabel = NSTextField(labelWithString: "0.0 dB")
        gainValueLabel.alignment = .right
        gainValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        gainValueLabel.widthAnchor.constraint(equalToConstant: 72).isActive = true

        let gainRow = NSStackView(views: [gainTitle, gainSlider, gainValueLabel])
        gainRow.orientation = .horizontal
        gainRow.spacing = 12
        gainSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let companionNote = NSTextField(labelWithString: "Open the companion app for conversation, previews, measurements, and history.")
        companionNote.textColor = .secondaryLabelColor
        companionNote.maximumNumberOfLines = 2

        let stack = NSStackView(views: [title, subtitle, inputStatusLabel, gainRow, companionNote])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        gainRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -22),
        ])
        view = root
        startRefreshTimer()
        refreshControls()
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        startRefreshTimer()
    }

    public override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func gainChanged(_ sender: NSSlider) {
        audioUnit?.parameterTree?.parameter(withAddress: 0)?.value = AUValue(sender.doubleValue)
        refreshControls()
    }

    private func refreshControls() {
        guard isViewLoaded, gainSlider != nil, let audioUnit else { return }
        let gain = audioUnit.parameterTree?.parameter(withAddress: 0)?.value ?? 0
        if !gainSlider.isHighlighted { gainSlider.doubleValue = Double(gain) }
        gainValueLabel.stringValue = String(format: "%+.1f dB", gain)
        let peak = audioUnit.inputPeakDBFS
        let renderCycle = audioUnit.completedRenderCycleCount
        let audioCallbackIsActive = renderCycle != lastRenderCycleSeen
        lastRenderCycleSeen = renderCycle
        inputStatusLabel.stringValue = audioCallbackIsActive && peak > -70
            ? String(format: "● Audio arriving   peak %+.1f dBFS", peak)
            : "○ Waiting for audio"
        inputStatusLabel.textColor = audioCallbackIsActive && peak > -70 ? .systemGreen : .secondaryLabelColor
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshControls() }
        }
    }
}
