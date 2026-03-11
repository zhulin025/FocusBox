import AppKit

class OverlayWindow: NSWindow {
    private var overlayView: OverlayView?
    weak var mouseDelegate: OverlayWindowMouseDelegate?
    private var isMonitoring = false
    private var isDrawing = false  // 标记是否正在绘制
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStore: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStore, defer: flag)
        setup()
    }
    
    init() {
        print("🚀 OverlayWindow init 被调用")
        
        // 获取主屏幕的尺寸
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        print("📐 屏幕尺寸：\(screenRect)")
        
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        print("✅ OverlayWindow 初始化完成")
        setup()
    }
    
    private func setup() {
        print("🔧 OverlayWindow setup 被调用")
        
        guard let screen = NSScreen.main else { return }
        
        // 确保窗口覆盖整个屏幕
        setFrame(screen.frame, display: true)
        
        // 设置为透明、无标题栏、浮动窗口
        isOpaque = false
        backgroundColor = NSColor.clear
        level = .screenSaver  // 高于普通窗口
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hasShadow = false
        ignoresMouseEvents = true  // 默认让鼠标事件穿透到下层应用，只在绘制时临时捕获
        
        // 创建 overlay 视图
        overlayView = OverlayView(frame: screen.frame)
        overlayView?.overlayWindow = self
        contentView = overlayView
        
        print("📐 OverlayWindow 尺寸：\(frame)")
        print("📐 屏幕尺寸：\(screen.frame)")
        print("🪟 OverlayWindow 层级：\(level)")
        
        // 显示窗口
        orderFrontRegardless()
        print("✅ OverlayWindow 已显示")
    }
    
    func drawRect(_ rect: NSRect, color: NSColor = NSColor.systemBlue, borderWidth: CGFloat = 4.0, theme: ColorTheme = .rainbow) {
        guard NSScreen.main != nil else {
            print("⚠️ 没有主屏幕")
            return
        }
        
        // 将全局坐标转换为窗口坐标
        let windowRect = NSRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        print("🎨 绘制矩形 - 输入：\(rect), 窗口：\(windowRect), 边框：\(borderWidth)px, 主题：\(theme.rawValue)")
        overlayView?.startRect = windowRect
        overlayView?.boxColor = color
        overlayView?.borderWidth = borderWidth
        overlayView?.colorTheme = theme
        overlayView?.gradientColors = []  // 清空渐变，生成新颜色
        overlayView?.needsDisplay = true
    }
    
    func hideRect(delay: TimeInterval = 1.0) {
        overlayView?.hide(delay: delay)
    }
    
    // MARK: - 鼠标事件处理
    
    /// 开始捕获鼠标事件（绘制时调用）
    func startCapturingMouseEvents() {
        isDrawing = true
        ignoresMouseEvents = false
        print("🖱️ 开始捕获鼠标事件")
    }
    
    /// 停止捕获鼠标事件（绘制完成后调用，释放控制权）
    func stopCapturingMouseEvents() {
        isDrawing = false
        ignoresMouseEvents = true
        print("🖱️ 停止捕获鼠标事件，释放控制权")
    }
    
    override func sendEvent(_ event: NSEvent) {
        // 将事件传递给 overlayView 处理
        super.sendEvent(event)
    }
}

// 鼠标事件代理协议
protocol OverlayWindowMouseDelegate: AnyObject {
    func handleMouseDown(_ point: NSPoint)
    func handleMouseDragged(_ point: NSPoint)
    func handleMouseUp(_ point: NSPoint)
    var isEnabled: Bool { get }
}

class OverlayView: NSView {
    var startRect: NSRect = .zero
    var boxColor: NSColor = NSColor.systemBlue
    var borderWidth: CGFloat = 4.0
    var colorTheme: ColorTheme = .rainbow
    var gradientColors: [NSColor] = []
    private var fadeTimer: Timer?
    private var boxAlpha: CGFloat = 1.0
    var overlayWindow: OverlayWindow?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 鼠标事件处理
    
    override func mouseDown(with event: NSEvent) {
        guard let delegate = overlayWindow?.mouseDelegate, delegate.isEnabled else { return }
        // 开始捕获鼠标事件
        overlayWindow?.startCapturingMouseEvents()
        let location = convert(event.locationInWindow, from: nil)
        delegate.handleMouseDown(location)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let delegate = overlayWindow?.mouseDelegate, delegate.isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        delegate.handleMouseDragged(location)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let delegate = overlayWindow?.mouseDelegate, delegate.isEnabled else { return }
        let location = convert(event.locationInWindow, from: nil)
        delegate.handleMouseUp(location)
        // 鼠标松开后延迟释放控制权（等待绘制完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.overlayWindow?.stopCapturingMouseEvents()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard startRect.width > 0 && startRect.height > 0 else { return }
        
        // 使用主题颜色生成渐变
        if gradientColors.isEmpty {
            gradientColors = colorTheme.colors
        }
        
        // 绘制渐变边框
        let path = NSBezierPath(rect: startRect)
        path.lineWidth = borderWidth
        
        // 使用渐变描边
        drawGradientStroke(path: path, colors: gradientColors, alpha: alphaValue, lineWidth: borderWidth)
        
        // 绘制半透明填充
        let fillPath = NSBezierPath(rect: startRect)
        boxColor.withAlphaComponent(alphaValue * 0.15).setFill()
        fillPath.fill()
    }
    
    /// 生成随机渐变颜色
    private func generateRandomGradient(baseColor: NSColor) -> [NSColor] {
        // 随机选择色系
        let hue = CGFloat.random(in: 0...1)
        let saturation: CGFloat = CGFloat.random(in: 0.7...1.0)
        let brightness: CGFloat = CGFloat.random(in: 0.8...1.0)
        
        let color1 = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        let color2 = NSColor(hue: (hue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: saturation, brightness: brightness, alpha: 1.0)
        let color3 = NSColor(hue: (hue + 0.6).truncatingRemainder(dividingBy: 1.0), saturation: saturation, brightness: brightness, alpha: 1.0)
        
        return [color1, color2, color3]
    }
    
    /// 绘制渐变边框
    private func drawGradientStroke(path: NSBezierPath, colors: [NSColor], alpha: CGFloat, lineWidth: CGFloat) {
        guard colors.count >= 2, let context = NSGraphicsContext.current?.cgContext else {
            colors.first?.withAlphaComponent(alpha).setStroke()
            path.lineWidth = lineWidth
            path.stroke()
            return
        }
        
        let rect = path.bounds
        
        // 保存图形状态
        context.saveGState()
        
        // 创建渐变
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColors = colors.map { $0.withAlphaComponent(alpha).cgColor }
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        // 设置裁剪区域为边框
        let outerPath = NSBezierPath(rect: rect)
        let innerPath = NSBezierPath(rect: rect.insetBy(dx: lineWidth, dy: lineWidth))
        
        outerPath.append(innerPath)
        outerPath.windingRule = .evenOdd
        outerPath.setClip()
        
        // 绘制渐变（对角线方向）
        let startPoint = CGPoint(x: rect.minX, y: rect.minY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        
        context.restoreGState()
    }
    
    func hide(delay: TimeInterval = 1.0) {
        // 指定延迟后开始淡出动画
        fadeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }
    
    private func fadeOut() {
        let fadeDuration: TimeInterval = 0.5
        let fadeInterval: TimeInterval = 0.05
        let steps = Int(fadeDuration / fadeInterval)
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            self.alphaValue = 1.0 - (CGFloat(currentStep) / CGFloat(steps))
            self.needsDisplay = true
            
            if currentStep >= steps {
                timer.invalidate()
                self.startRect = .zero
                self.alphaValue = 1.0
                self.needsDisplay = true
            }
        }
    }
}
