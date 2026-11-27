// Generates the "Dusk Lake" starter scene: seven PNG layers, two masks and scene.json (format version 2).
// Usage: swift scripts/make-dusk-lake.swift "App/Resources/StarterPack/Dusk Lake"
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let W = 2048, H = 1280

func png(_ name: String, gray: Bool = false, _ draw: (CGContext) -> Void) {
    let context = gray
        ? CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        : CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(context)
    let destination = CGImageDestinationCreateWithURL(out.appending(path: name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination), "couldn't write \(name)")
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func ridge(_ c: CGContext, base: CGFloat, amplitude: CGFloat, frequency: CGFloat, fill: CGColor) {
    c.move(to: .zero)
    for x in stride(from: 0, through: W, by: 8) {
        let u = CGFloat(x) / CGFloat(W)
        c.addLine(to: CGPoint(x: CGFloat(x), y: base + amplitude * (1 - abs(sin(u * frequency))) + amplitude * 0.15 * sin(u * 40)))
    }
    c.addLine(to: CGPoint(x: W, y: 0)); c.closePath(); c.setFillColor(fill); c.fillPath()
}

func trees(_ c: CGContext, fill: CGColor) {
    var seed: UInt64 = 42
    func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
    c.setFillColor(fill)
    for _ in 0..<38 {
        let x = next() * CGFloat(W), height = 160 + next() * 220
        c.fillEllipse(in: CGRect(x: x - height * 0.25, y: 330, width: height * 0.5, height: height))
    }
}

png("sky.png") { c in
    c.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [color(0xF4B26C), color(0xA5607E), color(0x1B2350)] as CFArray, locations: [0, 0.45, 1])!,
                         start: CGPoint(x: 0, y: 420), end: CGPoint(x: 0, y: H), options: [.drawsBeforeStartLocation])
}
png("sun.png") { c in c.setFillColor(color(0xFFE6B8)); c.fillEllipse(in: CGRect(x: 1180, y: 520, width: 190, height: 190)) }
png("mountains.png") { ridge($0, base: 560, amplitude: 260, frequency: 6.5, fill: color(0x5F5A8A)) }
png("hills.png") { ridge($0, base: 430, amplitude: 160, frequency: 3.2, fill: color(0x3D3D6E)) }
png("forest.png") { trees($0, fill: color(0x1E2A3A)) }
png("forest-mask.png", gray: true) { trees($0, fill: CGColor(gray: 1, alpha: 1)) }
png("lake.png") { c in
    c.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [color(0x141A38), color(0x4B4A7E)] as CFArray, locations: [0, 1])!,
                         start: .zero, end: CGPoint(x: 0, y: 360), options: [])
    c.clear(CGRect(x: 0, y: 360, width: W, height: H - 360))
}
png("lake-mask.png", gray: true) { c in c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: W, height: 360)) }
png("shore.png") { ridge($0, base: 70, amplitude: 60, frequency: 9, fill: color(0x0B0F1E)) }

let scene = """
{
  "version": 2,
  "particles": 900,
  "particleStyle": "dust",
  "grade": { "brightness": 1.03, "contrast": 1.04, "saturation": 1.08 },
  "layers": [
    { "image": "sky.png" },
    { "image": "sun.png", "depth": 0.05, "glow": 0.7 },
    { "image": "mountains.png", "depth": 0.15, "blur": 0.25 },
    { "image": "hills.png", "depth": 0.3 },
    { "image": "forest.png", "depth": 0.5, "effect": "sway", "mask": "forest-mask.png" },
    { "image": "lake.png", "depth": 0.6, "effect": "ripple", "mask": "lake-mask.png" },
    { "image": "shore.png", "depth": 0.9 }
  ]
}
"""
try Data(scene.utf8).write(to: out.appending(path: "scene.json"))
print("Wrote Dusk Lake to \(out.path)")
