import Foundation
import Combine

/// PlaylistManager - 播放列表管理
/// 支持多种排序方式、随机播放、循环模式

final class PlaylistManager: ObservableObject {

    @Published var items: [MediaItem] = []
    @Published var currentIndex: Int = -1
    @Published var shuffleEnabled: Bool = false
    @Published var loopMode: LoopMode = .none
    @Published var sortOrder: SortOrder = .addedOrder

    private var shuffleHistory: [Int] = []

    // MARK: - Current

    var currentItem: MediaItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    // MARK: - Add / Remove

    func addAndPlay(item: MediaItem) {
        if let idx = items.firstIndex(where: { $0.url == item.url }) {
            currentIndex = idx
        } else {
            items.append(item)
            currentIndex = items.count - 1
        }
    }

    func replace(items: [MediaItem]) {
        self.items = items
        currentIndex = items.isEmpty ? -1 : 0
    }

    func add(item: MediaItem) {
        if !items.contains(where: { $0.url == item.url }) {
            items.append(item)
        }
    }

    func addAll(items: [MediaItem]) {
        for item in items { add(item: item) }
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        if currentIndex >= items.count {
            currentIndex = items.count - 1
        }
    }

    func clear() {
        items.removeAll()
        currentIndex = -1
        shuffleHistory.removeAll()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Navigation

    func moveNext() {
        guard !items.isEmpty else { return }

        if shuffleEnabled {
            moveNextShuffle()
        } else {
            switch loopMode {
            case .none:
                if currentIndex < items.count - 1 {
                    currentIndex += 1
                }
            case .one:
                // 保持当前，由 PlayerManager 处理重播
                break
            case .all:
                currentIndex = (currentIndex + 1) % items.count
            }
        }
    }

    func movePrevious() {
        guard !items.isEmpty else { return }

        if shuffleEnabled {
            movePreviousShuffle()
        } else {
            if currentIndex > 0 {
                currentIndex -= 1
            } else if loopMode == .all {
                currentIndex = items.count - 1
            }
        }
    }

    func playAt(index: Int) {
        guard items.indices.contains(index) else { return }
        currentIndex = index
    }

    private func moveNextShuffle() {
        let remaining = (0..<items.count).filter { !shuffleHistory.contains($0) && $0 != currentIndex }
        if remaining.isEmpty {
            shuffleHistory.removeAll()
            if loopMode == .all {
                let next = Int.random(in: 0..<items.count)
                currentIndex = next
            }
            return
        }
        let next = remaining.randomElement()!
        shuffleHistory.append(currentIndex)
        currentIndex = next
    }

    private func movePreviousShuffle() {
        if let last = shuffleHistory.last {
            shuffleHistory.removeLast()
            currentIndex = last
        }
    }

    // MARK: - Sort

    func sort(by order: SortOrder) {
        sortOrder = order
        let current = currentItem
        switch order {
        case .addedOrder: break
        case .nameAsc:    items.sort { $0.title < $1.title }
        case .nameDesc:   items.sort { $0.title > $1.title }
        }
        if let item = current {
            currentIndex = items.firstIndex(where: { $0.url == item.url }) ?? -1
        }
    }

    // MARK: - Session Persistence

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: "playlist.session"),
              let session = try? JSONDecoder().decode(PlaylistSession.self, from: data) else { return }

        items = session.items.map { MediaItem(url: $0) }
        currentIndex = session.currentIndex
    }

    func saveSession() {
        let session = PlaylistSession(
            items: items.map { $0.url },
            currentIndex: currentIndex
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "playlist.session")
        }
    }

    // MARK: - Export / Import

    func exportM3U(to url: URL) {
        var lines = ["#EXTM3U"]
        for item in items {
            lines.append("#EXTINF:-1,\(item.title)")
            lines.append(item.url.absoluteString)
        }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func importM3U(from url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        var newItems = [MediaItem]()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            if let u = URL(string: trimmed) ?? URL(fileURLWithPath: trimmed) as URL? {
                newItems.append(MediaItem(url: u))
            }
        }
        addAll(items: newItems)
    }
}

// MARK: - Supporting Types

enum LoopMode: String, CaseIterable {
    case none = "不循环"
    case one  = "单曲循环"
    case all  = "列表循环"

    var icon: String {
        switch self {
        case .none: return "repeat"
        case .one:  return "repeat.1"
        case .all:  return "repeat"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case addedOrder = "添加顺序"
    case nameAsc    = "名称升序"
    case nameDesc   = "名称降序"
}

private struct PlaylistSession: Codable {
    let items: [URL]
    let currentIndex: Int
}
