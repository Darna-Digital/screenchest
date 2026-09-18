// Rasterizes an SVG into a PNG of the given pixel size using AppKit, so the app
// icon can be generated without any tools beyond the Xcode command line tools.
// Usage: swift scripts/render-icon.swift <in.svg> <out.png> <size>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let size = Int(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: render-icon.swift <in.svg> <out.png> <size>\n".utf8))
    exit(2)
}
let source = URL(fileURLWithPath: arguments[1])
let destination = URL(fileURLWithPath: arguments[2])

guard let image = NSImage(contentsOf: source) else {
    FileHandle.standardError.write(Data("render-icon: cannot load \(source.path)\n".utf8))
    exit(1)
}
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: destination)
