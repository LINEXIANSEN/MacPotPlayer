import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: PlayerManager
    @State private var showPlaylist: Bool = false
    @State private var showOpenURLSheet: Bool = false
    @State private var showEqualizer: Bool = false
    @State private var isMouseInWindow: Bool = false
    @State private var controlsHideTimer: Timer?

    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()

            // 视频渲染层
            VideoPlayerView()
                .ignoresSafeArea()

            // 字幕层
            SubtitleOverlayView()

            // 缓冲指示器
            if player.isBuffering {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // 控制面板（鼠标移入显示）
            VStack(spacing: 0) {
                Spacer()
                if isMouseInWindow || !player.isPlaying {
                    PlayerControlsView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isMouseInWindow)

            // 侧边播放列表
            if showPlaylist {
                PlaylistSidebarView()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.move(edge: .trailing))
            }

            // 错误提示
            if let error = player.errorMessage {
                ErrorBannerView(message: error) {
                    player.errorMessage = nil
                }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .background(Color.black)
        .onHover { hovering in
            isMouseInWindow = hovering
            resetControlsTimer()
        }
        .onTapGesture(count: 2) {
            player.toggleFullscreen()
        }
        .onTapGesture {
            player.togglePlayPause()
        }
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    // 捏合缩放调整窗口
                }
        )
        // 触摸板滑动手势
        .onScrollWheel { event in
            if event.deltaY != 0 {
                player.adjustVolume(by: Float(event.deltaY) * 2)
            }
        }
        .onDrop(of: SupportedFormats.uniformTypes, isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePlaylist)) { _ in
            withAnimation { showPlaylist.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOpenURLPanel)) { _ in
            showOpenURLSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showEqualizer)) { _ in
            showEqualizer = true
        }
        .sheet(isPresented: $showOpenURLSheet) {
            OpenURLView()
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { withAnimation { showPlaylist.toggle() } }) {
                    Image(systemName: "list.bullet")
                }
            }
        }
    }

    private func resetControlsTimer() {
        controlsHideTimer?.invalidate()
        if player.isPlaying {
            controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation {
                    isMouseInWindow = false
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls = [URL]()
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if urls.count == 1 {
                PlayerManager.shared.open(url: urls[0])
            } else if urls.count > 1 {
                PlayerManager.shared.openMultiple(urls: urls)
            }
        }

        return !providers.isEmpty
    }
}
