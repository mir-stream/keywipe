import CoreGraphics

/// The filter never reads characters or writes a keystroke log.
public enum KeyboardEventFilter {
    // NSEvent's systemDefined events carry media/brightness keys (NX_SYSDEFINED).
    public static let systemDefined = CGEventType(rawValue: 14)!

    public static let keyboardTypes: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged, systemDefined,
    ]

    public static let pointerTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
        .mouseMoved, .leftMouseDragged, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel,
    ]

    // Quartz delivers raw multitouch gestures as type 29. Type 30 also carries
    // Dock/Space gestures; the remaining AppKit types cover translated events.
    public static let gestureTypes: [CGEventType] =
        [18, 19, 20, 29, 30, 31, 32, 33, 34, 37, 38].map { CGEventType(rawValue: $0)! }

    public static var eventMask: CGEventMask {
        (keyboardTypes + pointerTypes).reduce(0) { $0 | (CGEventMask(1) << $1.rawValue) }
    }

    public static func eventMask(for mode: CleaningMode) -> CGEventMask {
        // Trackpad cleaning suppresses every input type, including gesture
        // events that are not enumerated in the public CGEventType enum.
        mode == .trackpad ? UInt64.max : eventMask
    }

    public static func filter(type: CGEventType, event: CGEvent,
                              mode: CleaningMode = .keyboard) -> Unmanaged<CGEvent>? {
        if mode == .trackpad { return nil }
        if keyboardTypes.contains(type) { return nil }
        if pointerTypes.contains(type) {
            // Include device-dependent left/right modifier bits in the low word.
            // A held Command/Control key must not alter the unlock click.
            let modifiers = CGEventFlags.maskAlphaShift.rawValue
                | CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
                | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
                | CGEventFlags.maskSecondaryFn.rawValue | CGEventFlags.maskHelp.rawValue
                | CGEventFlags.maskNumericPad.rawValue | 0xFFFF
            let nonCoalesced = event.flags.intersection(.maskNonCoalesced)
            event.flags = CGEventFlags(rawValue: event.flags.rawValue & ~modifiers)
                .union(nonCoalesced)
        }
        return Unmanaged.passUnretained(event)
    }
}
