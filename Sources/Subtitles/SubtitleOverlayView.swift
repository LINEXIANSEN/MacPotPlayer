import SwiftUI

/// 字幕叠加层视图
struct SubtitleOverlayView: View {
    @EnvironmentObject var player: PlayerManager
    @State private var subtitleText: AttributedString?

    var body: some View {
        VStack {
            Spacer()

            if player.subtitleManager.isEnabled,
               let text = player.subtitleManager.currentSubtitleText {
                SubtitleTextView(text: text)
                    .padding(.horizontal, 32)
                    .padding(.bottom, player.subtitlePositionY > 0 ? player.subtitlePositionY * 200 : 60)
                    .id(text.description) // 强制刷新
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: text.description)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SubtitleTextView: View {
    let text: AttributedString
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        Text(text)
            .font(.system(size: player.subtitleSize, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black, radius: 1, x: 1, y: 1)
            .shadow(color: .black, radius: 1, x: -1, y: -1)
            .shadow(color: .black, radius: 2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.45))
            )
    }
}
