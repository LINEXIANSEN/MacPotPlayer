import SwiftUI

struct MacPotPlayerCommands: Commands {
    var body: some Commands {
        // 文件菜单
        CommandGroup(replacing: .newItem) {
            Button("打开文件...") {
                PlayerManager.shared.showOpenFilePanel()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("打开 URL...") {
                PlayerManager.shared.showOpenURLPanel()
            }
            .keyboardShortcut("u", modifiers: .command)

            Divider()

            Button("打开播放列表") {
                NotificationCenter.default.post(name: .togglePlaylist, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)
        }

        // 播放菜单
        CommandMenu("播放") {
            Button("播放 / 暂停") {
                PlayerManager.shared.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("停止") {
                PlayerManager.shared.stop()
            }
            .keyboardShortcut(".", modifiers: .command)

            Divider()

            Button("向前跳转 5 秒") {
                PlayerManager.shared.seek(by: 5)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            Button("向后跳转 5 秒") {
                PlayerManager.shared.seek(by: -5)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button("向前跳转 1 分钟") {
                PlayerManager.shared.seek(by: 60)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("向后跳转 1 分钟") {
                PlayerManager.shared.seek(by: -60)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Divider()

            Menu("播放速度") {
                Button("0.25x") { PlayerManager.shared.setRate(0.25) }
                Button("0.5x")  { PlayerManager.shared.setRate(0.5) }
                Button("0.75x") { PlayerManager.shared.setRate(0.75) }
                Button("1.0x (正常)") { PlayerManager.shared.setRate(1.0) }
                Button("1.25x") { PlayerManager.shared.setRate(1.25) }
                Button("1.5x")  { PlayerManager.shared.setRate(1.5) }
                Button("2.0x")  { PlayerManager.shared.setRate(2.0) }
                Button("4.0x")  { PlayerManager.shared.setRate(4.0) }
            }

            Divider()

            Button("上一个文件") {
                PlayerManager.shared.playPrevious()
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("下一个文件") {
                PlayerManager.shared.playNext()
            }
            .keyboardShortcut("]", modifiers: .command)
        }

        // 视频菜单
        CommandMenu("视频") {
            Menu("比例") {
                Button("原始") { PlayerManager.shared.setAspectRatio(.original) }
                Button("4:3")  { PlayerManager.shared.setAspectRatio(.r4x3) }
                Button("16:9") { PlayerManager.shared.setAspectRatio(.r16x9) }
                Button("16:10"){ PlayerManager.shared.setAspectRatio(.r16x10) }
                Button("21:9") { PlayerManager.shared.setAspectRatio(.r21x9) }
                Button("适应窗口") { PlayerManager.shared.setAspectRatio(.fit) }
            }

            Divider()

            Button("截图") {
                PlayerManager.shared.takeScreenshot()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("连续截图...") {
                PlayerManager.shared.startBurstScreenshot()
            }

            Divider()

            Button("全屏") {
                PlayerManager.shared.toggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("画中画") {
                PlayerManager.shared.togglePictureInPicture()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }

        // 音频菜单
        CommandMenu("音频") {
            Button("增加音量") {
                PlayerManager.shared.adjustVolume(by: 5)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("减少音量") {
                PlayerManager.shared.adjustVolume(by: -5)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("静音") {
                PlayerManager.shared.toggleMute()
            }
            .keyboardShortcut("m", modifiers: .command)

            Divider()

            Button("均衡器...") {
                NotificationCenter.default.post(name: .showEqualizer, object: nil)
            }
        }

        // 字幕菜单
        CommandMenu("字幕") {
            Button("加载字幕文件...") {
                PlayerManager.shared.loadSubtitleFile()
            }

            Divider()

            Button("字幕上移") {
                PlayerManager.shared.adjustSubtitlePosition(by: 5)
            }

            Button("字幕下移") {
                PlayerManager.shared.adjustSubtitlePosition(by: -5)
            }

            Divider()

            Button("增大字幕字号") {
                PlayerManager.shared.adjustSubtitleSize(by: 2)
            }

            Button("减小字幕字号") {
                PlayerManager.shared.adjustSubtitleSize(by: -2)
            }

            Divider()

            Button("字幕同步 +0.5s") {
                PlayerManager.shared.adjustSubtitleDelay(by: 0.5)
            }

            Button("字幕同步 -0.5s") {
                PlayerManager.shared.adjustSubtitleDelay(by: -0.5)
            }
        }
    }
}
