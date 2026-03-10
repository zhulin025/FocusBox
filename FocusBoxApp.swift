import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var mouseMonitor: MouseMonitor?
    private var settingsWindow: NSWindow?
    
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
            mouseMonitor = MouseMonitor(overlayWindow: overlay)
            print("✅ 鼠标监听器已创建")
        }
        
        // 显示设置窗口
        showSettingsWindow()
        print("✅ 设置窗口已显示")
        
        print("✅ FocusBox 已启动")
        
        // 激活应用，确保窗口显示
        NSApp.activate(ignoringOtherApps: true)
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
            isActive: true,
            onToggle: { _ in },
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
    var onToggle: (Bool) -> Void
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
            
            // 状态指示
            HStack {
                Circle()
                    .fill(isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isActive ? "运行中" : "已暂停")
                    .foregroundColor(.secondary)
            }
            
            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Text("使用说明：")
                    .fontWeight(.semibold)
                Text("• 按住鼠标左键或触摸板拖动")
                Text("• 会绘制彩色矩形框")
                Text("• 松开后 1 秒自动消失")
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
        .frame(width: 320, height: 280)
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
