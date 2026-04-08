import SwiftUI

/// URL 打开面板（支持 HTTP/HTTPS/RTSP/RTMP/HLS）
struct OpenURLView: View {
    @Environment(\.dismiss) var dismiss
    @State private var urlString: String = ""
    @State private var isValid: Bool = true

    let commonProtocols = ["https://", "http://", "rtsp://", "rtmp://"]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("打开网络 URL")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 快捷协议按钮
            HStack(spacing: 6) {
                Text("协议:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                ForEach(commonProtocols, id: \.self) { proto in
                    Button(proto) {
                        if !urlString.hasPrefix(proto) {
                            // 移除已有协议头再加
                            let stripped = urlString.replacingOccurrences(
                                of: #"^[a-zA-Z]+://"#, with: "", options: .regularExpression)
                            urlString = proto + stripped
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 11))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // URL 输入框
            VStack(alignment: .leading, spacing: 4) {
                TextField("请输入 URL，例如 https://example.com/video.mp4", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onChange(of: urlString) { _ in isValid = true }

                if !isValid {
                    Text("请输入有效的 URL")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            // 历史记录（简单实现）
            if let history = recentURLs, !history.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近打开:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(history, id: \.self) { urlStr in
                                Button(urlStr) {
                                    urlString = urlStr
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            }
                        }
                    }
                    .frame(height: min(80, CGFloat(history.count * 22)))
                }
            }

            // 按钮
            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("打开") { openURL() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func openURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            isValid = false
            return
        }
        saveToHistory(trimmed)
        PlayerManager.shared.open(url: url)
        dismiss()
    }

    private var recentURLs: [String]? {
        UserDefaults.standard.stringArray(forKey: "recentURLs")
    }

    private func saveToHistory(_ urlStr: String) {
        var history = UserDefaults.standard.stringArray(forKey: "recentURLs") ?? []
        history.removeAll { $0 == urlStr }
        history.insert(urlStr, at: 0)
        UserDefaults.standard.set(Array(history.prefix(10)), forKey: "recentURLs")
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    var onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .padding(16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
