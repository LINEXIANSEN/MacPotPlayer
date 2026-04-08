import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var player: PlayerManager
    @Environment(\.dismiss) var dismiss

    private var audioEngine: AudioProcessingEngine { player.audioEngine }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("均衡器")
                    .font(.title3.bold())
                Spacer()
                Toggle("启用", isOn: Binding(
                    get: { audioEngine.isEqualizerEnabled },
                    set: { audioEngine.setEqualizerEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                Text("启用")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // 预设选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EQPreset.allPresets) { preset in
                        Button(preset.name) {
                            audioEngine.applyPreset(preset)
                        }
                        .buttonStyle(.bordered)
                        .tint(audioEngine.presetName == preset.name ? .accentColor : .secondary)
                        .controlSize(.small)
                    }
                    Button("重置") {
                        audioEngine.resetEQ()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            Divider()

            // EQ 频段滑条
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(audioEngine.equalizerBands.enumerated()), id: \.element.id) { idx, band in
                    EQBandSlider(
                        band: band,
                        isEnabled: audioEngine.isEqualizerEnabled
                    ) { gain in
                        audioEngine.setBandGain(gain, at: idx)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 220)

            Divider()

            // 底部：音量标准化
            HStack {
                Toggle("音量标准化 (响度均衡)", isOn: Binding(
                    get: { audioEngine.isNormalizationEnabled },
                    set: { audioEngine.setNormalizationEnabled($0) }
                ))
                .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - EQBandSlider

struct EQBandSlider: View {
    let band: EQBand
    let isEnabled: Bool
    var onChange: (Float) -> Void

    @State private var gain: Float

    init(band: EQBand, isEnabled: Bool, onChange: @escaping (Float) -> Void) {
        self.band = band
        self.isEnabled = isEnabled
        self.onChange = onChange
        self._gain = State(initialValue: band.gain)
    }

    var body: some View {
        VStack(spacing: 4) {
            // dB 值
            Text(gain == 0 ? "0" : String(format: "%+.0f", gain))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(gain > 0 ? .accentColor : gain < 0 ? .red : .secondary)
                .frame(height: 14)

            // 垂直滑条
            GeometryReader { geo in
                ZStack(alignment: .center) {
                    // 轨道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 4)

                    // 已选范围
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isEnabled ? Color.accentColor : Color.secondary)
                        .frame(width: 4, height: abs(CGFloat(gain)) / 24.0 * geo.size.height / 2)
                        .offset(y: CGFloat(gain) > 0
                            ? -abs(CGFloat(gain)) / 24.0 * geo.size.height / 4
                            : abs(CGFloat(gain)) / 24.0 * geo.size.height / 4)

                    // 0线
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 12, height: 1)

                    // 滑块
                    Circle()
                        .fill(isEnabled ? Color.accentColor : Color.secondary)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 2)
                        .offset(y: -(CGFloat(gain) / 24.0) * geo.size.height / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let delta = Float(-value.translation.height / geo.size.height * 48)
                                    gain = max(-24, min(24, band.gain + delta))
                                    onChange(gain)
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 30)

            // 频率标签
            Text(freqLabel(band.frequency))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(height: 12)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
        .onChange(of: band.gain) { newGain in
            gain = newGain
        }
    }

    private func freqLabel(_ hz: Float) -> String {
        if hz >= 1000 { return String(format: "%.0fK", hz / 1000) }
        return "\(Int(hz))"
    }
}
