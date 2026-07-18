import AppKit
import Foundation

// 用法: swift tools/IconGenerator.swift [输出iconset目录]
// 绘制 macOS 风格图标：蓝色渐变圆角底板 + 白色文档（折角+文字行）+ 橙色铅笔（标注主题）

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func drawIcon(_ s: CGFloat) {
    // ---- 底板：圆角矩形 + 蓝色纵向渐变 ----
    let inset = s * 0.095
    let iconRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let plate = NSBezierPath(roundedRect: iconRect, xRadius: s * 0.185, yRadius: s * 0.185)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.44, green: 0.79, blue: 1.00, alpha: 1),  // 顶部亮蓝
        NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.98, alpha: 1),  // 底部深蓝
    ])!
    gradient.draw(in: plate, angle: -90)

    // ---- 文档 ----
    let docW = s * 0.46
    let docH = s * 0.58
    let docX = (s - docW) / 2
    let docY = (s - docH) / 2 - s * 0.01
    let docRect = CGRect(x: docX, y: docY, width: docW, height: docH)
    let docPath = NSBezierPath(roundedRect: docRect, xRadius: s * 0.04, yRadius: s * 0.04)

    // 投影
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = s * 0.022
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.010)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    docPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // 折角（右上角）
    let fold = s * 0.115
    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: docX + docW - fold, y: docY))
    foldPath.line(to: NSPoint(x: docX + docW, y: docY))
    foldPath.line(to: NSPoint(x: docX + docW, y: docY + fold))
    foldPath.close()
    NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.97, alpha: 1).setFill()
    foldPath.fill()

    // 文字行
    let lineColor = NSColor(calibratedRed: 0.58, green: 0.76, blue: 0.91, alpha: 1)
    lineColor.setFill()
    let lineH = s * 0.036
    let lineX = docX + s * 0.075
    let lineWidths: [CGFloat] = [docW - s * 0.15, (docW - s * 0.15) * 0.78, (docW - s * 0.15) * 0.56]
    for (i, w) in lineWidths.enumerated() {
        let y = docY + s * 0.135 + CGFloat(i) * s * 0.085
        NSBezierPath(roundedRect: CGRect(x: lineX, y: y, width: w, height: lineH),
                     xRadius: lineH / 2, yRadius: lineH / 2).fill()
    }

    // ---- 铅笔（斜放在文档右下）----
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.translateBy(x: docX + docW * 0.72, y: docY + docH * 0.64)
    context.rotate(by: -CGFloat.pi / 4)  // 笔尖朝左下

    let penL = s * 0.21
    let penT = s * 0.050
    let tipL = s * 0.055

    // 笔杆
    NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.05, alpha: 1).setFill()
    NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: penL, height: penT),
                 xRadius: penT * 0.25, yRadius: penT * 0.25).fill()
    // 笔杆高光
    NSColor.white.withAlphaComponent(0.35).setFill()
    NSBezierPath(roundedRect: CGRect(x: penT * 0.2, y: penT * 0.58, width: penL - penT * 0.4, height: penT * 0.22),
                 xRadius: penT * 0.1, yRadius: penT * 0.1).fill()
    // 木质笔尖
    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: -tipL, y: penT / 2))
    tip.line(to: NSPoint(x: 0, y: 0))
    tip.line(to: NSPoint(x: 0, y: penT))
    tip.close()
    NSColor(calibratedRed: 1.00, green: 0.87, blue: 0.62, alpha: 1).setFill()
    tip.fill()
    // 笔芯
    let lead = NSBezierPath()
    lead.move(to: NSPoint(x: -tipL, y: penT / 2))
    lead.line(to: NSPoint(x: -tipL * 0.45, y: penT * 0.30))
    lead.line(to: NSPoint(x: -tipL * 0.45, y: penT * 0.70))
    lead.close()
    NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.30, alpha: 1).setFill()
    lead.fill()

    context.restoreGState()
}

for (name, px) in sizes {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("无法创建位图") }

    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    // 翻转为左上角原点，方便按视觉坐标绘制
    gc.cgContext.translateBy(x: 0, y: CGFloat(px))
    gc.cgContext.scaleBy(x: 1, y: -1)
    drawIcon(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

print("iconset 已生成: \(outDir)")
