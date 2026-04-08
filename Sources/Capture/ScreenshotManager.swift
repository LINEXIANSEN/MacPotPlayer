import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// ScreenshotManager - 截图 & 连续截图管理
final class ScreenshotManager {

    private var burstTimer: Timer?
    private var burstCount: Int = 0

    // MARK: - Single Screenshot

    func save(image: CGImage) {
        let url = generateURL(ext: "png")
        saveImage(image, to: url)
        showNotification(url: url)
    }

    // MARK: - Burst Screenshot

    func startBurst(engine: FFmpegPlayer, interval: Double = 1.0, maxCount: Int = 30) {
        stopBurst()
        burstCount = 0

        burstTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            engine.captureFrame { image in
                let url = self.generateURL(ext: "png", suffix: "_burst_\(self.burstCount)")
                self.saveImage(image, to: url)
                self.burstCount += 1
                if self.burstCount >= maxCount {
                    self.stopBurst()
                }
            }
        }
    }

    func stopBurst() {
        burstTimer?.invalidate()
        burstTimer = nil
    }

    // MARK: - Helpers

    private func generateURL(ext: String, suffix: String = "") -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timeStr = formatter.string(from: Date())

        let dir = screenshotDirectory()
        let filename = "MacPotPlayer_\(timeStr)\(suffix).\(ext)"
        return dir.appendingPathComponent(filename)
    }

    private func screenshotDirectory() -> URL {
        let prefs = PreferencesManager.shared
        let dir: URL

        if let custom = prefs.screenshotFolder {
            dir = custom
        } else {
            // 默认保存到图片库
            dir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("MacPotPlayer")
        }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveImage(_ image: CGImage, to url: URL) {
        let format = PreferencesManager.shared.screenshotFormat

        switch format {
        case .png:
            savePNG(image, to: url)
        case .jpg:
            let jpgURL = url.deletingPathExtension().appendingPathExtension("jpg")
            saveJPEG(image, to: jpgURL)
        case .bmp:
            let bmpURL = url.deletingPathExtension().appendingPathExtension("bmp")
            saveBMP(image, to: bmpURL)
        }
    }

    private func savePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func saveJPEG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    private func saveBMP(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "com.microsoft.bmp" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func showNotification(url: URL) {
        DispatchQueue.main.async {
            // 在状态栏显示截图通知
            NotificationCenter.default.post(name: .screenshotTaken, object: url)
        }
    }
}

// MARK: - Screenshot Format

enum ScreenshotFormat: String, CaseIterable {
    case png = "PNG"
    case jpg = "JPEG"
    case bmp = "BMP"
}
