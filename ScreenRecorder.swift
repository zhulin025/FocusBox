import AppKit
import AVFoundation
import CoreMedia
import UserNotifications

class ScreenRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var screenInput: AVCaptureScreenInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentOutputUrl: URL?
    
    // 状态
    private var isRecording = false
    var isRecordingStatus: Bool { isRecording }
    
    // 回调
    var onRecordingComplete: ((String) -> Void)?
    var onRecordingError: ((String) -> Void)?
    
    /// 开始录制指定区域
    func startRecording(rect: NSRect, outputUrl: URL) {
        guard !isRecording else {
            onRecordingError?("正在录制中")
            return
        }
        
        print("🎬 开始录制...")
        print("📍 输出：\(outputUrl.path)")
        
        currentOutputUrl = outputUrl
        
        // 创建捕获会话
        captureSession = AVCaptureSession()
        guard let session = captureSession else {
            onRecordingError?("无法创建捕获会话")
            return
        }
        
        // 创建屏幕输入
        screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID())
        guard let input = screenInput else {
            onRecordingError?("无法创建屏幕输入")
            return
        }
        
        // 设置帧率
        input.minFrameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
        
        // 创建电影输出
        movieOutput = AVCaptureMovieFileOutput()
        guard let output = movieOutput else {
            onRecordingError?("无法创建电影输出")
            return
        }
        
        // 添加输入输出到会话
        session.beginConfiguration()
        session.sessionPreset = .high
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        // 开始录制
        session.startRunning()
        output.startRecording(to: outputUrl, recordingDelegate: self)
        
        isRecording = true
        sendRecordingNotification(started: true)
    }
    
    /// 停止录制
    func stopRecording() {
        guard isRecording, let output = movieOutput else { return }
        
        print("⏹️ 停止录制...")
        output.stopRecording()
        
        isRecording = false
        captureSession?.stopRunning()
        captureSession = nil
        movieOutput = nil
        screenInput = nil
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ 录制失败：\(error.localizedDescription)")
            onRecordingError?(error.localizedDescription)
            sendRecordingNotification(started: false, success: false, message: "录制失败")
        } else {
            print("✅ 录制完成：\(outputFileURL.path)")
            onRecordingComplete?(outputFileURL.path)
            sendRecordingNotification(started: false, success: true, message: "录制已保存")
        }
        
        isRecording = false
        captureSession?.stopRunning()
        captureSession = nil
        movieOutput = nil
        screenInput = nil
    }
    
    // MARK: - 通知
    
    private func sendRecordingNotification(started: Bool, success: Bool = true, message: String = "") {
        if #available(macOS 10.14, *) {
            let notification = UNUserNotificationCenter.current()
            notification.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    let content = UNMutableNotificationContent()
                    content.title = "FocusBox 录制"
                    
                    if started {
                        content.body = "🎬 录制已开始"
                    } else {
                        content.body = success ? "✅ \(message)" : "❌ \(message)"
                    }
                    
                    content.sound = .default
                    
                    let request = UNNotificationRequest(
                        identifier: "focusbox_recording_\(Date().timeIntervalSince1970)",
                        content: content,
                        trigger: nil
                    )
                    notification.add(request)
                }
            }
        }
    }
}
