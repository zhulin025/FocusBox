#!/usr/bin/env swift

import AppKit

// 创建图标
let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)

image.lockFocus()

// 背景渐变
let gradient = NSGradient(starting: NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
                          ending: NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0))
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)

// 圆角矩形边框
let borderPath = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 432, height: 432),
                               xRadius: 100, yRadius: 100)
borderPath.lineWidth = 20
NSColor.white.withAlphaComponent(0.9).setStroke()
borderPath.stroke()

// 内部虚线矩形（FocusBox 的焦点框）
let dashPath = NSBezierPath(roundedRect: NSRect(x: 120, y: 120, width: 272, height: 272),
                             xRadius: 40, yRadius: 40)
dashPath.lineWidth = 16
dashPath.setLineDash([12, 8], count: 2, phase: 0)
NSColor.white.withAlphaComponent(0.7).setStroke()
dashPath.stroke()

// 四个角的装饰（表示焦点）
let corners: [NSPoint] = [
    NSPoint(x: 100, y: 100),
    NSPoint(x: 412, y: 100),
    NSPoint(x: 100, y: 412),
    NSPoint(x: 412, y: 412)
]

for corner in corners {
    let dotPath = NSBezierPath(ovalIn: NSRect(x: corner.x - 16, y: corner.y - 16, width: 32, height: 32))
    NSColor.white.setFill()
    dotPath.fill()
}

image.unlockFocus()

// 保存为 PNG
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "/Users/zhulin/clawd/projects/FocusBox/icon.png")
    try? pngData.write(to: url)
    print("✅ 图标已保存：icon.png")
}
