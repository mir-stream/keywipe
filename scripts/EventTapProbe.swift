import AppKit
import ApplicationServices

/// An opt-in integration check. Only events carrying this process's test marker
/// are filtered. The downstream sink consumes all test events before any app can
/// receive them; physical keyboard and trackpad events are never altered.
@main
struct EventTapProbe {
    final class State {
        let marker = Int64.random(in: 1_000_000...Int64.max)
        var filtering = false
        var upstream: [UInt32] = []
        var downstream: [UInt32] = []
        var mode: CleaningMode = .keyboard
        var trackpadState = TrackpadInputState()
    }

    static func main() {
        guard AXIsProcessTrusted() else {
            print("SKIP: this diagnostic process has no Accessibility permission.")
            exit(2)
        }
        verify(mode: .keyboard)
        verify(mode: .trackpad)
        print("PASS: both modes block and restore the expected input types.")
        print("Only tagged synthetic events were filtered. No physical keyboard or pointer input was blocked.")
    }

    static func verify(mode: CleaningMode) {
        let state = State()
        state.mode = mode
        let location: CGEventTapLocation = mode == .trackpad ? .cghidEventTap : .cgSessionEventTap
        let eventMask = KeyboardEventFilter.eventMask(for: mode)
        let pointer = Unmanaged.passUnretained(state).toOpaque()
        let sinkCallback: CGEventTapCallBack = { _, type, event, context in
            let state = Unmanaged<State>.fromOpaque(context!).takeUnretainedValue()
            guard event.getIntegerValueField(.eventSourceUserData) == state.marker else {
                return Unmanaged.passUnretained(event)
            }
            state.downstream.append(type.rawValue)
            return nil
        }
        let filterCallback: CGEventTapCallBack = { _, type, event, context in
            let state = Unmanaged<State>.fromOpaque(context!).takeUnretainedValue()
            guard event.getIntegerValueField(.eventSourceUserData) == state.marker else {
                return Unmanaged.passUnretained(event)
            }
            state.upstream.append(type.rawValue)
            if state.filtering && state.mode == .trackpad {
                state.trackpadState.observe(type: type, event: event, at: ProcessInfo.processInfo.systemUptime)
            }
            return state.filtering ? KeyboardEventFilter.filter(type: type, event: event, mode: state.mode)
                : Unmanaged.passUnretained(event)
        }

        guard let sink = CGEvent.tapCreate(tap: location, place: .tailAppendEventTap,
            options: .defaultTap, eventsOfInterest: eventMask,
            callback: sinkCallback, userInfo: pointer),
            let sinkSource = CFMachPortCreateRunLoopSource(nil, sink, 0) else {
            print("FAIL: cannot create diagnostic sink")
            exit(1)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), sinkSource, .commonModes)
        defer {
            CGEvent.tapEnable(tap: sink, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), sinkSource, .commonModes)
            CFMachPortInvalidate(sink)
        }
        guard let filter = CGEvent.tapCreate(tap: location, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: eventMask,
            callback: filterCallback, userInfo: pointer),
            let filterSource = CFMachPortCreateRunLoopSource(nil, filter, 0) else {
            print("FAIL: cannot create filter")
            exit(1)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), filterSource, .commonModes)
        defer {
            CGEvent.tapEnable(tap: filter, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), filterSource, .commonModes)
            CFMachPortInvalidate(filter)
        }

        let types = KeyboardEventFilter.keyboardTypes + (mode == .trackpad
            // AppKit gesture subtypes above 31 travel through Quartz as type
            // 29, rather than being directly postable CGEvent types.
            ? KeyboardEventFilter.pointerTypes
                + KeyboardEventFilter.gestureTypes.filter { $0.rawValue <= 31 } : [])
        let expected = types.map(\.rawValue).sorted()
        sendTestEvents(state, types: types, location: location)
        guard state.upstream.sorted() == expected && state.downstream.sorted() == expected else {
            print("FAIL: calibration upstream=\(state.upstream) downstream=\(state.downstream)")
            exit(1)
        }
        state.upstream.removeAll()
        state.downstream.removeAll()
        state.filtering = true
        sendTestEvents(state, types: types, location: location)
        guard state.upstream.sorted() == expected && state.downstream.isEmpty else {
            print("FAIL: filtered events reached the downstream sink")
            exit(1)
        }

        if mode == .trackpad {
            verifyEscapeHold(state, location: location)
            state.downstream.removeAll()
        }
        CGEvent.tapEnable(tap: filter, enable: false)
        state.upstream.removeAll()
        sendTestEvents(state, types: types, location: location)
        guard state.upstream.isEmpty && state.downstream.sorted() == expected else {
            print("FAIL: disabling the filter did not restore delivery")
            exit(1)
        }
        print("PASS: \(mode.rawValue), \(expected.count) event types, delivery → blocking → restoration.")
    }

    private static func sendTestEvents(_ state: State, types: [CGEventType], location: CGEventTapLocation) {
        let source = CGEventSource(stateID: .privateState)!
        let cursorLocation = CGEvent(source: nil)!.location
        for type in types {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0,
                                keyDown: type == .keyDown)!
            event.type = type
            event.flags = []
            event.location = cursorLocation
            event.setIntegerValueField(.eventSourceUserData, value: state.marker)
            event.post(tap: location)
            CFRunLoopRunInMode(.defaultMode, 0.02, false)
        }
        CFRunLoopRunInMode(.defaultMode, 0.2, false)
    }

    private static func verifyEscapeHold(_ state: State, location: CGEventTapLocation) {
        state.trackpadState = TrackpadInputState()
        let source = CGEventSource(stateID: .privateState)!
        func sendEscape(down: Bool) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: down)!
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: state.marker)
            event.post(tap: location)
            CFRunLoopRunInMode(.defaultMode, 0.05, false)
        }
        sendEscape(down: true)
        sendEscape(down: false)
        guard state.trackpadState.escapeProgress(at: ProcessInfo.processInfo.systemUptime) == 0 else {
            print("FAIL: short Esc press triggered unlock")
            exit(1)
        }
        sendEscape(down: true)
        CFRunLoopRunInMode(.defaultMode, 3.05, false)
        let now = ProcessInfo.processInfo.systemUptime
        guard state.trackpadState.escapeProgress(at: now) == 1,
              !state.trackpadState.isReadyToFinish(at: now) else {
            print("FAIL: 3-second Esc hold was not recognized")
            exit(1)
        }
        sendEscape(down: false)
        guard state.trackpadState.isReadyToFinish(at: ProcessInfo.processInfo.systemUptime),
              state.downstream.isEmpty else {
            print("FAIL: Esc release was not consumed cleanly")
            exit(1)
        }
        print("PASS: short Esc cancels; 3-second Esc unlocks after release without leaking Esc events.")
    }
}
