import AppKit
import ApplicationServices

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private final class CounterView: NSView {
    let marker: Int64
    var clicks = 0
    var scrolls = 0
    init(marker: Int64) {
        self.marker = marker
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 160))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == marker { clicks += 1 }
    }
    override func scrollWheel(with event: NSEvent) {
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == marker { scrolls += 1 }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let title = "KeyWipe 입력 차단 검사" as NSString
        title.draw(at: NSPoint(x: 30, y: 94), withAttributes: [
            .font: NSFont.systemFont(ofSize: 21, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ])
        ("클릭·스크롤을 검사한 뒤 자동으로 닫힙니다." as NSString)
            .draw(at: NSPoint(x: 30, y: 56), withAttributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
    }
}

@main
struct InteractionProbe {
    final class FilterState {
        let marker = Int64.random(in: 1_000_000...Int64.max)
        var enabled = false
    }

    @MainActor
    static func main() {
        do { try verify() }
        catch { print("FAIL:", error); exit(1) }
    }

    @MainActor
    private static func verify() throws {
        guard AXIsProcessTrusted() else { throw ProbeFailure(description: "Inspector needs Accessibility permission") }
        let previousApp = NSWorkspace.shared.frontmostApplication
        let previousCursor = CGEvent(source: nil)!.location
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let state = FilterState()
        let view = CounterView(marker: state.marker)
        let window = NSWindow(contentRect: view.bounds, styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.title = "KeyWipe 입력 차단 검사"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        defer {
            window.orderOut(nil)
            window.close()
            CGWarpMouseCursorPosition(previousCursor)
            previousApp?.activate(options: [])
        }
        pump(0.4)
        guard app.isActive else { throw ProbeFailure(description: "Probe window did not become active") }

        let callback: CGEventTapCallBack = { _, type, event, context in
            let state = Unmanaged<FilterState>.fromOpaque(context!).takeUnretainedValue()
            guard state.enabled, event.getIntegerValueField(.eventSourceUserData) == state.marker else {
                return Unmanaged.passUnretained(event)
            }
            return KeyboardEventFilter.filter(type: type, event: event, mode: .trackpad)
        }
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: KeyboardEventFilter.eventMask(for: .trackpad),
            callback: callback, userInfo: Unmanaged.passUnretained(state).toOpaque()),
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            throw ProbeFailure(description: "Cannot install the HID input filter")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        defer {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFMachPortInvalidate(tap)
        }
        let cursorLock = CursorMotionLock()
        defer { cursorLock.unlock() }

        let point = window.convertPoint(toScreen: NSPoint(x: view.bounds.midX, y: view.bounds.midY))
        let target = CGPoint(x: point.x, y: NSScreen.screens[0].frame.height - point.y)
        sendInput(marker: state.marker, at: target)
        guard view.clicks == 1, view.scrolls == 1 else {
            throw ProbeFailure(description: "Baseline delivery: clicks=\(view.clicks), scrolls=\(view.scrolls)")
        }
        print("PASS: native view receives one click and one scroll before filtering.")

        state.enabled = true
        guard cursorLock.lock() == .success else {
            throw ProbeFailure(description: "macOS rejected cursor disassociation")
        }
        sendInput(marker: state.marker, at: target)
        guard view.clicks == 1, view.scrolls == 1 else {
            throw ProbeFailure(description: "Input leaked into the native view while filtering")
        }
        print("PASS: native view receives zero additional clicks or scrolls while filtering.")
        guard cursorLock.unlock() == .success else {
            throw ProbeFailure(description: "macOS rejected cursor restoration")
        }
        state.enabled = false
        sendInput(marker: state.marker, at: target)
        guard view.clicks == 2, view.scrolls == 2 else {
            throw ProbeFailure(description: "Input delivery did not recover after filtering")
        }
        print("PASS: native click/scroll delivery recovers after filtering ends.")
        print("PASS: foreground cursor disassociation and restoration both succeed.")
        print("Physical trackpad movement still requires a device check.")
    }

    @MainActor
    private static func sendInput(marker: Int64, at point: CGPoint) {
        let source = CGEventSource(stateID: .privateState)!
        for type: CGEventType in [.mouseMoved, .leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type,
                                mouseCursorPosition: point, mouseButton: .left)!
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
            pump(0.08)
        }
        let scroll = CGEvent(scrollWheelEvent2Source: source, units: .pixel,
                             wheelCount: 1, wheel1: 12, wheel2: 0, wheel3: 0)!
        scroll.location = point
        scroll.flags = []
        scroll.setIntegerValueField(.eventSourceUserData, value: marker)
        scroll.post(tap: .cghidEventTap)
        pump(0.15)
    }

    @MainActor
    private static func pump(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let event = NSApp.nextEvent(matching: .any, until: deadline,
                                          inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }
}
