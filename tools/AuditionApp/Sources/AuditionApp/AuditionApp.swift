import AppKit
import SwiftUI

@MainActor
@main
enum LogicAssistantAuditionApp {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = AuditionApplicationDelegate()
        application.delegate = delegate
        application.run()
        _ = delegate
    }
}

@MainActor
private final class AuditionApplicationDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var model: AuditionModel?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let argument = ProcessInfo.processInfo.arguments.dropFirst().first
        let initialDirectory = argument.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let model = AuditionModel(initialDirectory: initialDirectory)
        self.model = model

        let content = AuditionContentView(model: model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_180, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Logic Audio Assistant — Preview Audition"
        window.minSize = NSSize(width: 960, height: 680)
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        installMenu()
        installKeyboardControl()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func openSession() { model?.chooseFolder() }

    private func installKeyboardControl() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let characters = event.charactersIgnoringModifiers?.lowercased() else { return event }
            let command = event.modifierFlags.contains(.command)
            if command, characters == "." { self.model?.stop(); return nil }
            if command { return event }
            switch characters {
            case " ": self.model?.togglePlayback(); return nil
            case "a": self.model?.toggleOriginalResult(); return nil
            case "0", "1", "2", "3":
                if let index = Int(characters) { self.model?.select(index: index) }
                return nil
            default: return event
            }
        }
    }

    private func installMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Preview Audition", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let open = fileMenu.addItem(withTitle: "Open Preview Folder…", action: #selector(openSession), keyEquivalent: "o")
        open.target = self
        fileItem.submenu = fileMenu
        NSApplication.shared.mainMenu = main
    }
}
