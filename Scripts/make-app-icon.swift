import AppKit
import Foundation

func sgn(_ v: CGFloat) -> CGFloat { v < 0 ? -1 : 1 }

/// Apple-style squircle (superellipse)
func squircle(in rect: CGRect, n: CGFloat = 5.0, steps: Int = 1440) -> CGPath {
    let p = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * sgn(ct) * pow(abs(ct), 2 / n)
        let y = cy + b * sgn(st) * pow(abs(st), 2 / n)
        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
    }
    p.closeSubpath()
    return p
}

struct Palette {
    let stops: [(CGFloat, NSColor)]
}

let palettes: [String: Palette] = [
    "azure": Palette(stops: [
        (0.0, NSColor(srgbRed: 0.42, green: 0.24, blue: 0.90, alpha: 1)),
        (0.45, NSColor(srgbRed: 0.20, green: 0.45, blue: 0.98, alpha: 1)),
        (1.0, NSColor(srgbRed: 0.36, green: 0.75, blue: 1.00, alpha: 1)),
    ]),
    "ocean": Palette(stops: [
        (0.0, NSColor(srgbRed: 0.04, green: 0.20, blue: 0.52, alpha: 1)),
        (0.5, NSColor(srgbRed: 0.08, green: 0.45, blue: 0.85, alpha: 1)),
        (1.0, NSColor(srgbRed: 0.34, green: 0.83, blue: 0.96, alpha: 1)),
    ]),
    "aurora": Palette(stops: [
        (0.0, NSColor(srgbRed: 0.36, green: 0.22, blue: 0.86, alpha: 1)),
        (0.5, NSColor(srgbRed: 0.16, green: 0.56, blue: 0.95, alpha: 1)),
        (1.0, NSColor(srgbRed: 0.32, green: 0.92, blue: 0.84, alpha: 1)),
    ]),
]

func gradient(_ p: Palette) -> CGGradient {
    let colors = p.stops.map { $0.1.cgColor } as CFArray
    let locs = p.stops.map { $0.0 }
    return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs)!
}

/// The "#" glyph as a filled path, built from round-capped strokes in a unit box.
func hashPath(in box: CGRect) -> CGPath {
    let S = box.width
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: box.minX + x * S, y: box.minY + y * S)
    }
    let line = CGMutablePath()
    // horizontals
    line.move(to: pt(0.045, 0.360)); line.addLine(to: pt(0.955, 0.360))
    line.move(to: pt(0.045, 0.640)); line.addLine(to: pt(0.955, 0.640))
    // slanted verticals
    line.move(to: pt(0.310, 0.045)); line.addLine(to: pt(0.420, 0.955))
    line.move(to: pt(0.600, 0.045)); line.addLine(to: pt(0.710, 0.955))
    return line.copy(strokingWithWidth: S * 0.150, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

func render(size: CGFloat, paletteName: String) -> Data {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high

    let pal = palettes[paletteName]!

    // macOS icon grid: art occupies ~80.5% of canvas, nudged up to leave shadow room
    let side = size * 0.8047
    let x = (size - side) / 2
    let y = (size - side) / 2 + size * 0.012
    let art = CGRect(x: x, y: y, width: side, height: side)
    let shape = squircle(in: art)

    // Drop shadow
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -size * 0.018),
                 blur: size * 0.035,
                 color: NSColor(white: 0, alpha: 0.30).cgColor)
    cg.addPath(shape)
    cg.setFillColor(NSColor.black.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Body gradient
    cg.saveGState()
    cg.addPath(shape); cg.clip()
    cg.drawLinearGradient(gradient(pal),
                          start: CGPoint(x: art.midX, y: art.minY),
                          end: CGPoint(x: art.midX, y: art.maxY),
                          options: [])

    // Liquid-glass gloss: bright sweep across the upper third
    let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor(white: 1, alpha: 0.42).cgColor,
                                    NSColor(white: 1, alpha: 0.10).cgColor,
                                    NSColor(white: 1, alpha: 0.0).cgColor] as CFArray,
                           locations: [0.0, 0.55, 1.0])!
    let glossRect = CGRect(x: art.minX - side * 0.15, y: art.midY + side * 0.02,
                           width: side * 1.30, height: side * 0.62)
    cg.saveGState()
    cg.addEllipse(in: glossRect); cg.clip()
    cg.drawLinearGradient(gloss,
                          start: CGPoint(x: art.midX, y: art.maxY),
                          end: CGPoint(x: art.midX, y: art.midY),
                          options: [])
    cg.restoreGState()

    // Subtle inner rim light along the top edge
    cg.setLineWidth(size * 0.006)
    cg.setStrokeColor(NSColor(white: 1, alpha: 0.35).cgColor)
    cg.addPath(shape)
    cg.strokePath()
    cg.restoreGState()

    // The # glyph
    let g = side * 0.520
    let glyphBox = CGRect(x: art.midX - g / 2, y: art.midY - g / 2, width: g, height: g)
    let glyph = hashPath(in: glyphBox)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -size * 0.006),
                 blur: size * 0.018,
                 color: NSColor(srgbRed: 0.02, green: 0.06, blue: 0.25, alpha: 0.35).cgColor)
    cg.addPath(glyph)
    cg.setFillColor(NSColor.white.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Glass tint down the glyph
    cg.saveGState()
    cg.addPath(glyph); cg.clip()
    let glyphGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1).cgColor,
                                        NSColor(srgbRed: 0.88, green: 0.94, blue: 1.0, alpha: 1).cgColor] as CFArray,
                               locations: [0.0, 1.0])!
    cg.drawLinearGradient(glyphGrad,
                          start: CGPoint(x: glyphBox.midX, y: glyphBox.maxY),
                          end: CGPoint(x: glyphBox.midX, y: glyphBox.minY),
                          options: [])
    cg.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// CLI: makeicon <palette> <outdir> <size:filename> ...
let args = CommandLine.arguments
guard args.count >= 4 else { fputs("usage: makeicon <palette> <outdir> size:name...\n", stderr); exit(1) }
let palette = args[1]
let outDir = args[2]
for spec in args.dropFirst(3) {
    let parts = spec.split(separator: ":", maxSplits: 1)
    let size = CGFloat(Int(parts[0])!)
    let name = String(parts[1])
    let data = render(size: size, paletteName: palette)
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("ok")
