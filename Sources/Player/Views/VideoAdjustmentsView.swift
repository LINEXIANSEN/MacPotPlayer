import SwiftUI

/// 视频画面调节面板（亮度、对比度、饱和度、色调、翻转等）
struct VideoAdjustmentsView: View {
    @EnvironmentObject var player: PlayerManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("画面调节")
                    .font(.title3.bold())
                Spacer()
                Button(action: resetAll) {
                    Text("重置全部")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // 亮度
                    AdjustmentSlider(
                        label: "亮度",
                        systemImage: "sun.max.fill",
                        value: Binding(
                            get: { Double(player.brightness) },
                            set: { player.setBrightness(Float($0)) }
                        ),
                        range: -1...1,
                        defaultValue: 0
                    )
                    // 对比度
                    AdjustmentSlider(
                        label: "对比度",
                        systemImage: "circle.lefthalf.filled",
                        value: Binding(
                            get: { Double(player.contrast) },
                            set: { player.setContrast(Float($0)) }
                        ),
                        range: 0...2,
                        defaultValue: 1
                    )
                    // 饱和度
                    AdjustmentSlider(
                        label: "饱和度",
                        systemImage: "drop.fill",
                        value: Binding(
                            get: { Double(player.saturation) },
                            set: { player.setSaturation(Float($0)) }
                        ),
                        range: 0...2,
                        defaultValue: 1
                    )

                    Divider()

                    // 比例模式
                    VStack(alignment: .leading, spacing: 8) {
                        Label("画面比例", systemImage: "aspectratio")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                            ForEach(AspectRatioMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue) {
                                    player.setAspectRatio(mode)
                                }
                                .buttonStyle(.bordered)
                                .tint(player.aspectRatio == mode ? .accentColor : .secondary)
                                .controlSize(.small)
                                .font(.system(size: 11))
                            }
                        }
                    }

                    Divider()

                    // AB 循环
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("AB 循环", systemImage: "repeat")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if player.isAbLoopActive {
                                Button("清除", role: .destructive) {
                                    player.clearABLoop()
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: { player.setABLoopStart() }) {
                                VStack(spacing: 2) {
                                    Text("设置 A 点")
                                        .font(.system(size: 12))
                                    if player.isAbLoopActive {
                                        Text(formatTime(player.abLoopStart))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button(action: { player.setABLoopEnd() }) {
                                VStack(spacing: 2) {
                                    Text("设置 B 点")
                                        .font(.system(size: 12))
                                    if player.isAbLoopActive {
                                        Text(formatTime(player.abLoopEnd))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 360, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func resetAll() {
        player.setBrightness(0)
        player.setContrast(1)
        player.setSaturation(1)
        player.setAspectRatio(.fit)
    }

    private func formatTime(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }
}

// MARK: - AdjustmentSlider

struct AdjustmentSlider: View {
    let label: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Button(action: { value = defaultValue }) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("重置")
            }

            HStack(spacing: 8) {
                Text(String(format: "%.1f", range.lowerBound))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                Slider(value: $value, in: range)
                    .tint(.accentColor)

                Text(String(format: "%.1f", range.upperBound))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
            }
        }
    }
}
