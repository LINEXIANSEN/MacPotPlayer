import Foundation
import AVFoundation
import Combine

/// PlayerManager - 播放器核心管理器 (单例)
/// 统一管理所有播放状态、控制逻辑和媒体信息
@MainActor
final class PlayerManager: ObservableObject {

    static let shared = PlayerManager()

    // MARK: - Published State

    @Published var state: PlaybackState = .idle
    @Published var currentItem: MediaItem?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false
    @Published var playbackRate: Float = 1.0
    @Published var aspectRatio: AspectRatioMode = .fit
    @Published var isFullscreen: Bool = false
    @Published var subtitleDelay: Double = 0
    @Published var subtitleSize: CGFloat = 36
    @Published var subtitlePositionY: CGFloat = 0.1
    @Published var videoTracks: [TrackInfo] = []
    @Published var audioTracks: [TrackInfo] = []
    @Published var subtitleTracks: [TrackInfo] = []
    @Published var errorMessage: String?
    @Published var isBuffering: Bool = false
    @Published var bufferedProgress: Double = 0
    @Published var brightness: Float = 0
    @Published var contrast: Float = 1
    @Published var saturation: Float = 1
    @Published var isAbLoopActive: Bool = false
    @Published var abLoopStart: Double = 0
    @Published var abLoopEnd: Double = 0

    // MARK: - VR / 360° 全景
    @Published var isVRMode: Bool = false
    let vrCamera = VRCameraController()

    // MARK: - Internal Components

    private(set) var engine: FFmpegPlayer?
    let playlistManager = PlaylistManager()
    let subtitleManager = SubtitleManager()
    let screenshotManager = ScreenshotManager()
    let audioEngine = AudioProcessingEngine()

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var progressSaveTimer: Timer?

    // MARK: - Init

    private init() {
        setupBindings()
        restoreLastSession()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听播放列表变化
        playlistManager.$currentIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncFromPlaylist()
            }
            .store(in: &cancellables)
    }

    // MARK: - Open Media

    func open(url: URL) {
        // 停止当前播放
        stop()

        let item = MediaItem(url: url)
        currentItem = item
        playlistManager.addAndPlay(item: item)

        openInternal(item: item)
    }

    func openMultiple(urls: [URL]) {
        let items = urls.map { MediaItem(url: $0) }
        playlistManager.replace(items: items)
        if let first = items.first {
            openInternal(item: first)
        }
    }

    private func openInternal(item: MediaItem) {
        state = .loading
        isBuffering = true

        // 保存到最近文件
        RecentFilesManager.shared.add(item: item)

        // 尝试恢复上次播放进度
        let savedProgress = PlaybackProgressStore.shared.progress(for: item.url)

        let player = FFmpegPlayer(url: item.url)
        player.delegate = self
        self.engine = player

        // 探测媒体信息
        player.loadMediaInfo { [weak self] info in
            guard let self else { return }
            self.duration = info.duration
            self.videoTracks = info.videoTracks
            self.audioTracks = info.audioTracks
            self.subtitleTracks = info.subtitleTracks
            self.isBuffering = false
            self.state = .ready

            // 恢复进度
            if savedProgress > 5 && savedProgress < info.duration - 5 {
                player.seek(to: savedProgress)
            }

            self.subtitleManager.loadEmbeddedTracks(from: info.subtitleTracks)
            self.subtitleManager.autoLoadExternalSubtitle(for: item.url)

            // 自动检测全景视频
            self.detectAndSetVRMode(url: item.url, info: info)

            player.play()
            self.isPlaying = true
            self.state = .playing
        }

        setupProgressSaveTimer()
        startTimeObserver(player: player)
    }

    // MARK: - Playback Control

    func play() {
        engine?.play()
        isPlaying = true
        state = .playing
    }

    func pause() {
        engine?.pause()
        isPlaying = false
        state = .paused
    }

    func stop() {
        savePlaybackState()
        engine?.stop()
        engine = nil
        isPlaying = false
        state = .idle
        currentTime = 0
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: Double) {
        let clamped = max(0, min(time, duration))
        engine?.seek(to: clamped)
        currentTime = clamped
    }

    func seek(by delta: Double) {
        seek(to: currentTime + delta)
    }

    // MARK: - Volume

    func setVolume(_ value: Float) {
        let clamped = max(0, min(value, 2.0)) // 支持最高 200% 音量增强
        volume = clamped
        engine?.setVolume(clamped)
        audioEngine.setVolume(clamped)
    }

    func adjustVolume(by delta: Float) {
        setVolume(volume + delta / 100.0)
    }

    func toggleMute() {
        isMuted.toggle()
        engine?.setMuted(isMuted)
    }

    // MARK: - Playback Rate

    func setRate(_ rate: Float) {
        let clamped = max(0.1, min(rate, 16.0))
        playbackRate = clamped
        engine?.setRate(clamped)
    }

    func increaseRate() { setRate(playbackRate + 0.1) }
    func decreaseRate() { setRate(playbackRate - 0.1) }

    // MARK: - Video Adjustments

    func setAspectRatio(_ mode: AspectRatioMode) {
        aspectRatio = mode
    }

    func setBrightness(_ value: Float) {
        brightness = max(-1, min(value, 1))
        engine?.setFilter(brightness: brightness, contrast: contrast, saturation: saturation)
    }

    func setContrast(_ value: Float) {
        contrast = max(0, min(value, 2))
        engine?.setFilter(brightness: brightness, contrast: contrast, saturation: saturation)
    }

    func setSaturation(_ value: Float) {
        saturation = max(0, min(value, 2))
        engine?.setFilter(brightness: brightness, contrast: contrast, saturation: saturation)
    }

    // MARK: - Subtitle

    func loadSubtitleFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SupportedFormats.subtitleTypes
        panel.title = "选择字幕文件"
        if panel.runModal() == .OK, let url = panel.url {
            subtitleManager.loadExternal(url: url)
        }
    }

    func adjustSubtitleDelay(by delta: Double) {
        subtitleDelay += delta
        subtitleManager.setDelay(subtitleDelay)
    }

    func adjustSubtitleSize(by delta: CGFloat) {
        subtitleSize = max(12, min(subtitleSize + delta, 120))
    }

    func adjustSubtitlePosition(by delta: CGFloat) {
        subtitlePositionY = max(0, min(subtitlePositionY + delta / 100.0, 0.95))
    }

    // MARK: - AB Loop

    func setABLoopStart() {
        abLoopStart = currentTime
        if abLoopStart >= abLoopEnd { abLoopEnd = duration }
        isAbLoopActive = true
    }

    func setABLoopEnd() {
        abLoopEnd = currentTime
        isAbLoopActive = true
    }

    func clearABLoop() {
        isAbLoopActive = false
        abLoopStart = 0
        abLoopEnd = 0
    }

    // MARK: - Playlist Navigation

    func playNext() {
        playlistManager.moveNext()
    }

    func playPrevious() {
        playlistManager.movePrevious()
    }

    private func syncFromPlaylist() {
        guard let item = playlistManager.currentItem else { return }
        if item.url != currentItem?.url {
            openInternal(item: item)
        }
    }

    // MARK: - Screenshot

    func takeScreenshot() {
        guard let engine else { return }
        engine.captureFrame { [weak self] image in
            self?.screenshotManager.save(image: image)
        }
    }

    func startBurstScreenshot() {
        guard let engine else { return }
        screenshotManager.startBurst(engine: engine)
    }

    // MARK: - Window / Fullscreen

    func toggleFullscreen() {
        guard let window = NSApp.keyWindow else { return }
        window.toggleFullScreen(nil)
        isFullscreen.toggle()
    }

    func togglePictureInPicture() {
        NotificationCenter.default.post(name: .togglePictureInPicture, object: nil)
    }

    // MARK: - File Open Panels

    func showOpenFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SupportedFormats.videoTypes + SupportedFormats.audioTypes
        panel.allowsMultipleSelection = true
        panel.title = "打开媒体文件"
        if panel.runModal() == .OK {
            if panel.urls.count == 1 {
                open(url: panel.urls[0])
            } else {
                openMultiple(urls: panel.urls)
            }
        }
    }

    func showOpenURLPanel() {
        NotificationCenter.default.post(name: .showOpenURLPanel, object: nil)
    }

    // MARK: - Time Observer

    private func startTimeObserver(player: FFmpegPlayer) {
        player.onTimeUpdate = { [weak self] time in
            guard let self else { return }
            self.currentTime = time

            // AB 循环
            if self.isAbLoopActive && time >= self.abLoopEnd {
                self.seek(to: self.abLoopStart)
            }

            // 字幕同步
            self.subtitleManager.update(currentTime: time + self.subtitleDelay)
        }

        player.onBufferProgress = { [weak self] progress in
            self?.bufferedProgress = progress
        }
    }

    // MARK: - Progress Persistence

    private func setupProgressSaveTimer() {
        progressSaveTimer?.invalidate()
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.savePlaybackState()
        }
    }

    func savePlaybackState() {
        guard let item = currentItem, currentTime > 5 else { return }
        PlaybackProgressStore.shared.save(progress: currentTime, for: item.url)
    }

    private func restoreLastSession() {
        // 恢复上次的播放列表状态
        playlistManager.restoreSession()
    }
}

// MARK: - FFmpegPlayerDelegate

extension PlayerManager: FFmpegPlayerDelegate {
    func playerDidReachEnd(_ player: FFmpegPlayer) {
        let loopMode = PreferencesManager.shared.loopMode
        switch loopMode {
        case .none:
            playNext()
        case .one:
            seek(to: 0)
            play()
        case .all:
            playNext()
        }
    }

    func player(_ player: FFmpegPlayer, didFailWithError error: Error) {
        state = .error(error.localizedDescription)
        errorMessage = error.localizedDescription
        isPlaying = false
    }

    func playerDidStartBuffering(_ player: FFmpegPlayer) {
        isBuffering = true
    }

    func playerDidFinishBuffering(_ player: FFmpegPlayer) {
        isBuffering = false
    }
}

// MARK: - VR / 360° 全景

extension PlayerManager {

    /// 自动检测是否为 360° 全景视频
    private func detectAndSetVRMode(url: URL, info: MediaInfo) {
        // 1. 元数据检测：读取球形视频标签
        let asset = AVAsset(url: url)
        Task {
            let metadata = try? await asset.load(.metadata)
            let isSpherical = metadata?.contains {
                $0.identifier?.rawValue.contains("spherical") == true ||
                $0.commonKey?.rawValue.contains("spherical") == true
            } ?? false

            // 2. 文件名检测：包含 360 / VR / equirectangular 关键词
            let name = url.lastPathComponent.lowercased()
            let nameHint = name.contains("360") || name.contains("_vr") || name.contains("equirect")

            // 3. 宽高比检测：equirectangular 通常是 2:1
            let w = info.videoWidth
            let h = info.videoHeight
            let isEquirect = h > 0 && abs(Double(w) / Double(h) - 2.0) < 0.05

            await MainActor.run {
                if isSpherical || nameHint || isEquirect {
                    self.enableVRMode(true)
                }
            }
        }
    }

    /// 手动切换 VR 模式
    func toggleVRMode() {
        enableVRMode(!isVRMode)
    }

    func enableVRMode(_ enable: Bool) {
        isVRMode = enable
        if enable {
            vrCamera.reset()
        }
    }
}

// MARK: - PlaybackState

enum PlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case error(String)
}

// MARK: - AspectRatioMode

enum AspectRatioMode: String, CaseIterable {
    case original = "原始"
    case fit      = "适应窗口"
    case fill     = "填充窗口"
    case r4x3     = "4:3"
    case r16x9    = "16:9"
    case r16x10   = "16:10"
    case r21x9    = "21:9"
    case r185x1   = "1.85:1"
    case r235x1   = "2.35:1"

    var ratio: CGFloat? {
        switch self {
        case .original, .fit, .fill: return nil
        case .r4x3:    return 4.0 / 3.0
        case .r16x9:   return 16.0 / 9.0
        case .r16x10:  return 16.0 / 10.0
        case .r21x9:   return 21.0 / 9.0
        case .r185x1:  return 1.85
        case .r235x1:  return 2.35
        }
    }
}
