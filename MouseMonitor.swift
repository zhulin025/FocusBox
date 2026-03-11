import AppKit
import Foundation

class MouseMonitor: OverlayWindowMouseDelegate {
    private weak var overlayWindow: OverlayWindow?
    private weak var delegate: MouseMonitorDelegate?
    private var isDragging = false
    private var startPoint: NSPoint = .zero
    private let logFile: URL
    var isEnabled: Bool = true
    
    // CGEventTap 相关
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false
    
    init(overlayWindow: OverlayWindow, delegate: MouseMonitorDelegate?) {
        self.overlayWindow = overlayWindow
        self.delegate = delegate
        self.logFile = URL(fileURLWithPath: "/tmp/focusbox.log")
        log("🚀 MouseMonitor 初始化")
        
        // 设置鼠标事件代理
        overlayWindow.mouseDelegate = self
        
        // 启动全局事件监听
        startGlobalEventMonitoring()
    }
    
    deinit {
        stopGlobalEventMonitoring()
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        log("🔌 MouseMonitor 已\(enabled ? "启用" : "禁用")")
        
        // 启用/禁用全局事件监听
        if enabled {
            startGlobalEventMonitoring()
        } else {
            stopGlobalEventMonitoring()
        }
    }
    
    // MARK: - 全局事件监听（使用 CGEventTap）
    
    private func startGlobalEventMonitoring() {
        guard !isMonitoring else { return }
        
        // 定义要监听的事件类型
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                     (1 << CGEventType.leftMouseDragged.rawValue) |
                                     (1 << CGEventType.leftMouseUp.rawValue)
        
        // 创建事件监听器（放在事件流的最前端，可以控制事件是否传递）
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let monitor = Unmanaged<MouseMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleCGEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log("❌ 无法创建 CGEventTap，请检查辅助功能权限")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // 启用事件监听
        CGEvent.tapEnable(tap: tap, enable: true)
        isMonitoring = true
        
        log("✅ 全局事件监听已启动")
    }
    
    private func stopGlobalEventMonitoring() {
        guard isMonitoring else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        
        log("⏹️ 全局事件监听已停止")
    }
    
    /// 处理 CGEvent 事件
    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            // 禁用时，让所有事件穿透
            return Unmanaged.passRetained(event)
        }
        
        // 将 CGEvent 转换为 NSPoint
        let location = event.location
        
        switch type {
        case .leftMouseDown:
            handleMouseDown(location)
            // 捕获事件，不传递到下层应用
            return nil
            
        case .leftMouseDragged:
            handleMouseDragged(location)
            // 只在拖动时捕获事件
            return isDragging ? nil : Unmanaged.passRetained(event)
            
        case .leftMouseUp:
            handleMouseUp(location)
            // 鼠标松开后，让事件穿透（这样下层应用可以接收 click 事件）
            // 但延迟一小段时间，确保我们的处理先完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.isDragging = false
            }
            return Unmanaged.passRetained(event)
            
        default:
            return Unmanaged.passRetained(event)
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
