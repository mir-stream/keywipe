import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@main
enum KeyWipeMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let controller = CleaningController()
    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--render-previews"), arguments.count > index + 1 {
            do {
                try PreviewRenderer.render(to: URL(fileURLWithPath: arguments[index + 1]),
                                           controller: controller)
                print("Rendered five previews; input filtering was never enabled.")
            } catch {
                fputs("Preview failed: \(error)\n", stderr)
                exit(1)
            }
            NSApp.terminate(nil)
            return
        }
        if arguments.contains("--diagnostics") {
            print("Accessibility permission: \(AXIsProcessTrusted())")
            print("Secure input active: \(IsSecureEventInputEnabled())")
            print("Connected displays: \(NSScreen.screens.count)")
            print("Keyboard filtering: inactive")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)
        configureMenu()
        configureWindow()
        configureStatusItem()
        controller.showMainWindow = { [weak self] in self?.showWindow() }
        controller.hideMainWindow = { [weak self] in self?.mainWindow?.orderOut(nil) }

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sessionPaused),
            name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sessionPaused),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sessionPaused),
            name: NSWorkspace.screensDidSleepNotification, object: nil)
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidResignActive(_ notification: Notification) {
        controller.applicationResignedActive()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        controller.applicationBecameActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }

    @objc private func showWindow() {
        if controller.isCleaning { controller.bringCleaningToFront() }
        else {
            controller.refreshPermission()
            mainWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func screensChanged() { controller.screenConfigurationChanged() }

    @objc private func sessionPaused() {
        controller.stopCleaning(message: "잠자기 또는 사용자 전환으로 청소 모드를 끝냈어요.",
                                showWindow: false)
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "KeyWipe 보기", action: #selector(showWindow), keyEquivalent: "")
            .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "KeyWipe 종료", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    private func configureWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "KeyWipe"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: HomeView(controller: controller))
        window.delegate = self
        window.center()
        mainWindow = window
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyWipe")
        item.button?.toolTip = "KeyWipe · 키보드·트랙패드 청소"
        let menu = NSMenu()
        menu.addItem(withTitle: "KeyWipe 보기", action: #selector(showWindow), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "KeyWipe 종료", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }
}
