// Phase 2 renderer spike benchmark. Puts the test scene on every screen at desktop level, measures it
// against the budgets in docs/ARCHITECTURE.md, prints a report and exits.
// Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release IkigaiSpike [seconds]
import AppKit
import IkigaiRender
import MetalKit
import os

// MARK: Measurements

/// Frame completions from Metal's completion threads: (wall time, GPU seconds).
final class FrameLog: Sendable {
    private let frames = OSAllocatedUnfairLock(initialState: [(Double, Double)]())
    func add(gpu: Double) { let now = CACurrentMediaTime(); frames.withLock { $0.append((now, gpu)) } }
    func drain() -> [(Double, Double)] { frames.withLock { let all = $0; $0.removeAll(); return all } }
}

func cpuSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
}

func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : .nan
}

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return .nan }
    let sorted = values.sorted()
    return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))]
}

// MARK: Test scene (procedural, 2048×1280 per layer)

let W = 2048, H = 1280

func image(_ draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    draw(context)
    return context.makeImage()!
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func ridge(_ c: CGContext, base: CGFloat, amplitude: CGFloat, frequency: CGFloat, fill: CGColor) {
    c.move(to: CGPoint(x: 0, y: 0))
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

@MainActor func makeScene(device: MTLDevice) throws -> [SceneLayer] {
    let loader = MTKTextureLoader(device: device)
    func texture(_ image: CGImage) throws -> MTLTexture { try loader.newTexture(cgImage: image, options: [.SRGB: false]) }

    let sky = image { c in
        c.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [color(0xF4B26C), color(0xA5607E), color(0x1B2350)] as CFArray, locations: [0, 0.45, 1])!,
                             start: CGPoint(x: 0, y: 420), end: CGPoint(x: 0, y: H), options: [.drawsBeforeStartLocation])
        c.setFillColor(color(0xFFE6B8)); c.fillEllipse(in: CGRect(x: 1180, y: 520, width: 190, height: 190))
    }
    let far = image { ridge($0, base: 560, amplitude: 260, frequency: 6.5, fill: color(0x5F5A8A)) }
    let hills = image { ridge($0, base: 430, amplitude: 160, frequency: 3.2, fill: color(0x3D3D6E)) }
    let forest = image { trees($0, fill: color(0x1E2A3A)) }
    let forestMask = image { trees($0, fill: color(0xFFFFFF)) }
    let water = image { c in
        c.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [color(0x141A38), color(0x4B4A7E)] as CFArray, locations: [0, 1])!,
                             start: .zero, end: CGPoint(x: 0, y: 360), options: [])
        c.clear(CGRect(x: 0, y: 360, width: W, height: H - 360))
    }
    let waterMask = image { c in c.setFillColor(color(0xFFFFFF)); c.fill(CGRect(x: 0, y: 0, width: W, height: 360)) }
    let grass = image { ridge($0, base: 70, amplitude: 60, frequency: 9, fill: color(0x0B0F1E)) }

    return [
        SceneLayer(texture: try texture(sky), depth: 0),
        SceneLayer(texture: try texture(far), depth: 0.15),
        SceneLayer(texture: try texture(hills), depth: 0.3),
        SceneLayer(texture: try texture(forest), depth: 0.5, effect: .sway, mask: try texture(forestMask)),
        SceneLayer(texture: try texture(water), depth: 0.6, effect: .ripple, mask: try texture(waterMask)),
        SceneLayer(texture: try texture(grass), depth: 0.9),
    ]
}

// MARK: Benchmark

@MainActor final class Benchmark {
    let playSeconds: Double
    let log = FrameLog()
    var views: [MTKView] = []
    var renderers: [SceneRenderer] = []
    var windows: [NSWindow] = []

    init(playSeconds: Double) { self.playSeconds = playSeconds }

    func run() async {
        guard let device = MTLCreateSystemDefaultDevice() else { print("No Metal device."); return }
        let layers: [SceneLayer]
        do { layers = try makeScene(device: device) } catch { print("Scene failed: \(error)"); return }

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.setFrame(screen.frame, display: false)
            let view = MTKView(frame: CGRect(origin: .zero, size: screen.frame.size))
            guard let renderer = try? SceneRenderer(device: device, layers: layers, particleCount: 2000) else { continue }
            renderer.attach(to: view)
            let log = self.log
            renderer.onFrameCompleted = { log.add(gpu: $0) }
            window.contentView = view
            window.orderFront(nil)
            windows.append(window); views.append(view); renderers.append(renderer)
        }
        let pixels = views.map { "\(Int($0.drawableSize.width))×\(Int($0.drawableSize.height))" }.joined(separator: ", ")

        try? await Task.sleep(for: .seconds(3)); _ = log.drain()  // warm-up: shader and texture upload costs

        let cpu0 = cpuSeconds(), wall0 = CACurrentMediaTime()
        try? await Task.sleep(for: .seconds(playSeconds))
        let playCPU = (cpuSeconds() - cpu0) / (CACurrentMediaTime() - wall0) * 100
        let played = log.drain()
        let memory = footprintMB()

        views.forEach { $0.isPaused = true }
        try? await Task.sleep(for: .milliseconds(300)); _ = log.drain()  // let in-flight frames land
        let cpu1 = cpuSeconds(), wall1 = CACurrentMediaTime()
        try? await Task.sleep(for: .seconds(10))
        let pausedCPU = (cpuSeconds() - cpu1) / (CACurrentMediaTime() - wall1) * 100
        let pausedFrames = log.drain().count

        let resumeAt = CACurrentMediaTime()
        views.forEach { $0.isPaused = false }
        var resume = Double.nan
        for _ in 0..<100 {
            try? await Task.sleep(for: .milliseconds(5))
            if let first = log.drain().first { resume = (first.0 - resumeAt) * 1000; break }
        }

        let gpu = played.map { $0.1 * 1000 }
        let times = played.map(\.0).sorted()
        let perScreenInterval = views.isEmpty ? 0 : 1.0 / 30 / Double(views.count)
        let hitches = zip(times, times.dropFirst()).filter { $1 - $0 > perScreenInterval * 2 * Double(views.count) * 1.5 }.count
        let fps = Double(played.count) / playSeconds / Double(max(views.count, 1))

        func row(_ name: String, _ target: String, _ value: String, _ pass: Bool) -> String {
            "| \(name) | \(target) | \(value) | \(pass ? "PASS" : "FAIL") |"
        }
        let report = [
            "Renderer spike — \(views.count) screen(s): \(pixels); 6 layers, 2 masked effects, 2000 particles, \(Int(playSeconds)) s",
            "",
            "| Check | Target | Measured | Result |",
            "|---|---|---|---|",
            row("Frame rate", "30 fps per screen", String(format: "%.1f fps", fps), fps >= 28),
            row("CPU while playing", "< 3% of one core", String(format: "%.2f%%", playCPU), playCPU < 3),
            row("GPU time per frame", "< 4 ms per 4K screen", String(format: "avg %.2f ms, p95 %.2f ms", gpu.reduce(0, +) / Double(max(gpu.count, 1)), percentile(gpu, 0.95)), percentile(gpu, 0.95) < 4),
            row("Memory", "< 300 MB", String(format: "%.0f MB", memory), memory < 300),
            row("Paused CPU", "~0%", String(format: "%.2f%%", pausedCPU), pausedCPU < 0.5),
            row("Paused GPU work", "no frames", "\(pausedFrames) frames", pausedFrames == 0),
            row("Resume", "first frame < 100 ms", String(format: "%.0f ms", resume), resume < 100),
            row("Hitches", "none > 2 frames", "\(hitches)", hitches == 0),
        ]
        print(report.joined(separator: "\n"))
        windows.forEach { $0.orderOut(nil) }
    }
}

let seconds = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 20
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let benchmark = Benchmark(playSeconds: seconds)
Task {
    await benchmark.run()
    exit(0)
}
app.run()
