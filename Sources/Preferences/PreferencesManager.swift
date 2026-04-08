import Foundation
import Combine

/// PreferencesManager - 全局设置管理
@MainActor
final class PreferencesManager: ObservableObject {

    static let shared = PreferencesManager()

    // 播放
    @Published var loopMode: LoopMode = .none
    @Published var rememberPosition: Bool = true
    @Published var autoPlayNext: Bool = true
    @Published var defaultRate: Float = 1.0
    @Published var hardwareDecoding: Bool = true

    // 字幕
    @Published var subtitleFontName: String = "PingFangSC-Semibold"
    @Published var subtitleFontSize: CGFloat = 36
    @Published var subtitleColor: String = "#FFFFFF"
    @Published var subtitleBgOpacity: Double = 0.45
    @Published var autoLoadSubtitle: Bool = true
    @Published var subtitlePreferLanguage: String = "zh"

    // 截图
    @Published var screenshotFormat: ScreenshotFormat = .png
    @Published var screenshotFolder: URL? = nil

    // 界面
    @Published var theme: AppTheme = .system
    @Published var alwaysOnTop: Bool = false
    @Published var hideControlsDelay: Double = 3.0
    @Published var showRemainingTime: Bool = false

    // 音频
    @Published var defaultVolume: Float = 1.0
    @Published var volumeMax: Float = 2.0
    @Published var normalizeAudio: Bool = false

    // 网络
    @Published var bufferSizeSeconds: Double = 5
    @Published var userAgent: String = "MacPotPlayer/1.0"

    private let defaults = UserDefaults.standard

    private init() { load() }

    func load() {
        if let raw = defaults.string(forKey: "loopMode"),
           let mode = LoopMode(rawValue: raw) { loopMode = mode }
        rememberPosition = defaults.object(forKey: "rememberPosition") as? Bool ?? true
        autoPlayNext     = defaults.object(forKey: "autoPlayNext")     as? Bool ?? true
        defaultRate      = defaults.object(forKey: "defaultRate")      as? Float ?? 1.0
        hardwareDecoding = defaults.object(forKey: "hardwareDecoding") as? Bool ?? true
        subtitleFontSize = defaults.object(forKey: "subtitleFontSize") as? CGFloat ?? 36
        autoLoadSubtitle = defaults.object(forKey: "autoLoadSubtitle") as? Bool ?? true
        if let raw = defaults.string(forKey: "screenshotFormat"),
           let fmt = ScreenshotFormat(rawValue: raw) { screenshotFormat = fmt }
        if let bookmarkData = defaults.data(forKey: "screenshotFolder"),
           let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: nil) {
            screenshotFolder = url
        }
        if let raw = defaults.string(forKey: "theme"),
           let t = AppTheme(rawValue: raw) { theme = t }
        alwaysOnTop       = defaults.object(forKey: "alwaysOnTop")       as? Bool   ?? false
        hideControlsDelay = defaults.object(forKey: "hideControlsDelay") as? Double ?? 3.0
        defaultVolume     = defaults.object(forKey: "defaultVolume")     as? Float  ?? 1.0
        volumeMax         = defaults.object(forKey: "volumeMax")         as? Float  ?? 2.0
        normalizeAudio    = defaults.object(forKey: "normalizeAudio")    as? Bool   ?? false
    }

    func save() {
        defaults.set(loopMode.rawValue, forKey: "loopMode")
        defaults.set(rememberPosition, forKey: "rememberPosition")
        defaults.set(autoPlayNext,     forKey: "autoPlayNext")
        defaults.set(defaultRate,      forKey: "defaultRate")
        defaults.set(hardwareDecoding, forKey: "hardwareDecoding")
        defaults.set(subtitleFontSize, forKey: "subtitleFontSize")
        defaults.set(autoLoadSubtitle, forKey: "autoLoadSubtitle")
        defaults.set(screenshotFormat.rawValue, forKey: "screenshotFormat")
        defaults.set(theme.rawValue,   forKey: "theme")
        defaults.set(alwaysOnTop,      forKey: "alwaysOnTop")
        defaults.set(hideControlsDelay,forKey: "hideControlsDelay")
        defaults.set(defaultVolume,    forKey: "defaultVolume")
        defaults.set(volumeMax,        forKey: "volumeMax")
        defaults.set(normalizeAudio,   forKey: "normalizeAudio")
    }
}

enum AppTheme: String, CaseIterable {
    case system = "跟随系统"
    case light  = "浅色"
    case dark   = "深色"
}
