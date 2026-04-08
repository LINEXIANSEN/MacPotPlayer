import Foundation
import OSLog

/// Logger - 统一日志系统
enum Logger {
    private static let subsystem = "com.macpotplayer.app"

    static let player    = os.Logger(subsystem: subsystem, category: "player")
    static let decoder   = os.Logger(subsystem: subsystem, category: "decoder")
    static let subtitle  = os.Logger(subsystem: subsystem, category: "subtitle")
    static let network   = os.Logger(subsystem: subsystem, category: "network")
    static let ui        = os.Logger(subsystem: subsystem, category: "ui")

    static func setup() {
        // 可在此处配置日志级别或输出目标
    }
}

// MARK: - NotificationCenter Extension

extension Notification.Name {
    static let togglePlaylist        = Notification.Name("MacPotPlayer.togglePlaylist")
    static let showOpenURLPanel      = Notification.Name("MacPotPlayer.showOpenURLPanel")
    static let showEqualizer         = Notification.Name("MacPotPlayer.showEqualizer")
    static let showSubtitlePanel     = Notification.Name("MacPotPlayer.showSubtitlePanel")
    static let togglePictureInPicture = Notification.Name("MacPotPlayer.togglePictureInPicture")
    static let screenshotTaken       = Notification.Name("MacPotPlayer.screenshotTaken")
    static let showVideoAdjustments  = Notification.Name("MacPotPlayer.showVideoAdjustments")
    static let showBookmarkPanel     = Notification.Name("MacPotPlayer.showBookmarkPanel")
}
