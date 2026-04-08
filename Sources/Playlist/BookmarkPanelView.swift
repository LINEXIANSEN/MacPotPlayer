import SwiftUI

struct BookmarkPanelView: View {
    @EnvironmentObject var player: PlayerManager
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var editingID: UUID?
    @State private var editLabel: String = ""

    private var currentBookmarks: [Bookmark] {
        guard let url = player.currentItem?.url else { return [] }
        return bookmarkManager.bookmarks(for: url)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("书签")
                    .font(.headline)
                Spacer()
                Button(action: addBookmark) {
                    Label("添加书签", systemImage: "bookmark.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(player.currentItem == nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if currentBookmarks.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无书签")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(currentBookmarks) { bm in
                        BookmarkRow(
                            bookmark: bm,
                            isEditing: editingID == bm.id,
                            editLabel: $editLabel,
                            onJump: {
                                player.seek(to: bm.time)
                            },
                            onEdit: {
                                editingID = bm.id
                                editLabel = bm.label
                            },
                            onSaveEdit: {
                                bookmarkManager.update(id: bm.id, label: editLabel)
                                editingID = nil
                            },
                            onDelete: {
                                bookmarkManager.remove(id: bm.id)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 280, minHeight: 300)
    }

    private func addBookmark() {
        guard let url = player.currentItem?.url else { return }
        bookmarkManager.add(at: player.currentTime, for: url)
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    let isEditing: Bool
    @Binding var editLabel: String
    var onJump: () -> Void
    var onEdit: () -> Void
    var onSaveEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 11))

            // 时间
            Text(formatTime(bookmark.time))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            // 标签
            if isEditing {
                TextField("标签", text: $editLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { onSaveEdit() }

                Button(action: onSaveEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            } else {
                Text(bookmark.label)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) { onJump() }
            }

            Spacer()

            if !isEditing {
                Button(action: onJump) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("跳转到此位置") { onJump() }
            Button("重命名") { onEdit() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }

    private func formatTime(_ t: Double) -> String {
        let s = Int(t)
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}
