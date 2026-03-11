import AppKit
import Foundation

class MouseMonitor {
    private weak var overlayWindow: OverlayWindow?
    private weak var delegate: MouseMonitorDelegate?
    private var isDragging = false
    private var startPoint: NSPoint = .zero
    private var leftMouseDownMonitor: Any?
    private var leftMouseUpMonitor: Any?
    private var leftMouseDraggedMonitor: Any?
    private let logFile: URL
    var isEnabled: Bool = true
    
    init(overlayWindow: OverlayWindow, delegate: MouseMonitorDelegate?) {
        self.overlayWindow = overlayWindow
        self.delegate = delegate
        self.logFile = URL(fileURLWithPath: "/tmp/focusbox.log")
        log("🚀 MouseMonitor 初始化")
        setupEventMonitors()
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        log("🔌 MouseMonitor 已\(enabled ? "启用" : "禁用")")
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
    
    deinit {
        if let monitor = leftMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = leftMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = leftMouseDraggedMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupEventMonitors() {
        log("📡 注册全局鼠标监听器...")
        
        // 监听全局鼠标按下事件
        leftMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.log("🖱️ 收到 leftMouseDown 事件")
            self?.handleMouseDown(event)
        }
        log("✅ leftMouseDown 监听器已注册")
        
        // 监听全局鼠标拖动事件
        leftMouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.log("🖱️ 收到 leftMouseDragged 事件")
            self?.handleMouseDragged(event)
        }
        log("✅ leftMouseDragged 监听器已注册")
        
        // 监听全局鼠标释放事件
        leftMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.log("🖱️ 收到 leftMouseUp 事件")
            self?.handleMouseUp(event)
        }
        log("✅ leftMouseUp 监听器已注册")
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        guard isEnabled else {
            log("⚠️ 跳过：MouseMonitor 已禁用")
            return
        }
        
        log("⬇️ handleMouseDown 被调用")
        isDragging = true
        startPoint = NSEvent.mouseLocation
        log("📍 起点：\(startPoint)")
    }
    
    private func handleMouseDragged(_ event: NSEvent) {
        log("➡️ handleMouseDragged 被调用，isDragging=\(isDragging)")
        guard isDragging, let overlay = overlayWindow, let delegate = delegate else {
            log("⚠️ 跳过绘制：isDragging=\(isDragging), overlay=\(overlayWindow != nil ? "存在" : "nil")")
            return
        }
        
        let currentLocation = NSEvent.mouseLocation
        let rect = rectFromPoints(startPoint, currentLocation)
        
        log("📐 矩形：\(rect)")
        
        // 只在矩形大小变化时重绘（性能优化）
        if rect.width > 10 && rect.height > 10 {
            log("🎨 绘制矩形...")
            overlay.drawRect(rect, borderWidth: delegate.borderWidth, theme: delegate.colorTheme)
        }
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        log("⬆️ handleMouseUp 被调用")
        guard isDragging, let overlay = overlayWindow, let delegate = delegate else { return }
        
        isDragging = false
        let currentLocation = NSEvent.mouseLocation
        let rect = rectFromPoints(startPoint, currentLocation)
        
        log("📐 最终矩形：\(rect)")
        
        // 只有足够大的矩形才显示
        if rect.width > 10 && rect.height > 10 {
            log("🎨 绘制并准备隐藏...")
            overlay.drawRect(rect, borderWidth: delegate.borderWidth, theme: delegate.colorTheme)
            // 使用用户设置的延迟后自动隐藏
            overlay.hideRect(delay: delegate.fadeDelay)
        }
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
