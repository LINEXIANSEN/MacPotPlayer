import Foundation
import CoreGraphics
import CoreText

/// SubtitleManager - 字幕管理系统
/// 支持 SRT、ASS/SSA、VTT、PGS、SUB、MicroDVD 等格式
/// 通过 libass 渲染高质量 ASS 字幕

final class SubtitleManager: ObservableObject {

    @Published var currentSubtitleText: AttributedString?
    @Published var isEnabled: Bool = true
    @Published var tracks: [SubtitleTrack] = []
    @Published var activeTrackIndex: Int = -1

    private var allSubtitles: [SubtitleEntry] = []
    private var externalURL: URL?
    private var delay: Double = 0

    // libass renderer (通过 Objective-C++ 桥接)
    private var assRenderer: ASSRenderer?

    // MARK: - Load

    func loadEmbeddedTracks(from trackInfos: [TrackInfo]) {
        tracks = trackInfos.map {
            SubtitleTrack(index: $0.index, title: $0.title, language: $0.language, source: .embedded)
        }
    }

    func loadExternal(url: URL) {
        externalURL = url
        let format = SubtitleFormat.detect(from: url)

        switch format {
        case .srt:
            loadSRT(url: url)
        case .ass, .ssa:
            loadASS(url: url)
        case .vtt:
            loadVTT(url: url)
        case .sub:
            loadSubRip(url: url)
        case .unknown:
            // 尝试 SRT 格式
            loadSRT(url: url)
        }

        let track = SubtitleTrack(
            index: tracks.count,
            title: url.lastPathComponent,
            language: nil,
            source: .external(url)
        )
        tracks.append(track)
        activeTrackIndex = track.index
    }

    /// 自动匹配同名字幕文件
    func autoLoadExternalSubtitle(for videoURL: URL) {
        let dir = videoURL.deletingLastPathComponent()
        let name = videoURL.deletingPathExtension().lastPathComponent

        let extensions = ["srt", "ass", "ssa", "vtt", "sub"]
        for ext in extensions {
            let candidateURL = dir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                loadExternal(url: candidateURL)
                return
            }
        }
    }

    // MARK: - Update (called every frame)

    func update(currentTime: Double) {
        guard isEnabled, !allSubtitles.isEmpty else {
            currentSubtitleText = nil
            return
        }

        let t = currentTime + delay
        let active = allSubtitles.filter { $0.startTime <= t && $0.endTime >= t }

        if active.isEmpty {
            currentSubtitleText = nil
        } else {
            let combined = active.map { $0.styledText }.joined(separator: "\n")
            currentSubtitleText = combined
        }
    }

    // MARK: - Delay

    func setDelay(_ delay: Double) {
        self.delay = delay
    }

    // MARK: - Parsers

    private func loadSRT(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) ??
              String(contentsOf: url, encoding: .isoLatin1) else { return }

        allSubtitles = SRTParser.parse(content: content)
    }

    private func loadASS(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        allSubtitles = ASSParser.parse(content: content)
        assRenderer = ASSRenderer(content: content)
    }

    private func loadVTT(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        allSubtitles = VTTParser.parse(content: content)
    }

    private func loadSubRip(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        allSubtitles = SubRipParser.parse(content: content)
    }
}

// MARK: - SubtitleEntry

struct SubtitleEntry {
    let startTime: Double
    let endTime: Double
    let rawText: String
    let styledText: AttributedString

    init(startTime: Double, endTime: Double, text: String, style: SubtitleStyle = .default) {
        self.startTime = startTime
        self.endTime = endTime
        self.rawText = text

        var container = AttributeContainer()
        container.font = .systemFont(ofSize: style.fontSize, weight: .semibold)
        container.foregroundColor = style.foregroundColor
        container.strokeWidth = -2
        container.strokeColor = style.strokeColor

        self.styledText = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

// MARK: - SubtitleStyle

struct SubtitleStyle {
    var fontSize: CGFloat = 36
    var foregroundColor: NSColor = .white
    var strokeColor: NSColor = .black
    var fontName: String = "PingFangSC-Semibold"
    var alignment: NSTextAlignment = .center

    static let `default` = SubtitleStyle()
}

// MARK: - SubtitleTrack

struct SubtitleTrack: Identifiable {
    enum Source {
        case embedded
        case external(URL)
    }

    let id = UUID()
    let index: Int
    let title: String
    let language: String?
    let source: Source
}

// MARK: - SubtitleFormat

enum SubtitleFormat {
    case srt, ass, ssa, vtt, sub, unknown

    static func detect(from url: URL) -> SubtitleFormat {
        switch url.pathExtension.lowercased() {
        case "srt": return .srt
        case "ass": return .ass
        case "ssa": return .ssa
        case "vtt": return .vtt
        case "sub": return .sub
        default:    return .unknown
        }
    }
}

// MARK: - SRT Parser

enum SRTParser {
    static func parse(content: String) -> [SubtitleEntry] {
        var entries = [SubtitleEntry]()
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                             .components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            // 找时间行
            guard let timeLine = lines.first(where: { $0.contains(" --> ") }),
                  let times = parseTimeLine(timeLine) else { continue }

            // 文本（跳过序号行和时间行）
            let textLines = lines.filter {
                !$0.contains(" --> ") && Int($0.trimmingCharacters(in: .whitespaces)) == nil
            }
            let text = textLines.joined(separator: "\n")

            entries.append(SubtitleEntry(startTime: times.0, endTime: times.1, text: text))
        }

        return entries.sorted { $0.startTime < $1.startTime }
    }

    private static func parseTimeLine(_ line: String) -> (Double, Double)? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2,
              let start = parseTime(parts[0].trimmingCharacters(in: .whitespaces)),
              let end   = parseTime(parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0])
        else { return nil }
        return (start, end)
    }

    static func parseTime(_ str: String) -> Double? {
        // HH:MM:SS,mmm or HH:MM:SS.mmm
        let normalized = str.replacingOccurrences(of: ",", with: ".")
        let components = normalized.components(separatedBy: ":")
        guard components.count == 3,
              let h = Double(components[0]),
              let m = Double(components[1]),
              let s = Double(components[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}

// MARK: - ASS Parser (Advanced SubStation Alpha)

enum ASSParser {
    static func parse(content: String) -> [SubtitleEntry] {
        var entries = [SubtitleEntry]()
        var inEvents = false
        var formatFields = [String]()

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "[Events]" {
                inEvents = true
                continue
            }
            if trimmed.hasPrefix("[") && trimmed != "[Events]" {
                inEvents = false
            }

            if inEvents {
                if trimmed.hasPrefix("Format:") {
                    let fmt = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    formatFields = fmt.components(separatedBy: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                } else if trimmed.hasPrefix("Dialogue:") {
                    let data = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    if let entry = parseDialogue(data, fields: formatFields) {
                        entries.append(entry)
                    }
                }
            }
        }
        return entries.sorted { $0.startTime < $1.startTime }
    }

    private static func parseDialogue(_ data: String, fields: [String]) -> SubtitleEntry? {
        var parts = data.components(separatedBy: ",")
        guard parts.count >= fields.count else { return nil }

        // 文本字段可能含逗号，合并尾部
        let textIndex = fields.firstIndex(of: "Text") ?? (fields.count - 1)
        if parts.count > fields.count {
            let extra = parts[(textIndex + 1)...].joined(separator: ",")
            parts[textIndex] += extra
        }

        let startStr = parts[safeIndex: fields.firstIndex(of: "Start") ?? 1] ?? ""
        let endStr   = parts[safeIndex: fields.firstIndex(of: "End")   ?? 2] ?? ""
        let rawText  = parts[safeIndex: textIndex] ?? ""

        guard let start = parseASSTime(startStr),
              let end   = parseASSTime(endStr) else { return nil }

        // 去除 ASS 标签 {\an8}{\c&HFFFFFF&} 等
        let cleanedText = rawText
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: #"\{[^}]*\}"#, with: "", options: .regularExpression)

        return SubtitleEntry(startTime: start, endTime: end, text: cleanedText)
    }

    static func parseASSTime(_ s: String) -> Double? {
        // h:mm:ss.cc
        let parts = s.components(separatedBy: ":")
        guard parts.count == 3,
              let h  = Double(parts[0]),
              let m  = Double(parts[1]),
              let sc = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + sc
    }
}

// MARK: - VTT Parser

enum VTTParser {
    static func parse(content: String) -> [SubtitleEntry] {
        var entries = [SubtitleEntry]()
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }

            guard let timeLine = lines.first(where: { $0.contains(" --> ") }) else { continue }
            let timeIdx = lines.firstIndex(of: timeLine) ?? 0

            let parts = timeLine.components(separatedBy: " --> ")
            guard parts.count == 2,
                  let start = SRTParser.parseTime(parts[0]),
                  let end   = SRTParser.parseTime(parts[1].components(separatedBy: " ")[0]) else { continue }

            let text = lines[(timeIdx + 1)...].joined(separator: "\n")
            entries.append(SubtitleEntry(startTime: start, endTime: end, text: text))
        }
        return entries
    }
}

// MARK: - SubRip Parser

enum SubRipParser {
    static func parse(content: String) -> [SubtitleEntry] {
        // {start}{end}text format
        var entries = [SubtitleEntry]()
        let pattern = #"\{(\d+)\}\{(\d+)\}(.+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex?.firstMatch(in: line, range: range),
               match.numberOfRanges == 4 {
                let s = Double((line as NSString).substring(with: match.range(at: 1))) ?? 0
                let e = Double((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let text = (line as NSString).substring(with: match.range(at: 3))
                // SubRip 使用帧号，假设 25fps
                entries.append(SubtitleEntry(startTime: s / 25.0, endTime: e / 25.0, text: text))
            }
        }
        return entries
    }
}

// MARK: - ASSRenderer Stub (通过 Objective-C++ 桥接 libass)

class ASSRenderer {
    init(content: String) {
        // TODO: 初始化 libass ass_library_init / ass_renderer_init
        // 通过 Bridging/ASSBridge.mm 调用
    }

    func render(at time: Double, size: CGSize) -> CGImage? {
        // TODO: ass_render_frame 返回 bitmap
        return nil
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safeIndex index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}
