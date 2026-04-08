import Foundation
import AVFoundation
import Accelerate

/// AudioProcessingEngine - 音频处理引擎
/// 提供均衡器、音频标准化、声道映射、音量放大等功能
/// 底层使用 AVAudioEngine + AVAudioUnitEQ

final class AudioProcessingEngine: ObservableObject {

    // MARK: - Published

    @Published var equalizerBands: [EQBand] = EQBand.defaultBands
    @Published var isEqualizerEnabled: Bool = false
    @Published var isNormalizationEnabled: Bool = false
    @Published var presetName: String = "关闭"
    @Published var volume: Float = 1.0

    // MARK: - AVAudio

    private let engine = AVAudioEngine()
    private var eqNode: AVAudioUnitEQ?
    private var playerNode = AVAudioPlayerNode()
    private var timePitchNode = AVAudioUnitTimePitch()
    private var reverb = AVAudioUnitReverb()

    private var currentRate: Float = 1.0

    // MARK: - Init

    init() {
        setupEngine()
    }

    // MARK: - Setup

    private func setupEngine() {
        let eq = AVAudioUnitEQ(numberOfBands: EQBand.defaultBands.count)
        self.eqNode = eq

        engine.attach(playerNode)
        engine.attach(eq)
        engine.attach(timePitchNode)

        // 连接节点链: playerNode -> EQ -> TimePitch -> mainMixerNode
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: eq, format: format)
        engine.connect(eq, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: format)

        updateEQBands()

        do {
            try engine.start()
        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    // MARK: - EQ

    func setEqualizerEnabled(_ enabled: Bool) {
        isEqualizerEnabled = enabled
        eqNode?.globalGain = enabled ? 0 : 0
        updateEQBands()
    }

    func setBandGain(_ gain: Float, at index: Int) {
        guard equalizerBands.indices.contains(index) else { return }
        equalizerBands[index].gain = gain
        updateEQBands()
    }

    private func updateEQBands() {
        guard let eq = eqNode else { return }
        for (i, band) in equalizerBands.enumerated() {
            guard i < eq.bands.count else { break }
            let b = eq.bands[i]
            b.frequency   = band.frequency
            b.gain        = isEqualizerEnabled ? band.gain : 0
            b.bandwidth   = band.bandwidth
            b.filterType  = band.filterType
            b.bypass      = !isEqualizerEnabled
        }
    }

    func applyPreset(_ preset: EQPreset) {
        presetName = preset.name
        equalizerBands = preset.bands
        isEqualizerEnabled = true
        updateEQBands()
    }

    func resetEQ() {
        equalizerBands = EQBand.defaultBands
        isEqualizerEnabled = false
        presetName = "关闭"
        updateEQBands()
    }

    // MARK: - Volume & Rate

    func setVolume(_ v: Float) {
        volume = v
        engine.mainMixerNode.outputVolume = v
    }

    func setRate(_ rate: Float) {
        currentRate = rate
        timePitchNode.rate = rate
        // 保持音调不变（变速不变调）
        timePitchNode.pitch = 0
        timePitchNode.overlap = 8.0
    }

    // MARK: - Normalization

    func setNormalizationEnabled(_ enabled: Bool) {
        isNormalizationEnabled = enabled
        // TODO: 分析音频 RMS，自动调整增益
    }
}

// MARK: - EQBand

struct EQBand: Identifiable {
    let id = UUID()
    var frequency: Float
    var gain: Float       // dB, -24 ~ +24
    var bandwidth: Float  // 八度
    var filterType: AVAudioUnitEQFilterType

    static let defaultBands: [EQBand] = [
        EQBand(frequency:    32, gain: 0, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain: 0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain: 0, bandwidth: 1.0, filterType: .highShelf),
    ]
}

// MARK: - EQ Presets

struct EQPreset: Identifiable {
    let id = UUID()
    let name: String
    let bands: [EQBand]

    static let allPresets: [EQPreset] = [
        .flat,
        .bassBoost,
        .trebleBoost,
        .vocal,
        .rock,
        .pop,
        .jazz,
        .classical,
        .electronic,
        .loudness,
    ]

    static let flat = EQPreset(name: "平坦", bands: EQBand.defaultBands)

    static let bassBoost = EQPreset(name: "重低音增强", bands: [
        EQBand(frequency:    32, gain: 8,  bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain: 6,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain: 4,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain: 2,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain: 0,  bandwidth: 1.0, filterType: .highShelf),
    ])

    static let trebleBoost = EQPreset(name: "高频增强", bands: [
        EQBand(frequency:    32, gain: 0,  bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: 0,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain: 2,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain: 4,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain: 6,  bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain: 8,  bandwidth: 1.0, filterType: .highShelf),
    ])

    static let vocal = EQPreset(name: "人声增强", bands: [
        EQBand(frequency:    32, gain: -2, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain: -2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain:  6, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  6, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  1, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let rock = EQPreset(name: "摇滚", bands: [
        EQBand(frequency:    32, gain:  5, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: -2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: -1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  5, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  4, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let pop = EQPreset(name: "流行", bands: [
        EQBand(frequency:    32, gain:  1, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain:  1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: -1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  2, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let jazz = EQPreset(name: "爵士", bands: [
        EQBand(frequency:    32, gain:  4, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: -1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: -1, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  3, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let classical = EQPreset(name: "古典", bands: [
        EQBand(frequency:    32, gain:  0, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain: -3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain: -6, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let electronic = EQPreset(name: "电子", bands: [
        EQBand(frequency:    32, gain:  6, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  5, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain: -2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain: -2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  3, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  5, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  6, bandwidth: 1.0, filterType: .highShelf),
    ])

    static let loudness = EQPreset(name: "响度", bands: [
        EQBand(frequency:    32, gain:  6, bandwidth: 1.0, filterType: .lowShelf),
        EQBand(frequency:    64, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   125, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   250, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:   500, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  1000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  2000, gain:  0, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  4000, gain:  2, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency:  8000, gain:  4, bandwidth: 1.0, filterType: .parametric),
        EQBand(frequency: 16000, gain:  6, bandwidth: 1.0, filterType: .highShelf),
    ])
}
