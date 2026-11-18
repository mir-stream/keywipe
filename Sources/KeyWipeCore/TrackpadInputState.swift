import CoreGraphics

/// Keeps only pressed key codes/button numbers in memory, never typed text.
public struct TrackpadInputState {
    private var escapeHold = EscapeHold()
    private var heldKeys: Set<Int64> = []
    private var heldButtons: Set<Int64> = []
    private var heldModifiers: CGEventFlags = []
    private var lastPointerActivity: Double = -.infinity

    public init() {}

    public func escapeProgress(at time: Double) -> Double { escapeHold.progress(at: time) }

    public func isReadyToFinish(at time: Double) -> Bool {
        heldKeys.isEmpty && heldButtons.isEmpty && heldModifiers.isEmpty
            && time - lastPointerActivity >= 0.25
    }

    public mutating func observe(type: CGEventType, event: CGEvent, at time: Double) {
        if type == .keyDown || type == .keyUp {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if type == .keyDown { heldKeys.insert(code) }
            else { heldKeys.remove(code) }
            if code == 53 {
                if type == .keyDown {
                    escapeHold.keyDown(at: time,
                        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
                } else { escapeHold.keyUp(at: time) }
            }
        } else if type == .flagsChanged {
            heldModifiers = event.flags.intersection([
                .maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn,
            ])
        }
        if KeyboardEventFilter.pointerTypes.contains(type)
            || KeyboardEventFilter.gestureTypes.contains(type) {
            lastPointerActivity = time
        }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) {
            heldButtons.insert(event.getIntegerValueField(.mouseEventButtonNumber))
        } else if [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(type) {
            heldButtons.remove(event.getIntegerValueField(.mouseEventButtonNumber))
        }
    }
}
