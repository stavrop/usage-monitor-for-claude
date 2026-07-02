// Renders the app icon (1024x1024 PNG) with CoreGraphics — an original "usage
// gauge" mark in Claude's warm clay orange. Run:  swift tools/make_icon.swift <out.png>
import AppKit

let size = 1024
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "icon_1024.png"

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

let W = CGFloat(size)

// --- Background: warm clay-orange vertical gradient ---
let bg = CGGradient(colorsSpace: cs,
                    colors: [rgb(0xE0, 0x8A, 0x63), rgb(0xC2, 0x5A, 0x35)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: W), end: CGPoint(x: 0, y: 0),
                       options: [])

// Subtle top highlight for depth
let glow = CGGradient(colorsSpace: cs,
                      colors: [rgb(255, 255, 255, 0.18), rgb(255, 255, 255, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: W*0.5, y: W*0.72), startRadius: 0,
                       endCenter: CGPoint(x: W*0.5, y: W*0.72), endRadius: W*0.6,
                       options: [])

// --- Gauge geometry ---
let cx = W * 0.5
let cy = W * 0.46
let radius = W * 0.30
let lineW = W * 0.085
let ivory = rgb(0xFB, 0xF7, 0xEF)

func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

let startA = deg(218)     // lower-left
let endA = deg(-38)       // lower-right  (sweep ~256° clockwise over the top)
let sweep = (218 - (-38)) // 256
let pct: CGFloat = 0.67
let progEnd = deg(218 - pct * CGFloat(sweep))

// Track
ctx.setLineCap(.round)
ctx.setLineWidth(lineW)
ctx.setStrokeColor(rgb(255, 255, 255, 0.26))
ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
           startAngle: startA, endAngle: endA, clockwise: true)
ctx.strokePath()

// Progress (67%)
ctx.setStrokeColor(ivory)
ctx.setLineWidth(lineW)
ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
           startAngle: startA, endAngle: progEnd, clockwise: true)
ctx.strokePath()

// Tick dots just inside the arc
let dotR = W * 0.012
let dotRadius = radius - lineW * 0.9
let ticks = 9
for i in 0...ticks {
    let a = deg(218 - CGFloat(i) / CGFloat(ticks) * CGFloat(sweep))
    let px = cx + dotRadius * cos(a)
    let py = cy + dotRadius * sin(a)
    ctx.setFillColor(rgb(255, 255, 255, 0.55))
    ctx.fillEllipse(in: CGRect(x: px - dotR, y: py - dotR, width: dotR*2, height: dotR*2))
}

// --- Needle pointing to the 67% mark ---
let needleA = progEnd
let needleLen = radius - lineW * 0.2
let tip = CGPoint(x: cx + needleLen * cos(needleA), y: cy + needleLen * sin(needleA))
// base perpendicular for a tapered needle
let baseW = W * 0.035
let perp = needleA + .pi/2
let b1 = CGPoint(x: cx + baseW * cos(perp), y: cy + baseW * sin(perp))
let b2 = CGPoint(x: cx - baseW * cos(perp), y: cy - baseW * sin(perp))
// short counterweight tail
let tailLen = W * 0.05
let tail = CGPoint(x: cx - tailLen * cos(needleA), y: cy - tailLen * sin(needleA))

ctx.setFillColor(ivory)
ctx.beginPath()
ctx.move(to: tip)
ctx.addLine(to: b1)
ctx.addLine(to: tail)
ctx.addLine(to: b2)
ctx.closePath()
ctx.fillPath()

// Hub
let hubR = W * 0.055
ctx.setFillColor(ivory)
ctx.fillEllipse(in: CGRect(x: cx - hubR, y: cy - hubR, width: hubR*2, height: hubR*2))
ctx.setFillColor(rgb(0xC2, 0x5A, 0x35))
let hubInner = hubR * 0.45
ctx.fillEllipse(in: CGRect(x: cx - hubInner, y: cy - hubInner, width: hubInner*2, height: hubInner*2))

// --- "%" mark below the gauge to denote usage ---
let pctText = "%" as NSString
let para = NSMutableParagraphStyle(); para.alignment = .center
let font = NSFont.systemFont(ofSize: W*0.18, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(cgColor: ivory)!,
    .paragraphStyle: para,
]
// Draw text via NSGraphicsContext bridged to our CGContext
let prev = NSGraphicsContext.current
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let textSize = pctText.size(withAttributes: attrs)
pctText.draw(at: CGPoint(x: cx - textSize.width/2, y: W*0.115),
             withAttributes: attrs)
NSGraphicsContext.current = prev

// --- Write PNG ---
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(size)x\(size))")
