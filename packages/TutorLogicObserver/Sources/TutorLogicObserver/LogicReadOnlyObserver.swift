import AppKit
import ApplicationServices
import Foundation
import TutorConversation

/// A deliberately one-way view of the visible Logic Pro accessibility tree.
///
/// This type contains no accessibility setters, actions, keyboard events, mouse
/// events, Apple Events, or Audio Unit commands. Its results describe only the
/// controls Logic exposes at the instant of the query.
@MainActor
public final class LogicReadOnlyObserver {
    public static let logicBundleIdentifier = "com.apple.logic10"
    public static let exposesMutationActions = false

    public init() {}

    public func observe(query: String, maximumNodes: Int = 900) -> TutorLogicObservation {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.logicBundleIdentifier
        ).first else {
            return TutorLogicObservation(
                status: .logicNotRunning,
                applicationName: "Logic Pro",
                bundleIdentifier: Self.logicBundleIdentifier,
                limitation: "Logic Pro was not running. No window or control was observed."
            )
        }

        guard AXIsProcessTrusted() else {
            return TutorLogicObservation(
                status: .permissionDenied,
                applicationName: application.localizedName ?? "Logic Pro",
                bundleIdentifier: application.bundleIdentifier,
                limitation: "Accessibility access is not currently granted to TrackSmith. The observer did not prompt, inspect, or control Logic."
            )
        }

        let root = AXUIElementCreateApplication(application.processIdentifier)
        let windows = elements(attribute: kAXWindowsAttribute as CFString, from: root)
        let focusedWindow = element(attribute: kAXFocusedWindowAttribute as CFString, from: root)
        let orderedWindows = focusedWindow.map { focused in
            [focused] + windows.filter { !CFEqual($0, focused) }
        } ?? windows
        let queryTokens = Self.tokens(query)
        var visited = Set<CFHashCode>()
        var queue: [(element: AXUIElement, depth: Int)] = orderedWindows.map { ($0, 0) }
        var matches: [(score: Int, control: TutorObservedControl)] = []
        var inspected = 0

        while !queue.isEmpty, inspected < min(max(maximumNodes, 1), 2_000), matches.count < 120 {
            let next = queue.removeFirst()
            let identity = CFHash(next.element)
            guard visited.insert(identity).inserted else { continue }
            inspected += 1

            let role = string(attribute: kAXRoleAttribute as CFString, from: next.element) ?? "unknown"
            let title = firstNonempty([
                string(attribute: kAXTitleAttribute as CFString, from: next.element),
                string(attribute: kAXDescriptionAttribute as CFString, from: next.element),
                string(attribute: kAXIdentifierAttribute as CFString, from: next.element),
                string(attribute: kAXHelpAttribute as CFString, from: next.element),
            ])
            let value = scalarString(attribute: kAXValueAttribute as CFString, from: next.element)
            let searchable = [role, title ?? "", value ?? ""].joined(separator: " ")
            let searchableTokens = Self.tokens(searchable)
            let overlap = queryTokens.intersection(searchableTokens)

            if !overlap.isEmpty, let title, !title.isEmpty {
                let labelTokens = Self.tokens(title)
                var score = overlap.count * 10
                if labelTokens.count == 1, let only = labelTokens.first, queryTokens.contains(only) { score += 30 }
                if title.caseInsensitiveCompare(query) == .orderedSame { score += 80 }
                if title.localizedCaseInsensitiveContains(query) { score += 40 }
                if role == "AXButton" { score += 2 }
                matches.append((score, TutorObservedControl(
                    role: Self.bounded(role, maximum: 120),
                    label: Self.bounded(title, maximum: 400),
                    value: value.map { Self.bounded($0, maximum: 240) },
                    frame: frame(of: next.element)
                )))
            }

            if next.depth < 14 {
                let children = elements(attribute: kAXChildrenAttribute as CFString, from: next.element)
                queue.append(contentsOf: children.prefix(180).map { ($0, next.depth + 1) })
            }
        }

        let windowTitle = orderedWindows.lazy.compactMap {
            self.string(attribute: kAXTitleAttribute as CFString, from: $0)
        }.first
        if matches.isEmpty {
            return TutorLogicObservation(
                status: .controlNotFound,
                applicationName: application.localizedName ?? "Logic Pro",
                bundleIdentifier: application.bundleIdentifier,
                windowTitle: windowTitle,
                limitation: "TrackSmith read \(inspected) visible accessibility nodes but found no semantic match for the query. Hidden controls and plug-in internals may not be exposed by Logic."
            )
        }
        let controls = matches.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.control.label.count != rhs.control.label.count {
                return lhs.control.label.count < rhs.control.label.count
            }
            return lhs.control.label < rhs.control.label
        }.prefix(40).map(\.control)
        return TutorLogicObservation(
            status: .observed,
            applicationName: application.localizedName ?? "Logic Pro",
            bundleIdentifier: application.bundleIdentifier,
            windowTitle: windowTitle,
            controls: controls,
            limitation: "Read-only Accessibility observation of visible UI only. This does not prove hidden state, project structure, automation, audio routing, or that the user changed a control."
        )
    }

    /// This is intentionally separate from `observe`: merely inspecting Logic
    /// never opens a system permission prompt. Call only from an explicit user
    /// action in TrackSmith settings or the Show Me flow.
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func copy(attribute: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value
    }

    private func element(attribute: CFString, from root: AXUIElement) -> AXUIElement? {
        guard let value = copy(attribute: attribute, from: root),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func elements(attribute: CFString, from root: AXUIElement) -> [AXUIElement] {
        guard let value = copy(attribute: attribute, from: root) as? [AnyObject] else { return [] }
        return value.compactMap { candidate in
            guard CFGetTypeID(candidate) == AXUIElementGetTypeID() else { return nil }
            return unsafeDowncast(candidate, to: AXUIElement.self)
        }
    }

    private func string(attribute: CFString, from element: AXUIElement) -> String? {
        guard let value = copy(attribute: attribute, from: element) else { return nil }
        if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let attributed = value as? NSAttributedString {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func scalarString(attribute: CFString, from element: AXUIElement) -> String? {
        guard let value = copy(attribute: attribute, from: element) else { return nil }
        if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func frame(of element: AXUIElement) -> TutorScreenRect? {
        guard let positionValue = copy(attribute: kAXPositionAttribute as CFString, from: element),
              let sizeValue = copy(attribute: kAXSizeAttribute as CFString, from: element),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(positionValue, to: AXValue.self), .cgPoint, &position),
              AXValueGetValue(unsafeDowncast(sizeValue, to: AXValue.self), .cgSize, &size),
              position.x.isFinite, position.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return TutorScreenRect(
            x: Double(position.x),
            y: Double(position.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }

    private func firstNonempty(_ values: [String?]) -> String? {
        for candidate in values {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return nil
    }

    private static func tokens(_ value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 })
    }

    private static func bounded(_ value: String, maximum: Int) -> String {
        guard value.utf8.count > maximum else { return value }
        return String(value.prefix(maximum))
    }
}

/// A mouse-transparent, non-activating visual callout owned by the companion app.
/// It never clicks or modifies the target control.
@MainActor
public final class LogicCalloutOverlayController {
    private var panel: NSPanel?

    public init() {}

    public func show(control: TutorObservedControl, message: String) -> Bool {
        guard let target = control.frame, let appKitFrame = Self.appKitFrame(for: target) else { return false }
        dismiss()
        let padding: CGFloat = 12
        let calloutHeight: CGFloat = 44
        let frame = NSRect(
            x: appKitFrame.minX - padding,
            y: appKitFrame.minY - padding - calloutHeight,
            width: max(appKitFrame.width + (padding * 2), 280),
            height: appKitFrame.height + (padding * 2) + calloutHeight
        )
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = LogicCalloutView(
            targetFrame: NSRect(
                x: padding,
                y: padding + calloutHeight,
                width: appKitFrame.width,
                height: appKitFrame.height
            ),
            message: message
        )
        panel.orderFrontRegardless()
        self.panel = panel
        return true
    }

    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private static func appKitFrame(for rect: TutorScreenRect) -> NSRect? {
        let center = CGPoint(x: rect.x + (rect.width / 2), y: rect.y + (rect.height / 2))
        for screen in NSScreen.screens {
            guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let displayBounds = CGDisplayBounds(CGDirectDisplayID(displayNumber.uint32Value))
            guard displayBounds.contains(center) else { continue }
            return NSRect(
                x: screen.frame.minX + CGFloat(rect.x) - displayBounds.minX,
                y: screen.frame.maxY - (CGFloat(rect.y) - displayBounds.minY) - CGFloat(rect.height),
                width: CGFloat(rect.width),
                height: CGFloat(rect.height)
            )
        }
        return nil
    }
}

@MainActor
private final class LogicCalloutView: NSView {
    private let targetFrame: NSRect
    private let message: String

    init(targetFrame: NSRect, message: String) {
        self.targetFrame = targetFrame
        self.message = message
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let highlight = NSBezierPath(roundedRect: targetFrame.insetBy(dx: 1, dy: 1), xRadius: 7, yRadius: 7)
        NSColor.systemYellow.withAlphaComponent(0.12).setFill()
        highlight.fill()
        NSColor.systemYellow.setStroke()
        highlight.lineWidth = 3
        highlight.stroke()

        let labelFrame = NSRect(x: 8, y: 7, width: bounds.width - 16, height: 28)
        let label = NSAttributedString(
            string: message,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.windowBackgroundColor.withAlphaComponent(0.94),
            ]
        )
        label.draw(in: labelFrame)
    }
}
