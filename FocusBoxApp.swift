import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var mouseMonitor: MouseMonitor?
    private var settingsWindow: NSWindow?
    private var settingsModel: SettingsModel?
    private var screenRecorder: ScreenRecorder?
    
    // 全局快捷键监听
    private var hotKeyMonitor: Any?
    var isEnabled = true
    
    // 用户设置
    var borderWidth: CGFloat = 4.0
    var colorTheme: ColorTheme = .rainbow
    var fadeDelay: TimeInterval = 1.0
    var enableRecording = false  // 是否启用录制功能
    
    // 通知代理
    var notificationCenter: NotificationCenter = .default
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 FocusBox 启动中...")
        
        // 创建状态栏图标
        setupStatusItem()
        print("✅ 状态栏图标已创建")
        
        // 创建覆盖窗口
        overlayWindow = OverlayWindow()
        print("✅ 覆盖窗口已创建")
        
        // 创建屏幕录制器
        screenRecorder = ScreenRecorder()
        print("✅ 屏幕录制器已初始化")
        
        // 创建鼠标/触摸板监听器
        if let overlay = overlayWindow {
            mouseMonitor = MouseMonitor(overlayWindow: overlay, delegate: self)
            print("✅ 鼠标监听器已创建")
        }
        
        // 注册全局快捷键
        setupHotKey()
        print("✅ 快捷键已注册 (⌘+⇧+F 切换，⌘+⇧+R 录制)")
        
        // 显示设置窗口
        showSettingsWindow()
        print("✅ 设置窗口已显示")
        
        print("✅ FocusBox 已启动")
        
        // 激活应用，确保窗口显示
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupHotKey() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Command + Shift + F - 切换启用/禁用
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 3 {  // F 键
                self?.toggleEnabled()
            }
            // Command + Shift + R - 开始/停止录制
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 15 {  // R 键
                self?.toggleRecording()
            }
        }
    }
    
    @objc func toggleRecording() {
        guard let recorder = screenRecorder else { return }
        
        if recorder.isRecordingStatus {
            // 停止录制
            recorder.stopRecording()
            print("⏹️ 录制已停止")
        } else {
            // 开始录制 - 录制整个屏幕
            if let screen = NSScreen.main {
                let outputDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                let outputUrl = outputDir?.appendingPathComponent("FocusBox_\(Date().timeIntervalSince1970).mp4")
                
                if let url = outputUrl {
                    recorder.startRecording(rect: screen.frame, outputUrl: url)
                    print("🎬 录制已开始：\(url.path)")
                    
                    // 发送通知
                    sendRecordingNotification(started: true)
                }
            }
        }
    }
    
    private func sendRecordingNotification(started: Bool) {
        if #available(macOS 10.14, *) {
            let notification = UNUserNotificationCenter.current()
            notification.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    let content = UNMutableNotificationContent()
                    content.title = "FocusBox 录制"
                    content.body = started ? "🎬 录制已开始" : "✅ 录制已保存"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: "focusbox_recording", content: content, trigger: nil)
                    notification.add(request)
                }
            }
        }
    }
    
    @objc func toggleEnabled() {
        isEnabled.toggle()
        print("🔌 FocusBox 已\(isEnabled ? "启用" : "禁用")")
        
        // 更新设置模型（同步 UI）
        settingsModel?.isActive = isEnabled
        
        // 更新状态栏图标
        if let button = statusItem?.button {
            if isEnabled {
                button.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "FocusBox")
                button.title = ""
            } else {
                button.image = NSImage(systemSymbolName: "rectangle.dashed.badge.xmark", accessibilityDescription: "FocusBox Disabled")
                button.title = "⏸️"
            }
        }
        
        // 通知鼠标监听器
        mouseMonitor?.setEnabled(isEnabled)
        
        // 发送通知
        sendNotification(enabled: isEnabled)
    }
    
    private func sendNotification(enabled: Bool) {
        // macOS 10.14+ 使用 UserNotifications
        if #available(macOS 10.14, *) {
            let notification = UNUserNotificationCenter.current()
            notification.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    let content = UNMutableNotificationContent()
                    content.title = "FocusBox"
                    content.body = enabled ? "已启用 - 可以绘制矩形框" : "已暂停 - 按 ⌘+⇧+F 重新启用"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: "focusbox_toggle", content: content, trigger: nil)
                    notification.add(request)
                }
            }
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "FocusBox")
            button.action = #selector(toggleFromStatusItem)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 创建菜单（右键点击时显示）
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示设置窗口", action: #selector(showSettings), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 FocusBox", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func toggleFromStatusItem() {
        // 左键点击：切换启用/禁用
        toggleEnabled()
    }
    
    @objc private func showSettings() {
        showSettingsWindow()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func showSettingsWindow() {
        if settingsWindow != nil {
            settingsWindow?.orderFront(nil)
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        print("🔧 创建设置窗口...")
        
        // 创建设置数据模型
        settingsModel = SettingsModel(
            isActive: isEnabled,
            borderWidth: borderWidth,
            colorTheme: colorTheme,
            fadeDelay: fadeDelay,
            onToggle: { [weak self] active in
                if self?.isEnabled != active {
                    self?.toggleEnabled()
                }
            },
            onBorderWidthChange: { [weak self] width in
                self?.borderWidth = width
                print("📏 边框粗细：\(width)")
            },
            onThemeChange: { [weak self] theme in
                self?.colorTheme = theme
                print("🎨 颜色主题：\(theme.rawValue)")
            },
            onFadeDelayChange: { [weak self] delay in
                self?.fadeDelay = delay
                print("⏱️ 淡出延迟：\(delay)秒")
            },
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )
        
        // 使用 SwiftUI 创建设置界面
        let contentView = SettingsView(model: settingsModel!)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.contentView = hostingController.view
        settingsWindow?.title = "FocusBox 设置"
        settingsWindow?.level = .normal
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        
        print("📐 窗口位置：\(settingsWindow?.frame ?? NSRect.zero)")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 FocusBox 已退出")
    }
}

// 设置数据模型（可观察对象）
class SettingsModel: ObservableObject {
    @Published var isActive: Bool
    @Published var borderWidth: CGFloat
    @Published var colorTheme: ColorTheme
    @Published var fadeDelay: TimeInterval
    
    var onToggle: (Bool) -> Void
    var onBorderWidthChange: (CGFloat) -> Void
    var onThemeChange: (ColorTheme) -> Void
    var onFadeDelayChange: (TimeInterval) -> Void
    var onQuit: () -> Void
    
    init(
        isActive: Bool,
        borderWidth: CGFloat,
        colorTheme: ColorTheme,
        fadeDelay: TimeInterval,
        onToggle: @escaping (Bool) -> Void,
        onBorderWidthChange: @escaping (CGFloat) -> Void,
        onThemeChange: @escaping (ColorTheme) -> Void,
        onFadeDelayChange: @escaping (TimeInterval) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.isActive = isActive
        self.borderWidth = borderWidth
        self.colorTheme = colorTheme
        self.fadeDelay = fadeDelay
        self.onToggle = onToggle
        self.onBorderWidthChange = onBorderWidthChange
        self.onThemeChange = onThemeChange
        self.onFadeDelayChange = onFadeDelayChange
        self.onQuit = onQuit
    }
}

// SwiftUI 设置界面
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    
    var body: some View {
        VStack(spacing: 20) {
            // 图标和标题
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("FocusBox")
                .font(.title)
                .fontWeight(.bold)
            
            // 状态指示和开关
            HStack {
                Circle()
                    .fill(model.isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(model.isActive ? "运行中" : "已暂停")
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $model.isActive)
                    .onChange(of: model.isActive) { newValue in
                        model.onToggle(newValue)
                    }
                    .toggleStyle(.switch)
            }
            
            // 边框粗细
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("边框粗细：\(Int(model.borderWidth))px")
                        .fontWeight(.medium)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(model.borderWidth) },
                    set: { newValue in
                        model.borderWidth = newValue
                        model.onBorderWidthChange(CGFloat(newValue))
                    }
                ), in: 2...20, step: 1)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 淡出延迟
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("淡出延迟：\(String(format: "%.1f", model.fadeDelay))秒")
                        .fontWeight(.medium)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { model.fadeDelay },
                    set: { newValue in
                        model.fadeDelay = newValue
                        model.onFadeDelayChange(newValue)
                    }
                ), in: 0.5...5.0, step: 0.5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 颜色主题
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色主题")
                    .fontWeight(.medium)
                Picker("主题", selection: Binding(
                    get: { model.colorTheme },
                    set: { newValue in
                        model.colorTheme = newValue
                        model.onThemeChange(newValue)
                    }
                )) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Text("使用说明：")
                    .fontWeight(.semibold)
                Text("• 按住鼠标左键或触摸板拖动")
                Text("• 会绘制彩色矩形框")
                Text("• 松开后 1 秒自动消失")
                Divider()
                Text("⌨️ 快捷键：")
                    .fontWeight(.medium)
                Text("  ⌘+⇧+F 启用/暂停")
                    .foregroundColor(.blue)
                Text("  ⌘+⇧+R 开始/停止录制")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // 按钮
            HStack(spacing: 20) {
                Button(action: { model.onQuit() }) {
                    Text("退出")
                        .frame(width: 80)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(30)
        .frame(width: 350, height: 450)
    }
}

// 鼠标监听器代理协议
protocol MouseMonitorDelegate: AnyObject {
    var isEnabled: Bool { get }
    var borderWidth: CGFloat { get }
    var colorTheme: ColorTheme { get }
    var fadeDelay: TimeInterval { get }
    func toggleEnabled()
}

extension AppDelegate: MouseMonitorDelegate {}

// 颜色主题
enum ColorTheme: String, CaseIterable {
    case rainbow = "🌈 彩虹"
    case ocean = "🌊 海洋"
    case sunset = "🌅 日落"
    case forest = "🌲 森林"
    case monochrome = "⚫ 单色"
    
    var colors: [NSColor] {
        switch self {
        case .rainbow:
            return [NSColor.red, NSColor.orange, NSColor.yellow, NSColor.green, NSColor.blue, NSColor.purple]
        case .ocean:
            return [NSColor(red: 0.0, green: 0.4, blue: 0.6, alpha: 1.0),
                    NSColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1.0),
                    NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)]
        case .sunset:
            return [NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
                    NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
                    NSColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0)]
        case .forest:
            return [NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0),
                    NSColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0),
                    NSColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1.0)]
        case .monochrome:
            return [NSColor.black, NSColor.darkGray, NSColor.gray]
        }
    }
}

// 手动创建 main 入口
@main
struct FocusBoxApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
