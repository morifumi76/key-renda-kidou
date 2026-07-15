import AppKit

// key-renda-kidou のアプリアイコンを描画して PNG（1024x1024）を出力するスクリプト
// 使い方: swift scripts/make-icon.swift <出力先.png>

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/icon-1024.png"

let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("描画コンテキストを取得できませんでした")
}

// --- 背景（macOSアイコン標準の余白付き角丸スクエア） ---
let margin: CGFloat = 100
let bgRect = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let cornerRadius: CGFloat = 185

ctx.saveGState()
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

// 青のグラデーション（左上が明るい）
let gradientColors = [
    NSColor(calibratedRed: 0.25, green: 0.52, blue: 1.00, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.65, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: bgRect.minX, y: bgRect.maxY),
    end: CGPoint(x: bgRect.maxX, y: bgRect.minY),
    options: []
)
ctx.restoreGState()

// --- キーキャップ（白・少し下に側面を見せて立体感を出す） ---
let capSize: CGFloat = 470
let capX = (size - capSize) / 2
let capY = (size - capSize) / 2 - 40
let capCorner: CGFloat = 90

// 側面（下の暗い部分）
ctx.saveGState()
let sideRect = CGRect(x: capX, y: capY - 34, width: capSize, height: capSize)
ctx.addPath(CGPath(roundedRect: sideRect, cornerWidth: capCorner, cornerHeight: capCorner, transform: nil))
ctx.setFillColor(NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.92, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()

// 上面（白、ほんのり影）
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
let faceRect = CGRect(x: capX, y: capY, width: capSize, height: capSize)
ctx.addPath(CGPath(roundedRect: faceRect, cornerWidth: capCorner, cornerHeight: capCorner, transform: nil))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

// --- キーキャップの上に稲妻（起動の象徴、SF Symbol） ---
if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 300, weight: .semibold)
    let symbol = bolt.withSymbolConfiguration(config) ?? bolt
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.90, alpha: 1).set()
    let r = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    // キーキャップ上面の中央に描画
    let boltHeight: CGFloat = 300
    let aspect = symbol.size.width / symbol.size.height
    let boltWidth = boltHeight * aspect
    let boltRect = NSRect(
        x: faceRect.midX - boltWidth / 2,
        y: faceRect.midY - boltHeight / 2,
        width: boltWidth,
        height: boltHeight
    )
    tinted.draw(in: boltRect)
}

// --- 連打（ノック）の波紋アーク（右上に2本、背景の内側に収める） ---
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineCap(.round)
let waveCenter = CGPoint(x: faceRect.maxX - 30, y: faceRect.maxY - 30)
let startAngle: CGFloat = .pi * 0.06
let endAngle: CGFloat = .pi * 0.44

ctx.setLineWidth(28)
ctx.addArc(center: waveCenter, radius: 105, startAngle: startAngle, endAngle: endAngle, clockwise: false)
ctx.strokePath()

ctx.setLineWidth(28)
ctx.addArc(center: waveCenter, radius: 175, startAngle: startAngle, endAngle: endAngle, clockwise: false)
ctx.strokePath()
ctx.restoreGState()

image.unlockFocus()

// --- PNG書き出し ---
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNGへの変換に失敗しました")
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("✅ 出力: \(outputPath)")
