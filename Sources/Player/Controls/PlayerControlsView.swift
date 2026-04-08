import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject var player: PlayerManager
    @State private var isDraggingProgress: Bool = false
    @State private var dragProgress: Double = 0
    @State private var showVolumeSlider: Bool = false
    @State private var showSpeedPicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            ProgressBarView(
                progress: isDraggingProgress ? dragProgress : player.currentTime,
                buffered: player.bufferedProgress,
                duration: player.duration,
                isDragging: $isDraggingProgress,
                dragValue: $dragProgress
            ) { newTime in
                player.seek(to: newTime)
            }
            .padding(.horizontal, 12)

            // 控制按钮行
            HStack(spacing: 0) {
                // 左侧控件
                HStack(spacing: 8) {
                    // 播放/暂停
                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)

                    // 上一个
                    Button(action: { player.playPrevious() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)

                    // 下一个
                    Button(action: { player.playNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)

                    // 停止
                    Button(action: { player.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.8))

                    // 音量
                    HStack(spacing: 4) {
                        Button(action: { player.toggleMute() }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 14))
                                .frame(width: 28, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)

                        VolumeSliderView(volume: Binding(
                            get: { Double(player.volume) },
                            set: { player.setVolume(Float($0)) }
                        ))
                        .frame(width: 80)
                    }

                    // 时间标签
                    Text(timeLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.leading, 4)
                }
                .padding(.leading, 12)

                Spacer()

                // 右侧控件
                HStack(spacing: 8) {
                    // 播放速度
                    Menu {
                        ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0], id: \.self) { rate in
                            Button("\(rate.formatted())x") {
                                player.setRate(Float(rate))
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 13))
                            Text("\(player.playbackRate.formatted())x")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)

                    // 字幕按钮
                    Button(action: {
                        NotificationCenter.default.post(name: .showSubtitlePanel, object: nil)
                    }) {
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(player.subtitleManager.isEnabled ? .yellow : .white.opacity(0.7))

                    // 截图
                    Button(action: { player.takeScreenshot() }) {
                        Image(systemName: "camera")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.8))

                    // 360° VR 模式切换
                    Button(action: { player.toggleVRMode() }) {
                        Image(systemName: player.isVRMode ? "view.3d" : "view.3d")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                            .overlay(alignment: .topTrailing) {
                                if player.isVRMode {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 2, y: -2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(player.isVRMode ? .blue : .white.opacity(0.8))
                    .help(player.isVRMode ? "退出 360° 全景模式" : "进入 360° 全景模式")

                    // 画中画
                    Button(action: { player.togglePictureInPicture() }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.8))

                    // 全屏
                    Button(action: { player.toggleFullscreen() }) {
                        Image(systemName: player.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
                .padding(.trailing, 12)
            }
            .frame(height: 52)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var volumeIcon: String {
        if player.isMuted || player.volume == 0 { return "speaker.slash.fill" }
        if player.volume < 0.33 { return "speaker.wave.1.fill" }
        if player.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var timeLabel: String {
        let current = formatTime(player.currentTime)
        let total = formatTime(player.duration)
        return "\(current) / \(total)"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "00:00" }
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let progress: Double
    let buffered: Double
    let duration: Double
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    var onSeek: (Double) -> Void

    @State private var isHovering: Bool = false
    @State private var hoverTime: Double = 0
    @State private var hoverX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: isHovering ? 6 : 3)

                // 已缓冲
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: max(0, geo.size.width * bufferedFraction), height: isHovering ? 6 : 3)

                // 已播放
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, geo.size.width * progressFraction), height: isHovering ? 6 : 3)

                // 拖拽圆点
                if isHovering || isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 2)
                        .offset(x: max(0, geo.size.width * progressFraction - 7))
                }

                // 悬停时间提示
                if isHovering {
                    Text(formatTime(hoverTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(4)
                        .offset(x: clampedTooltipX(hoverX: hoverX, width: geo.size.width))
                        .offset(y: -24)
                }
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        hoverX = value.location.x
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        dragValue = fraction * duration
                        hoverTime = dragValue
                    }
                    .onEnded { value in
                        isDragging = false
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(fraction * duration)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    hoverX = loc.x
                    hoverTime = (loc.x / geo.size.width) * duration
                case .ended:
                    break
                }
            }
        }
        .frame(height: 20)
        .padding(.vertical, 4)
    }

    private var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return (isDragging ? dragValue : progress) / duration
    }

    private var bufferedFraction: Double {
        guard duration > 0 else { return 0 }
        return buffered / duration
    }

    private func clampedTooltipX(hoverX: CGFloat, width: CGFloat) -> CGFloat {
        max(20, min(hoverX - 20, width - 60))
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "00:00" }
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Volume Slider

struct VolumeSliderView: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2.0)
            .tint(.white)
            .help("音量: \(Int(volume * 100))%")
    }
}
