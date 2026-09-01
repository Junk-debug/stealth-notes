import AppKit
import CoreImage

let canvas: CGFloat = 1024
// macOS icon grid: the squircle occupies ~824pt of a 1024 canvas.
let margin: CGFloat = 100
let iconRect = CGRect(x: margin, y: margin, width: canvas - 2 * margin, height: canvas - 2 * margin)
let cornerRadius: CGFloat = 186

func makeBitmap() -> NSBitmapImageRep {
    NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
}

func draw(into rep: NSBitmapImageRep, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
}

let squircle = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

// ---- Pass 0: background only (crisp squircle, no card) ----
let bgRep = makeBitmap()
draw(into: bgRep) {
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSGradient(
        starting: NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.42, alpha: 1),
        ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.22, alpha: 1)
    )!.draw(in: iconRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSColor.white.withAlphaComponent(0.07).setStroke()
    let rim = NSBezierPath(roundedRect: iconRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
    rim.lineWidth = 4
    rim.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
}

// ---- Pass 1: base artwork (dark squircle + note card + text lines) ----
let baseRep = makeBitmap()
draw(into: baseRep) {
    // Base squircle: charcoal-navy vertical gradient.
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSGradient(
        starting: NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.42, alpha: 1),
        ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.22, alpha: 1)
    )!.draw(in: iconRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Subtle inner top highlight on the squircle rim.
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSColor.white.withAlphaComponent(0.07).setStroke()
    let rim = NSBezierPath(roundedRect: iconRect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
    rim.lineWidth = 4
    rim.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Note card with soft shadow.
    let cardRect = CGRect(x: (canvas - 450) / 2, y: (canvas - 530) / 2, width: 450, height: 530)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: 72, yRadius: 72)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 46
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set()
    NSColor.white.setFill()
    card.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Card face gradient (paper).
    NSGraphicsContext.current?.saveGraphicsState()
    card.addClip()
    NSGradient(
        starting: NSColor(calibratedWhite: 0.99, alpha: 1),
        ending: NSColor(calibratedWhite: 0.88, alpha: 1)
    )!.draw(in: cardRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Three text lines.
    let lineColor = NSColor(calibratedRed: 0.60, green: 0.64, blue: 0.80, alpha: 1)
    lineColor.setFill()
    let lineHeight: CGFloat = 40
    let lineWidths: [CGFloat] = [270, 270, 230]
    let startY = cardRect.midY + 92
    for (i, w) in lineWidths.enumerated() {
        let y = startY - CGFloat(i) * 112 - lineHeight / 2
        let r = CGRect(x: cardRect.minX + 88, y: y, width: w, height: lineHeight)
        NSBezierPath(roundedRect: r, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
    }
}

// ---- Pass 2: blurred copy for the frosted glass ----
let ciBase = CIImage(bitmapImageRep: baseRep)!
let blurFilter = CIFilter(name: "CIGaussianBlur")!
blurFilter.setValue(ciBase, forKey: kCIInputImageKey)
blurFilter.setValue(18.0, forKey: kCIInputRadiusKey)
let blurred = blurFilter.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas))
let ciContext = CIContext()
let blurredCG = ciContext.createCGImage(blurred, from: blurred.extent)!

// ---- Pass 3: composite ----
let finalRep = makeBitmap()
draw(into: finalRep) {
    let ctx = NSGraphicsContext.current!.cgContext
    let fullBlur = CommandLine.arguments.contains("full")

    // Sharp layer: full artwork in half mode; in full mode only the crisp background
    // (the card goes entirely behind glass, but the squircle edge must stay sharp).
    let sharpSource = fullBlur ? CIImage(bitmapImageRep: bgRep)! : ciBase
    ctx.draw(CIContext().createCGImage(sharpSource, from: sharpSource.extent)!, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

    // Frosted glass: right half of the squircle, or the entire squircle in "full" mode.
    let glassRect = fullBlur
        ? iconRect
        : CGRect(x: canvas / 2, y: iconRect.minY, width: iconRect.maxX - canvas / 2, height: iconRect.height)
    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSBezierPath(rect: glassRect).addClip()

    // Blurred content under the glass.
    ctx.draw(blurredCG, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

    // Frost tint: cool gray-blue, lighter toward the top.
    NSGradient(
        starting: NSColor(calibratedRed: 0.60, green: 0.64, blue: 0.96, alpha: 0.38),
        ending: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.78, alpha: 0.30)
    )!.draw(in: iconRect, angle: -90)

    NSGraphicsContext.current?.restoreGraphicsState()

    // Crisp edge where the glass begins (half mode only).
    if !fullBlur {
        NSGraphicsContext.current?.saveGraphicsState()
        squircle.addClip()
        NSColor(calibratedRed: 0.80, green: 0.85, blue: 1.0, alpha: 0.35).setFill()
        NSBezierPath(rect: CGRect(x: canvas / 2 - 2, y: iconRect.minY, width: 3, height: iconRect.height)).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

let outURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png")
try! finalRep.representation(using: .png, properties: [:])!.write(to: outURL)
print("written: \(outURL.path)")
