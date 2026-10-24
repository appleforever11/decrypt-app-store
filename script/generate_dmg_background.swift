import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 720, height = 480
let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()
let full = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [NSColor(calibratedRed: 0.91, green: 0.95, blue: 1.0, alpha: 1), NSColor(calibratedRed: 0.79, green: 0.86, blue: 0.98, alpha: 1)])!.draw(in: full, angle: 30)
func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    (value as NSString).draw(in: NSRect(x: 30, y: y, width: 660, height: size*1.6), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
}
text("Decrypt App Store", y: 376, size: 32, weight: .bold, color: NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.32, alpha: 1))
text("Your apps. On your Mac.", y: 344, size: 16, weight: .regular, color: NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.45, alpha: 1))
for x in [CGFloat(132), CGFloat(452)] {
    let card = NSBezierPath(roundedRect: NSRect(x: x, y: 133, width: 136, height: 140), xRadius: 29, yRadius: 29)
    NSColor.white.withAlphaComponent(0.38).setFill(); card.fill()
    NSColor.white.withAlphaComponent(0.72).setStroke(); card.lineWidth = 1; card.stroke()
}
let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 318, y: 205)); arrow.line(to: NSPoint(x: 402, y: 205)); arrow.move(to: NSPoint(x: 382, y: 225)); arrow.line(to: NSPoint(x: 402, y: 205)); arrow.line(to: NSPoint(x: 382, y: 185)); arrow.lineWidth = 4; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.16, green: 0.40, blue: 0.86, alpha: 0.9).setStroke(); arrow.stroke()
text("Drag the app to Applications", y: 68, size: 18, weight: .medium, color: NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.32, alpha: 1))
text("Then open it from your Applications folder.", y: 40, size: 13, weight: .regular, color: NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.45, alpha: 1))
image.unlockFocus()
// A logical 720 × 480 background keeps Finder's coordinates deterministic.
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: full); NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
