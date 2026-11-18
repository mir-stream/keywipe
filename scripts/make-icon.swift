import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func drawIcon(pixels: Int, to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()

    NSColor(red: 0.10, green: 0.18, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                 xRadius: 202, yRadius: 202).fill()
    let mint = NSColor(red: 0.57, green: 0.91, blue: 0.79, alpha: 1)
    mint.setFill()
    NSBezierPath(roundedRect: NSRect(x: 177, y: 290, width: 670, height: 382),
                 xRadius: 54, yRadius: 54).fill()
    NSColor(red: 0.10, green: 0.18, blue: 0.16, alpha: 1).setFill()
    for row in 0..<3 {
        for col in 0..<9 {
            NSBezierPath(roundedRect: NSRect(x: 221 + col * 65, y: 430 + row * 68,
                                            width: 46, height: 45), xRadius: 10, yRadius: 10).fill()
        }
    }
    NSBezierPath(roundedRect: NSRect(x: 345, y: 345, width: 330, height: 42),
                 xRadius: 12, yRadius: 12).fill()
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 150, weight: .medium)) {
        symbol.lockFocus()
        mint.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        symbol.unlockFocus()
        symbol.draw(in: NSRect(x: 681, y: 682, width: 160, height: 160))
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(pixels: size, to: directory.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(pixels: size * 2, to: directory.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
