import AppKit
import ApplicationServices
import Carbon
import KeyWipeCore

@MainActor
final class KeyboardBlocker {
    enum StartError: LocalizedError {
        case permission, secureInput, tapUnavailable

        var errorDescription: String? {
            switch self {
            case .permission:
                return "손쉬운 사용에서 KeyWipe를 허용한 뒤 다시 시작해 주세요."
            case .secureInput:
                return "보안 입력이 사용 중이에요. 암호 입력창을 닫은 뒤 다시 시작해 주세요."
            case .tapUnavailable:
                return "입력 차단을 시작하지 못했어요. 권한을 확인하고 앱을 다시 열어 주세요."
            }
        }
    }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var mode: CleaningMode = .keyboard
    private var trackpadState = TrackpadInputState()
    private var generation = 0
    var onInterruption: (() -> Void)?

    func escapeProgress(at time: Double) -> Double { trackpadState.escapeProgress(at: time) }

    func isReadyToFinish(at time: Double) -> Bool {
        trackpadState.isReadyToFinish(at: time)
    }

    var isHealthy: Bool {
        guard let tap else { return false }
        return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
            && AXIsProcessTrusted() && !IsSecureEventInputEnabled()
    }

    func start(mode: CleaningMode) throws {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { throw StartError.permission }
        guard !IsSecureEventInputEnabled() else { throw StartError.secureInput }
        self.mode = mode
        generation += 1

        let callback: CGEventTapCallBack = { _, type, event, context in
            // This source is attached exclusively to the main run loop. The
            // callback does no I/O, logging, rendering, or asynchronous waiting.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let context {
                    MainActor.assumeIsolated {
                        let owner = Unmanaged<KeyboardBlocker>.fromOpaque(context)
                            .takeUnretainedValue()
                        let generation = owner.generation
                        // Do not silently continue displaying a protected state.
                        DispatchQueue.main.async { [weak owner] in
                            guard let owner, owner.generation == generation else { return }
                            owner.onInterruption?()
                        }
                    }
                }
                return Unmanaged.passUnretained(event)
            }
            guard let context else { return Unmanaged.passUnretained(event) }
            let mode = MainActor.assumeIsolated {
                let owner = Unmanaged<KeyboardBlocker>.fromOpaque(context).takeUnretainedValue()
                if owner.mode == .trackpad {
                    owner.trackpadState.observe(type: type, event: event,
                        at: ProcessInfo.processInfo.systemUptime)
                }
                return owner.mode
            }
            return KeyboardEventFilter.filter(type: type, event: event, mode: mode)
        }

        guard let newTap = CGEvent.tapCreate(
            // Stop pointer/gesture delivery at the earliest tap. Cursor motion
            // itself is frozen separately with CursorMotionLock. Do not
            // silently fall back to a later tap if this one is unavailable.
            tap: mode == .trackpad ? .cghidEventTap : .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: KeyboardEventFilter.eventMask(for: mode),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw StartError.tapUnavailable }

        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            throw StartError.tapUnavailable
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard isHealthy else {
            stop()
            throw StartError.tapUnavailable
        }
    }

    func stop() {
        generation += 1
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        source = nil
        tap = nil
        trackpadState = TrackpadInputState()
    }
}
