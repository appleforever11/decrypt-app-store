import AppKit
import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 56, y: 56, width: 912, height: 912)
let shape = NSBezierPath(roundedRect: rect, xRadius: 205, yRadius: 205)
NSGradient(colors: [NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.94, alpha: 1), NSColor(calibratedRed: 0.39, green: 0.29, blue: 0.94, alpha: 1)])!.draw(in: shape, angle: 55)
NSColor.white.withAlphaComponent(0.24).setStroke(); shape.lineWidth = 4; shape.stroke()
let card = NSBezierPath(roundedRect: NSRect(x: 265, y: 242, width: 494, height: 520), xRadius: 95, yRadius: 95)
NSColor.white.withAlphaComponent(0.14).setFill(); card.fill()
NSColor.white.withAlphaComponent(0.46).setStroke(); card.lineWidth = 5; card.stroke()
let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 512, y: 670)); arrow.line(to: NSPoint(x: 512, y: 400)); arrow.move(to: NSPoint(x: 404, y: 504)); arrow.line(to: NSPoint(x: 512, y: 396)); arrow.line(to: NSPoint(x: 620, y: 504))
NSColor.white.setStroke(); arrow.lineWidth = 47; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
let baseline = NSBezierPath(); baseline.move(to: NSPoint(x: 405, y: 324)); baseline.line(to: NSPoint(x: 619, y: 324)); baseline.lineWidth = 32; baseline.lineCapStyle = .round; baseline.stroke()
image.unlockFocus()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels)); NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
