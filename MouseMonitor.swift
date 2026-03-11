import AppKit
import Foundation

class MouseMonitor: OverlayWindowMouseDelegate {
    private weak var overlayWindow: OverlayWindow?
    private weak var delegate: MouseMonitorDelegate?
    private var isDragging = false
    private var startPoint: NSPoint = .zero
    private let logFile: URL
    var isEnabled: Bool = true
    
    init(overlayWindow: OverlayWindow, delegate: MouseMonitorDelegate?) {
        self.overlayWindow = overlayWindow
        self.delegate = delegate
        self.logFile = URL(fileURLWithPath: "/tmp/focusbox.log")
        log("🚀 MouseMonitor 初始化")
        
        // 设置鼠标事件代理
        overlayWindow.mouseDelegate = self
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        log("🔌 MouseMonitor 已\(enabled ? "启用" : "禁用")")
        
        // 启用/禁用覆盖层窗口的鼠标捕获
        if enabled {
            overlayWindow?.orderFrontRegardless()
        } else {
            overlayWindow?.orderOut(nil)
        }
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? line.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
        print(line.trimmingCharacters(in: .newlines))
    }
    
    // MARK: - OverlayWindowMouseDelegate 实现
    
    func handleMouseDown(_ point: NSPoint) {
        guard isEnabled else {
            log("⚠️ 跳过：MouseMonitor 已禁用")
            return
        }
        
        log("⬇️ handleMouseDown 被调用，位置：\(point)")
        isDragging = true
        startPoint = point
        log("📍 起点：\(startPoint)")
        
        // 通知 overlayWindow 开始捕获事件
        overlayWindow?.startCapturingMouseEvents()
    }
    
    func handleMouseDragged(_ point: NSPoint) {
        log("➡️ handleMouseDragged 被调用，isDragging=\(isDragging), 位置：\(point)")
        guard isDragging, let overlay = overlayWindow, let delegate = delegate else {
            log("⚠️ 跳过绘制：isDragging=\(isDragging)")
            return
        }
        
        let rect = rectFromPoints(startPoint, point)
        
        log("📐 矩形：\(rect)")
        
        // 只在矩形大小变化时重绘（性能优化）
        if rect.width > 10 && rect.height > 10 {
            log("🎨 绘制矩形...")
            overlay.drawRect(rect, borderWidth: delegate.borderWidth, theme: delegate.colorTheme)
        }
    }
    
    func handleMouseUp(_ point: NSPoint) {
        log("⬆️ handleMouseUp 被调用，位置：\(point)")
        guard isDragging, let overlay = overlayWindow, let delegate = delegate else { return }
        
        isDragging = false
        let rect = rectFromPoints(startPoint, point)
        
        log("📐 最终矩形：\(rect)")
        
        // 只有足够大的矩形才显示
        if rect.width > 10 && rect.height > 10 {
            log("🎨 绘制并准备隐藏...")
            overlay.drawRect(rect, borderWidth: delegate.borderWidth, theme: delegate.colorTheme)
            // 使用用户设置的延迟后自动隐藏
            overlay.hideRect(delay: delegate.fadeDelay)
        }
        
        // 通知 overlayWindow 停止捕获事件
        overlayWindow?.stopCapturingMouseEvents()
    }
    
    /// 根据两个点计算矩形（处理从右下到左上的拖动）
    private func rectFromPoints(_ p1: NSPoint, _ p2: NSPoint) -> NSRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let width = abs(p2.x - p1.x)
        let height = abs(p2.y - p1.y)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
