import Foundation

/// 播放进度持久化（记忆播放位置）
final class PlaybackProgressStore {

    static let shared = PlaybackProgressStore()

    private let key = "playback.progress"
    private var store: [String: Double] = [:]

    private init() { load() }

    func save(progress: Double, for url: URL) {
        store[url.absoluteString] = progress
        persist()
    }

    func progress(for url: URL) -> Double {
        store[url.absoluteString] ?? 0
    }

    func remove(for url: URL) {
        store.removeValue(forKey: url.absoluteString)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(store, forKey: key)
    }

    private func load() {
        store = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }
}

// MARK: - RecentFilesManager

final class RecentFilesManager {

    static let shared = RecentFilesManager()

    private let maxCount = 20
    private let key = "recentFiles"
    private(set) var recentItems: [MediaItem] = []

    private init() { load() }

    func add(item: MediaItem) {
        recentItems.removeAll { $0.url == item.url }
        recentItems.insert(item, at: 0)
        if recentItems.count > maxCount { recentItems = Array(recentItems.prefix(maxCount)) }
        persist()
        // 同步给系统 Recent Documents
        NSDocumentController.shared.noteNewRecentDocumentURL(item.url)
    }

    func clear() {
        recentItems.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func persist() {
        let urls = recentItems.map { $0.url }
        if let data = try? JSONEncoder().encode(urls) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let urls = try? JSONDecoder().decode([URL].self, from: data) else { return }
        recentItems = urls.map { MediaItem(url: $0) }
    }
}
