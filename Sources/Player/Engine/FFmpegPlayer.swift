import Foundation
import AVFoundation
import CoreVideo
import CoreGraphics

// MARK: - FFmpegPlayer
// 封装 FFmpeg C API，提供 Swift 友好的接口
// 实际运行时需要链接 FFmpeg xcframework (见 Scripts/setup_dependencies.sh)

protocol FFmpegPlayerDelegate: AnyObject {
    func playerDidReachEnd(_ player: FFmpegPlayer)
    func player(_ player: FFmpegPlayer, didFailWithError error: Error)
    func playerDidStartBuffering(_ player: FFmpegPlayer)
    func playerDidFinishBuffering(_ player: FFmpegPlayer)
}

final class FFmpegPlayer {

    // MARK: - Properties

    weak var delegate: FFmpegPlayerDelegate?

    var onTimeUpdate: ((Double) -> Void)?
    var onBufferProgress: ((Double) -> Void)?
    var onFrameReady: ((CVPixelBuffer) -> Void)?

    private(set) var isPlaying: Bool = false
    private(set) var duration: Double = 0

    private let url: URL
    private var decodeContext: FFmpegDecodeContext?
    private var videoRenderer: VideoRenderer?
    private var audioRenderer: AudioRenderer?
    private var decodeQueue = DispatchQueue(label: "com.macpotplayer.decode", qos: .userInteractive)
    private var renderQueue = DispatchQueue(label: "com.macpotplayer.render", qos: .userInteractive)
    private var displayLink: CVDisplayLink?
    private var currentTimeInternal: Double = 0
    private var rate: Float = 1.0
    private var volume: Float = 1.0
    private var isMuted: Bool = false
    private var brightnessFilter: Float = 0
    private var contrastFilter: Float = 1
    private var saturationFilter: Float = 1
    private var isSeeking: Bool = false

    // Video frame queue
    private var videoFrameQueue = VideoFrameQueue(capacity: 60)
    private var audioBufferQueue = AudioBufferQueue(capacity: 256)

    // MARK: - Init

    init(url: URL) {
        self.url = url
        setupDisplayLink()
    }

    deinit {
        stop()
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }

    // MARK: - Media Info

    func loadMediaInfo(completion: @escaping (MediaInfo) -> Void) {
        decodeQueue.async { [weak self] in
            guard let self else { return }

            // 打开格式上下文
            guard let context = FFmpegDecodeContext(url: self.url) else {
                DispatchQueue.main.async {
                    self.delegate?.player(self, didFailWithError: PlayerError.cannotOpenFile)
                }
                return
            }

            self.decodeContext = context
            self.duration = context.duration

            // 收集轨道信息
            var videoTracks = [TrackInfo]()
            var audioTracks = [TrackInfo]()
            var subtitleTracks = [TrackInfo]()

            for stream in context.streams {
                switch stream.codecType {
                case .video:
                    videoTracks.append(TrackInfo(
                        index: stream.index,
                        title: stream.title ?? "视频轨 \(stream.index)",
                        language: stream.language,
                        extra: "\(stream.width)x\(stream.height) \(stream.codecName)"
                    ))
                case .audio:
                    audioTracks.append(TrackInfo(
                        index: stream.index,
                        title: stream.title ?? "音频轨 \(stream.index)",
                        language: stream.language,
                        extra: "\(stream.sampleRate)Hz \(stream.channels)ch \(stream.codecName)"
                    ))
                case .subtitle:
                    subtitleTracks.append(TrackInfo(
                        index: stream.index,
                        title: stream.title ?? "字幕轨 \(stream.index)",
                        language: stream.language,
                        extra: stream.codecName
                    ))
                }
            }

            // 获取第一路视频流尺寸
            let firstVideoStream = context.streams.first(where: { $0.codecType == .video })

            let info = MediaInfo(
                duration: context.duration,
                videoTracks: videoTracks,
                audioTracks: audioTracks,
                subtitleTracks: subtitleTracks,
                videoWidth: firstVideoStream?.width ?? 0,
                videoHeight: firstVideoStream?.height ?? 0
            )

            DispatchQueue.main.async { completion(info) }
        }
    }

    // MARK: - Playback Control

    func play() {
        guard let context = decodeContext else { return }
        isPlaying = true
        startDecoding(context: context)
        startDisplayLink()
        audioRenderer?.start()
    }

    func pause() {
        isPlaying = false
        audioRenderer?.pause()
        stopDisplayLink()
    }

    func stop() {
        isPlaying = false
        decodeContext?.close()
        decodeContext = nil
        audioRenderer?.stop()
        stopDisplayLink()
        videoFrameQueue.clear()
        audioBufferQueue.clear()
    }

    func seek(to time: Double) {
        guard let context = decodeContext else { return }
        isSeeking = true
        videoFrameQueue.clear()
        audioBufferQueue.clear()

        decodeQueue.async { [weak self] in
            guard let self else { return }
            context.seek(to: time)
            self.currentTimeInternal = time
            self.isSeeking = false
            if self.isPlaying {
                self.startDecoding(context: context)
            }
        }
    }

    func setRate(_ rate: Float) {
        self.rate = rate
        audioRenderer?.setRate(rate)
    }

    func setVolume(_ volume: Float) {
        self.volume = volume
        audioRenderer?.setVolume(isMuted ? 0 : volume)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        audioRenderer?.setVolume(muted ? 0 : volume)
    }

    func setFilter(brightness: Float, contrast: Float, saturation: Float) {
        brightnessFilter = brightness
        contrastFilter = contrast
        saturationFilter = saturation
        videoRenderer?.setFilter(brightness: brightness, contrast: contrast, saturation: saturation)
    }

    // MARK: - Frame Capture

    func captureFrame(completion: @escaping (CGImage) -> Void) {
        videoRenderer?.captureCurrentFrame(completion: completion)
    }

    // MARK: - Decoding Loop

    private func startDecoding(context: FFmpegDecodeContext) {
        decodeQueue.async { [weak self] in
            guard let self, self.isPlaying else { return }

            while self.isPlaying && !self.isSeeking {
                // 填充视频帧队列
                if self.videoFrameQueue.isFull {
                    Thread.sleep(forTimeInterval: 0.005)
                    continue
                }

                guard let packet = context.readPacket() else {
                    // 文件结束
                    DispatchQueue.main.async {
                        self.delegate?.playerDidReachEnd(self)
                    }
                    break
                }

                switch packet.streamType {
                case .video:
                    if let frame = context.decodeVideoPacket(packet) {
                        self.videoFrameQueue.enqueue(frame)
                    }
                case .audio:
                    if let samples = context.decodeAudioPacket(packet) {
                        self.audioBufferQueue.enqueue(samples)
                        self.audioRenderer?.feed(samples)
                    }
                case .subtitle:
                    break
                }
            }
        }
    }

    // MARK: - Display Link

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            let player = Unmanaged<FFmpegPlayer>.fromOpaque(userInfo!).takeUnretainedValue()
            player.renderNextFrame()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func startDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
    }

    private func renderNextFrame() {
        guard isPlaying, let frame = videoFrameQueue.dequeue() else { return }

        let pts = frame.pts
        currentTimeInternal = pts

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.videoRenderer?.render(frame: frame)
            self.onFrameReady?(frame.pixelBuffer)
            self.onTimeUpdate?(pts)
        }
    }
}

// MARK: - Supporting Types

struct MediaInfo {
    let duration: Double
    let videoTracks: [TrackInfo]
    let audioTracks: [TrackInfo]
    let subtitleTracks: [TrackInfo]
    let videoWidth: Int
    let videoHeight: Int
}

struct TrackInfo: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let language: String?
    let extra: String
}

struct MediaItem: Identifiable {
    let id = UUID()
    let url: URL
    var title: String { url.deletingPathExtension().lastPathComponent }
    var isNetwork: Bool { url.scheme == "http" || url.scheme == "https" || url.scheme == "rtsp" || url.scheme == "rtmp" }
}

enum PlayerError: LocalizedError {
    case cannotOpenFile
    case unsupportedFormat
    case decodeError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:   return "无法打开文件"
        case .unsupportedFormat:return "不支持的格式"
        case .decodeError(let msg): return "解码错误: \(msg)"
        case .networkError(let msg): return "网络错误: \(msg)"
        }
    }
}

// MARK: - Stub Classes (由 Objective-C++ 桥接实现)
// 这些类在 Bridging 层中通过 FFmpeg C API 实现

class FFmpegDecodeContext {
    let duration: Double
    let streams: [StreamInfo]

    init?(url: URL) {
        // TODO: 调用 FFmpeg avformat_open_input / avformat_find_stream_info
        // 通过 Objective-C++ 桥接文件 FFmpegBridge.mm 实现
        self.duration = 0
        self.streams = []
        return nil // 占位，实际通过桥接初始化
    }

    func readPacket() -> FFmpegPacket? { nil }
    func decodeVideoPacket(_ packet: FFmpegPacket) -> VideoFrame? { nil }
    func decodeAudioPacket(_ packet: FFmpegPacket) -> AudioSamples? { nil }
    func seek(to time: Double) {}
    func close() {}
}

struct StreamInfo {
    enum CodecType { case video, audio, subtitle }
    let index: Int
    let codecType: CodecType
    let codecName: String
    let title: String?
    let language: String?
    let width: Int
    let height: Int
    let sampleRate: Int
    let channels: Int
}

struct FFmpegPacket {
    let streamType: StreamInfo.CodecType
    let data: Data
    let pts: Double
}

struct VideoFrame {
    let pixelBuffer: CVPixelBuffer
    let pts: Double
    let width: Int
    let height: Int
}

struct AudioSamples {
    let data: Data
    let pts: Double
    let sampleRate: Int
    let channels: Int
    let format: AudioFormat
}

enum AudioFormat { case float32, int16 }

class VideoRenderer {
    func render(frame: VideoFrame) {}
    func setFilter(brightness: Float, contrast: Float, saturation: Float) {}
    func captureCurrentFrame(completion: @escaping (CGImage) -> Void) {}
}

class AudioRenderer {
    func start() {}
    func pause() {}
    func stop() {}
    func feed(_ samples: AudioSamples) {}
    func setRate(_ rate: Float) {}
    func setVolume(_ volume: Float) {}
}

class VideoFrameQueue {
    private var queue = [VideoFrame]()
    private let capacity: Int
    private let lock = NSLock()

    var isFull: Bool { lock.withLock { queue.count >= capacity } }
    var isEmpty: Bool { lock.withLock { queue.isEmpty } }

    init(capacity: Int) { self.capacity = capacity }

    func enqueue(_ frame: VideoFrame) {
        lock.withLock { if queue.count < capacity { queue.append(frame) } }
    }

    func dequeue() -> VideoFrame? {
        lock.withLock { queue.isEmpty ? nil : queue.removeFirst() }
    }

    func clear() { lock.withLock { queue.removeAll() } }
}

class AudioBufferQueue {
    private var queue = [AudioSamples]()
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) { self.capacity = capacity }

    func enqueue(_ samples: AudioSamples) {
        lock.withLock { if queue.count < capacity { queue.append(samples) } }
    }

    func dequeue() -> AudioSamples? {
        lock.withLock { queue.isEmpty ? nil : queue.removeFirst() }
    }

    func clear() { lock.withLock { queue.removeAll() } }
}
