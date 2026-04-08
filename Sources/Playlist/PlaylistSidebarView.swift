import SwiftUI
import UniformTypeIdentifiers

struct PlaylistSidebarView: View {
    @EnvironmentObject var player: PlayerManager
    @State private var searchText: String = ""
    @State private var showSortMenu: Bool = false
    @State private var selectedIDs = Set<UUID>()

    private var playlist: PlaylistManager { player.playlistManager }

    private var filteredItems: [MediaItem] {
        if searchText.isEmpty { return playlist.items }
        return playlist.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("播放列表")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // 循环模式
                Button(action: cycleLoopMode) {
                    Image(systemName: loopIcon)
                        .font(.system(size: 13))
                        .foregroundColor(playlist.loopMode == .none ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .help(playlist.loopMode.rawValue)
                // 随机
                Button(action: { playlist.shuffleEnabled.toggle() }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13))
                        .foregroundColor(playlist.shuffleEnabled ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                // 排序
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) { playlist.sort(by: order) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                // 清空
                Button(action: { playlist.clear() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 列表
            if filteredItems.isEmpty {
                EmptyPlaylistView()
            } else {
                List(selection: $selectedIDs) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                        PlaylistItemRow(
                            item: item,
                            index: idx,
                            isCurrent: playlist.currentIndex == idx
                        )
                        .onTapGesture(count: 2) {
                            playlist.playAt(index: idx)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                        .listRowBackground(
                            playlist.currentIndex == idx
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .contextMenu {
                            Button("播放") { playlist.playAt(index: idx) }
                            Divider()
                            Button("从列表移除", role: .destructive) { playlist.remove(at: idx) }
                        }
                    }
                    .onMove { src, dst in playlist.move(from: src, to: dst) }
                }
                .listStyle(.plain)
            }

            Divider()

            // 底部工具栏
            HStack(spacing: 12) {
                Button(action: addFiles) {
                    Label("添加", systemImage: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Text("\(playlist.items.count) 个文件")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Menu {
                    Button("导出 M3U...") { exportM3U() }
                    Button("导入 M3U...") { importM3U() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Helpers

    private var loopIcon: String {
        switch playlist.loopMode {
        case .none: return "repeat"
        case .one:  return "repeat.1"
        case .all:  return "repeat"
        }
    }

    private func cycleLoopMode() {
        switch playlist.loopMode {
        case .none: playlist.loopMode = .all
        case .all:  playlist.loopMode = .one
        case .one:  playlist.loopMode = .none
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SupportedFormats.videoTypes + SupportedFormats.audioTypes
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            playlist.addAll(items: panel.urls.map { MediaItem(url: $0) })
        }
    }

    private func exportM3U() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "m3u")!]
        panel.nameFieldStringValue = "playlist.m3u"
        if panel.runModal() == .OK, let url = panel.url {
            playlist.exportM3U(to: url)
        }
    }

    private func importM3U() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "m3u")!, UTType(filenameExtension: "m3u8")!]
        if panel.runModal() == .OK, let url = panel.url {
            playlist.importM3U(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.playlist.add(item: MediaItem(url: url))
                    }
                }
            }
        }
        return true
    }
}

// MARK: - PlaylistItemRow

struct PlaylistItemRow: View {
    let item: MediaItem
    let index: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            // 序号 / 播放指示器
            ZStack {
                Text("\(index + 1)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .opacity(isCurrent ? 0 : 1)

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .opacity(isCurrent ? 1 : 0)
            }
            .frame(width: 20)

            // 图标
            Image(systemName: item.isNetwork ? "network" : "film")
                .font(.system(size: 12))
                .foregroundColor(isCurrent ? .accentColor : .secondary)
                .frame(width: 16)

            // 标题
            Text(item.title)
                .font(.system(size: 12))
                .foregroundColor(isCurrent ? .primary : .primary)
                .fontWeight(isCurrent ? .medium : .regular)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

// MARK: - EmptyPlaylistView

struct EmptyPlaylistView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("播放列表为空")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("拖入文件或点击「添加」")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
