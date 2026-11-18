import AppKit
@preconcurrency import ApplicationServices
import SwiftUI
import KeyWipeCore

@MainActor
final class CleaningController: ObservableObject {
    @Published var hasPermission = AXIsProcessTrusted()
    @Published var mode: CleaningMode = .keyboard
    @Published private(set) var isCleaning = false
    @Published private(set) var isFinishing = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var escapeProgress = 0.0
    @Published var notice: String?

    var showMainWindow: (() -> Void)?
    var hideMainWindow: (() -> Void)?
    private let blocker = KeyboardBlocker()
    private let cursorLock = CursorMotionLock()
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var startedAt: Double = 0
    private var releasedAt: Double?
    private var lastHealthCheck: Double = -.infinity
    private var previousPresentation: NSApplication.PresentationOptions = []

    init() {
        blocker.onInterruption = { [weak self] in
            self?.interrupt()
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func openPermissionSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshPermission() {
        let allowed = AXIsProcessTrusted()
        if hasPermission != allowed { hasPermission = allowed }
    }

    func startCleaning() {
        guard !isCleaning else { return }
        refreshPermission()
        guard !Self.hasPressedKeys else {
            notice = "키보드에서 손을 뗀 다음, 트랙패드로 시작해 주세요."
            return
        }
        guard !NSScreen.screens.isEmpty else {
            notice = "사용할 수 있는 화면이 없어요."
            return
        }
        do {
            try blocker.start(mode: mode)
        } catch {
            notice = error.localizedDescription
            return
        }
        notice = nil
        startedAt = ProcessInfo.processInfo.systemUptime
        elapsedSeconds = 0
        escapeProgress = 0
        isFinishing = false
        isCleaning = true
        previousPresentation = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        rebuildOverlays()
        if mode == .trackpad {
            guard NSApp.isActive, cursorLock.lock() == .success else {
                stopCleaning(message: "커서 이동을 멈추지 못했어요. KeyWipe 창에서 다시 시작해 주세요.")
                return
            }
        }
        hideMainWindow?()
    }

    func requestFinish() {
        guard isCleaning else { return }
        isFinishing = true
        releasedAt = nil
        tick()
    }

    func stopCleaning(message: String? = nil, showWindow: Bool = true) {
        guard isCleaning else { return }
        cursorLock.unlock()
        blocker.stop()
        isCleaning = false
        isFinishing = false
        escapeProgress = 0
        releasedAt = nil
        closeOverlays()
        NSApp.presentationOptions = previousPresentation
        notice = message
        if showWindow { showMainWindow?() }
    }

    func interrupt() {
        stopCleaning(message: "입력 차단이 중단됐어요. 청소를 멈추고 권한을 확인한 뒤 다시 시작해 주세요.")
    }

    func screenConfigurationChanged() {
        guard isCleaning else { return }
        guard !NSScreen.screens.isEmpty else {
            stopCleaning(message: "화면 연결이 바뀌어 청소 모드를 끝냈어요.")
            return
        }
        rebuildOverlays()
    }

    func bringCleaningToFront() {
        for window in windows { window.orderFrontRegardless() }
        windows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func shutdown() {
        stopCleaning(showWindow: false)
        cursorLock.unlock()
        blocker.stop()
        timer?.invalidate()
    }

    func applicationResignedActive() {
        guard isCleaning, mode == .trackpad else { return }
        // Cursor association is a foreground-app API. Never leave the UI
        // claiming protection after the application loses that condition.
        stopCleaning(message: "다른 앱으로 전환되어 트랙패드 청소 모드를 끝냈어요.", showWindow: false)
    }

    func applicationBecameActive() {
        refreshPermission()
        if !isCleaning { cursorLock.unlock() }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastHealthCheck >= 0.25 {
            lastHealthCheck = now
            refreshPermission()
            if isCleaning && !blocker.isHealthy {
                interrupt()
                return
            }
        }
        guard isCleaning else { return }
        let seconds = Int(now - startedAt)
        if elapsedSeconds != seconds { elapsedSeconds = seconds }
        if mode == .trackpad && !isFinishing {
            let progress = blocker.escapeProgress(at: now)
            if escapeProgress != progress { escapeProgress = progress }
            if progress >= 1 {
                requestFinish()
                return
            }
        }
        guard isFinishing else { return }
        // Do not let a key still under the cloth repeat into another app when
        // the overlay disappears. Caps Lock's toggle state is not a held key.
        if Self.hasPressedKeys || (mode == .trackpad && !blocker.isReadyToFinish(at: now)) {
            releasedAt = nil
        } else if let releasedAt, now - releasedAt >= 0.25 {
            stopCleaning(message: "깨끗해졌네요. 입력을 다시 사용할 수 있어요.")
        } else if releasedAt == nil {
            releasedAt = now
        }
    }

    private static var hasPressedKeys: Bool {
        (0..<128).contains { code in
            code != 57 && CGEventSource.keyState(.hidSystemState, key: CGKeyCode(code))
        }
    }

    private func closeOverlays() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        windows.removeAll()
    }

    private func rebuildOverlays() {
        closeOverlays()
        for screen in NSScreen.screens {
            let window = CleaningWindow(contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false, screen: screen)
            window.setFrame(screen.frame, display: false)
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.backgroundColor = NSColor(red: 0.055, green: 0.075, blue: 0.085, alpha: 1)
            window.isOpaque = true
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(rootView: CleaningView(controller: self))
            windows.append(window)
        }
        bringCleaningToFront()
    }
}

private final class CleaningWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
