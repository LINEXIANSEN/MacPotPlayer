import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var selectedTab: PrefTab = .playback

    enum PrefTab: String, CaseIterable {
        case playback  = "播放"
        case subtitle  = "字幕"
        case audio     = "音频"
        case screenshot = "截图"
        case interface = "界面"
        case network   = "网络"
        case about     = "关于"

        var icon: String {
            switch self {
            case .playback:   return "play.circle"
            case .subtitle:   return "captions.bubble"
            case .audio:      return "speaker.wave.3"
            case .screenshot: return "camera"
            case .interface:  return "macwindow"
            case .network:    return "network"
            case .about:      return "info.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PlaybackPrefsView().tabItem {
                Label(PrefTab.playback.rawValue, systemImage: PrefTab.playback.icon)
            }.tag(PrefTab.playback)

            SubtitlePrefsView().tabItem {
                Label(PrefTab.subtitle.rawValue, systemImage: PrefTab.subtitle.icon)
            }.tag(PrefTab.subtitle)

            AudioPrefsView().tabItem {
                Label(PrefTab.audio.rawValue, systemImage: PrefTab.audio.icon)
            }.tag(PrefTab.audio)

            ScreenshotPrefsView().tabItem {
                Label(PrefTab.screenshot.rawValue, systemImage: PrefTab.screenshot.icon)
            }.tag(PrefTab.screenshot)

            InterfacePrefsView().tabItem {
                Label(PrefTab.interface.rawValue, systemImage: PrefTab.interface.icon)
            }.tag(PrefTab.interface)

            NetworkPrefsView().tabItem {
                Label(PrefTab.network.rawValue, systemImage: PrefTab.network.icon)
            }.tag(PrefTab.network)

            AboutView().tabItem {
                Label(PrefTab.about.rawValue, systemImage: PrefTab.about.icon)
            }.tag(PrefTab.about)
        }
        .frame(width: 560, height: 420)
        .onDisappear { preferences.save() }
    }
}

// MARK: - Playback Prefs
struct PlaybackPrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("播放行为") {
                Picker("循环模式", selection: $prefs.loopMode) {
                    ForEach(LoopMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("记忆播放进度", isOn: $prefs.rememberPosition)
                Toggle("自动播放下一个", isOn: $prefs.autoPlayNext)
                Toggle("启用硬件解码", isOn: $prefs.hardwareDecoding)
            }
            Section("默认值") {
                HStack {
                    Text("默认播放速度")
                    Spacer()
                    Stepper("\(prefs.defaultRate.formatted())x",
                            value: $prefs.defaultRate, in: 0.25...4.0, step: 0.25)
                }
                HStack {
                    Text("最大音量")
                    Spacer()
                    Stepper("\(Int(prefs.volumeMax * 100))%",
                            value: $prefs.volumeMax, in: 1.0...4.0, step: 0.5)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Subtitle Prefs
struct SubtitlePrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("字幕设置") {
                Toggle("自动加载同名字幕", isOn: $prefs.autoLoadSubtitle)
                HStack {
                    Text("字幕字号")
                    Spacer()
                    Stepper("\(Int(prefs.subtitleFontSize))pt",
                            value: $prefs.subtitleFontSize, in: 12...120, step: 2)
                }
                HStack {
                    Text("优先字幕语言")
                    Spacer()
                    TextField("zh / en / ja ...", text: $prefs.subtitlePreferLanguage)
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Section("背景") {
                HStack {
                    Text("字幕背景透明度")
                    Spacer()
                    Slider(value: $prefs.subtitleBgOpacity, in: 0...1)
                        .frame(width: 150)
                    Text("\(Int(prefs.subtitleBgOpacity * 100))%")
                        .frame(width: 36)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Audio Prefs
struct AudioPrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("音频") {
                Toggle("音量标准化（响度均衡）", isOn: $prefs.normalizeAudio)
                HStack {
                    Text("默认音量")
                    Spacer()
                    Slider(value: $prefs.defaultVolume, in: 0...2)
                        .frame(width: 150)
                    Text("\(Int(prefs.defaultVolume * 100))%")
                        .frame(width: 36)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Screenshot Prefs
struct ScreenshotPrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("截图格式") {
                Picker("格式", selection: $prefs.screenshotFormat) {
                    ForEach(ScreenshotFormat.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("保存位置") {
                HStack {
                    Text(prefs.screenshotFolder?.path ?? "图片 / MacPotPlayer")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("更改...") { chooseFolder() }
                    if prefs.screenshotFolder != nil {
                        Button("重置") { prefs.screenshotFolder = nil }
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "选择"
        if panel.runModal() == .OK { prefs.screenshotFolder = panel.url }
    }
}

// MARK: - Interface Prefs
struct InterfacePrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $prefs.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("行为") {
                Toggle("窗口总在最前", isOn: $prefs.alwaysOnTop)
                Toggle("显示剩余时间", isOn: $prefs.showRemainingTime)
                HStack {
                    Text("控制栏隐藏延迟")
                    Spacer()
                    Stepper("\(Int(prefs.hideControlsDelay))秒",
                            value: $prefs.hideControlsDelay, in: 1...10, step: 1)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Network Prefs
struct NetworkPrefsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("网络") {
                HStack {
                    Text("缓冲时长")
                    Spacer()
                    Stepper("\(Int(prefs.bufferSizeSeconds))秒",
                            value: $prefs.bufferSizeSeconds, in: 1...60, step: 1)
                }
                HStack {
                    Text("User-Agent")
                    Spacer()
                    TextField("User-Agent", text: $prefs.userAgent)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("MacPotPlayer")
                .font(.largeTitle.bold())

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("一款功能全面的 macOS 视频播放器\n基于 Swift + FFmpeg + AVFoundation")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.system(size: 13))

            Divider()

            Text("© 2026 MacPotPlayer. All rights reserved.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
