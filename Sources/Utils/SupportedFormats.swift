import Foundation
import UniformTypeIdentifiers

enum SupportedFormats {
    static let videoExtensions = [
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
        "ts", "m2ts", "mts", "mpg", "mpeg", "vob", "ogv", "3gp",
        "3g2", "rmvb", "rm", "asf", "divx", "xvid", "hevc", "h264",
        "h265", "av1", "f4v", "swf", "mxf", "dv", "qt"
    ]

    static let audioExtensions = [
        "mp3", "aac", "flac", "wav", "ogg", "opus", "wma", "m4a",
        "aiff", "aif", "alac", "ape", "mka", "dts", "ac3", "eac3",
        "truehd", "wv", "tta", "mpc"
    ]

    static let subtitleExtensions = [
        "srt", "ass", "ssa", "vtt", "sub", "idx", "pgs", "sup",
        "smi", "lrc", "scc"
    ]

    static var videoTypes: [UTType] {
        videoExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static var audioTypes: [UTType] {
        audioExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static var subtitleTypes: [UTType] {
        subtitleExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static var uniformTypes: [UTType] {
        videoTypes + audioTypes
    }

    static func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) || audioExtensions.contains(ext)
    }
}
