import AppKit
import SwiftUI

/// Renders the real views into local PNGs without enabling an event tap or
/// requesting privacy permissions. Useful on a developer's active computer.
@MainActor
enum PreviewRenderer {
    static func render(to directory: URL, controller: CleaningController) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        controller.hasPermission = false
        try renderView(HomeView(controller: controller), size: NSSize(width: 540, height: 660),
                       to: directory.appendingPathComponent("home-permission.png"))
        controller.hasPermission = true
        try renderView(HomeView(controller: controller), size: NSSize(width: 540, height: 660),
                       to: directory.appendingPathComponent("home-ready.png"))
        try renderView(CleaningView(controller: controller, preview: true),
                       size: NSSize(width: 1280, height: 800),
                       to: directory.appendingPathComponent("cleaning.png"))
        controller.mode = .trackpad
        try renderView(HomeView(controller: controller), size: NSSize(width: 540, height: 660),
                       to: directory.appendingPathComponent("home-trackpad.png"))
        try renderView(CleaningView(controller: controller, preview: true),
                       size: NSSize(width: 1280, height: 800),
                       to: directory.appendingPathComponent("cleaning-trackpad.png"))
    }

    private static func renderView<V: View>(_ root: V, size: NSSize, to url: URL) throws {
        let hosting = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
        window.contentView = nil
        window.close()
    }
}
