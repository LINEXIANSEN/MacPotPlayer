import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册支持的文件类型
        NSApp.servicesProvider = self

        // 设置应用激活策略
        NSApp.setActivationPolicy(.regular)

        // 初始化日志系统
        Logger.setup()

        // 注册媒体键监听
        MediaKeyHandler.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 保存播放进度
        PlayerManager.shared.savePlaybackState()
        MediaKeyHandler.shared.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        PlayerManager.shared.open(url: url)
    }

    // 支持从 Finder 拖入文件
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        PlayerManager.shared.open(url: url)
        return true
    }
}
