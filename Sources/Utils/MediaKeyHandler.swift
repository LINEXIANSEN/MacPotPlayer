import Foundation
import AppKit

/// MediaKeyHandler - 响应系统媒体键（播放/暂停/上一首/下一首）
final class MediaKeyHandler {

    static let shared = MediaKeyHandler()
    private var eventMonitor: Any?

    private init() {}

    func startMonitoring() {
        // 监听键盘媒体键事件
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleMediaKey(event: event)
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleMediaKey(event: NSEvent) {
        guard event.type == .systemDefined && event.subtype.rawValue == 8 else { return }
        let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyDown = (keyFlags & 0xFF00) == 0xA400 || (keyFlags & 0x1) == 0x0

        guard keyDown else { return }

        DispatchQueue.main.async {
            switch keyCode {
            case NX_KEYTYPE_PLAY:
                PlayerManager.shared.togglePlayPause()
            case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                PlayerManager.shared.playNext()
            case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                PlayerManager.shared.playPrevious()
            default:
                break
            }
        }
    }
}

private let NX_KEYTYPE_PLAY:     Int = 16
private let NX_KEYTYPE_NEXT:     Int = 17
private let NX_KEYTYPE_PREVIOUS: Int = 18
private let NX_KEYTYPE_FAST:     Int = 19
private let NX_KEYTYPE_REWIND:   Int = 20
