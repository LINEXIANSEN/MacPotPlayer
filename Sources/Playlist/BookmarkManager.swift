import Foundation
import Combine

/// BookmarkManager - 书签 & 章节管理
final class BookmarkManager: ObservableObject {

    static let shared = BookmarkManager()

    @Published var bookmarks: [Bookmark] = []

    private let storageKey = "bookmarks.v1"

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(at time: Double, for url: URL, label: String? = nil) {
        let bm = Bookmark(
            mediaURL: url,
            time: time,
            label: label ?? formatTime(time),
            createdAt: Date()
        )
        bookmarks.append(bm)
        save()
    }

    func remove(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func update(id: UUID, label: String) {
        if let idx = bookmarks.firstIndex(where: { $0.id == id }) {
            bookmarks[idx].label = label
            save()
        }
    }

    func bookmarks(for url: URL) -> [Bookmark] {
        bookmarks.filter { $0.mediaURL == url }.sorted { $0.time < $1.time }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        bookmarks = decoded
    }

    private func formatTime(_ t: Double) -> String {
        let s = Int(t)
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Bookmark Model

struct Bookmark: Identifiable, Codable {
    var id: UUID = UUID()
    let mediaURL: URL
    var time: Double
    var label: String
    let createdAt: Date
}
