import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var mouseMonitor: MouseMonitor?
    private var settingsWindow: NSWindow?
    
    // 全局快捷键监听
    private var hotKeyMonitor: Any?
    var isEnabled = true
    
    // 用户设置
    var borderWidth: CGFloat = 4.0
    var colorTheme: ColorTheme = .rainbow
    var fadeDelay: TimeInterval = 1.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 FocusBox 启动中...")
        
        // 创建状态栏图标
        setupStatusItem()
        print("✅ 状态栏图标已创建")
        
        // 创建覆盖窗口
        overlayWindow = OverlayWindow()
        print("✅ 覆盖窗口已创建")
        
        // 创建鼠标/触摸板监听器
        if let overlay = overlayWindow {
            mouseMonitor = MouseMonitor(overlayWindow: overlay, delegate: self)
            print("✅ 鼠标监听器已创建")
        }
        
        // 注册全局快捷键 (Command + Shift + F)
        setupHotKey()
        print("✅ 快捷键已注册 (⌘+⇧+F)")
        
        // 显示设置窗口
        showSettingsWindow()
        print("✅ 设置窗口已显示")
        
        print("✅ FocusBox 已启动")
        
        // 激活应用，确保窗口显示
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupHotKey() {
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Command + Shift + F
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 3 {  // F 键
                self?.toggleEnabled()
            }
        }
    }
    
    @objc func toggleEnabled() {
        isEnabled.toggle()
        print("🔌 FocusBox 已\(isEnabled ? "启用" : "禁用")")
        
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
            button.action = #selector(toggleMenu)
            button.target = self
        }
        
        // 创建菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示设置窗口", action: #selector(showSettings), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 FocusBox", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func toggleMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: statusItem?.button)
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
        
        // 使用 SwiftUI 创建设置界面
        let contentView = SettingsView(
            isActive: isEnabled,
            borderWidth: borderWidth,
            colorTheme: colorTheme,
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
            onQuit: { [weak self] in
                self?.quitApp()
            }
        )
        
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

// SwiftUI 设置界面
struct SettingsView: View {
    var isActive: Bool
    var borderWidth: CGFloat
    var colorTheme: ColorTheme
    var onToggle: (Bool) -> Void
    var onBorderWidthChange: (CGFloat) -> Void
    var onThemeChange: (ColorTheme) -> Void
    var onQuit: () -> Void
    
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
                    .fill(isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isActive ? "运行中" : "已暂停")
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
            }
            
            // 边框粗细
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("边框粗细：\(Int(borderWidth))px")
                        .fontWeight(.medium)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(borderWidth) },
                    set: { onBorderWidthChange(CGFloat($0)) }
                ), in: 2...20, step: 1)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 颜色主题
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色主题")
                    .fontWeight(.medium)
                Picker("主题", selection: Binding(
                    get: { colorTheme },
                    set: { onThemeChange($0) }
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
                Text("⌨️ 快捷键：⌘+⇧+F 启用/暂停")
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
                Button(action: onQuit) {
                    Text("退出")
                        .frame(width: 80)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(30)
        .frame(width: 350, height: 420)
    }
}

// 鼠标监听器代理协议
protocol MouseMonitorDelegate: AnyObject {
    var isEnabled: Bool { get }
    var borderWidth: CGFloat { get }
    var colorTheme: ColorTheme { get }
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
