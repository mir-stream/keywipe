import AppKit
import SwiftUI
import KeyWipeCore

struct HoldToFinishButton: NSViewRepresentable {
    let onFinish: () -> Void

    func makeNSView(context: Context) -> HoldButtonView {
        let view = HoldButtonView()
        view.onFinish = onFinish
        return view
    }

    func updateNSView(_ nsView: HoldButtonView, context: Context) {
        nsView.onFinish = onFinish
    }

    static func dismantleNSView(_ nsView: HoldButtonView, coordinator: ()) {
        nsView.cancel()
    }
}

@MainActor
final class HoldButtonView: NSView {
    var onFinish: (() -> Void)?
    private var gesture = HoldGesture()
    private var timer: Timer?
    private var tracking: NSTrackingArea?
    private var hovering = false
    private var progress: Double { gesture.progress(at: ProcessInfo.processInfo.systemUptime) }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("청소 끝내기")
        setAccessibilityHelp("트랙패드나 마우스로 2초간 누른 뒤 놓으세요.")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        cancel()
    }

    override func mouseDown(with event: NSEvent) {
        cancel()
        gesture.begin(at: ProcessInfo.processInfo.systemUptime)
        let ticker = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay = true }
        }
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if !bounds.contains(convert(event.locationInWindow, from: nil)) { cancel() }
    }

    override func mouseUp(with event: NSEvent) {
        let confirmed = gesture.release(at: ProcessInfo.processInfo.systemUptime,
            inside: bounds.contains(convert(event.locationInWindow, from: nil)))
        cancel()
        if confirmed { onFinish?() }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        gesture.cancel()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancel() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: hovering ? 0.17 : 0.12, alpha: 1).setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor(red: 0.57, green: 0.91, blue: 0.79, alpha: 1).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width * progress,
               height: rect.height).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: 1, alpha: hovering ? 0.35 : 0.2).setStroke()
        path.lineWidth = 1
        path.stroke()

        let title = progress >= 1 ? "손을 떼면 해제돼요" : "청소 끝내기"
        let text = title as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
        // Keep the lettering legible on both the dark and filled portions.
        NSGraphicsContext.saveGraphicsState()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width * progress,
               height: rect.height).clip()
        var filledAttributes = attributes
        filledAttributes[.foregroundColor] = NSColor(calibratedWhite: 0.08, alpha: 1)
        text.draw(at: point, withAttributes: filledAttributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}
