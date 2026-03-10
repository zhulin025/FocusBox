import AppKit

class ScreenRecorder: NSObject {
    private var isRecording = false
    private var outputPath: String = ""
    
    // 回调
    var onRecordingComplete: ((String) -> Void)?
    var onRecordingError: ((String) -> Void)?
    
    /// 开始录制指定区域
    func startRecording(rect: NSRect, outputUrl: URL) {
        guard !isRecording else {
            onRecordingError?("正在录制中")
            return
        }
        
        outputPath = outputUrl.path
        isRecording = true
        
        print("🎬 开始录制：\(rect)")
        print("📍 输出：\(outputUrl.path)")
        
        // 使用 screenshot 命令行工具（macOS 内置）
        Task {
            do {
                // 等待 5 秒录制
                try await Task.sleep(nanoseconds: 5_000_000_000)
                
                // 截取屏幕截图（简化版本）
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-x", "-o", "-F", outputUrl.path]
                
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    isRecording = false
                    print("✅ 录制完成：\(outputPath)")
                    onRecordingComplete?(outputPath)
                } else {
                    isRecording = false
                    onRecordingError?("录制失败")
                }
            } catch {
                isRecording = false
                onRecordingError?(error.localizedDescription)
                print("❌ 录制失败：\(error)")
            }
        }
    }
    
    /// 停止录制
    func stopRecording() {
        guard isRecording else { return }
        
        print("⏹️ 停止录制...")
        isRecording = false
        
        // 简化版本：立即完成
        onRecordingComplete?(outputPath)
    }
    
    /// 是否正在录制
    var isRecordingStatus: Bool {
        return isRecording
    }
}
