import SwiftUI
import AVFoundation
import Metal
import MetalKit

/// VideoPlayerView - 视频渲染容器
/// 自动根据播放内容切换普通渲染（MTKView）和 360° 全景渲染（VRPlayerView）
struct VideoPlayerView: View {

    @EnvironmentObject var player: PlayerManager

    var body: some View {
        Group {
            if player.isVRMode {
                VRPlayerView(camera: player.vrCamera)
                    .environmentObject(player)
                    .overlay(alignment: .topTrailing) {
                        VRHUDOverlay(camera: player.vrCamera)
                    }
            } else {
                FlatVideoPlayerView()
                    .environmentObject(player)
            }
        }
    }
}

// MARK: - VR HUD 叠加层（视角信息 + 重置按钮）

private struct VRHUDOverlay: View {
    @ObservedObject var camera: VRCameraController

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "view.3d")
                    .foregroundStyle(.white)
                Text("360°")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())

            Text(String(format: "FOV %.0f°  H %.0f°  V %.0f°",
                        camera.fov, camera.yaw, camera.pitch))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.4), in: Capsule())

            Button {
                camera.reset()
            } label: {
                Label("复位视角", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(12)
    }
}

// MARK: - FlatVideoPlayerView（原 VideoPlayerView 逻辑，重命名）

/// FlatVideoPlayerView - Metal 渲染的普通视频画面
struct FlatVideoPlayerView: NSViewRepresentable {

    @EnvironmentObject var player: PlayerManager

    func makeCoordinator() -> Coordinator {
        Coordinator(player: player)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 120 // ProMotion 支持
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.coordinator.setup(view: view)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.updateAspectRatio(player.aspectRatio)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        weak var player: PlayerManager?
        private var renderer: MetalVideoRenderer?
        private var currentAspectRatio: AspectRatioMode = .fit
        private var nativeVideoSize: CGSize = CGSize(width: 1920, height: 1080)

        init(player: PlayerManager) {
            self.player = player
            super.init()

            // 监听新帧
            player.engine?.onFrameReady = { [weak self] pixelBuffer in
                self?.renderer?.update(pixelBuffer: pixelBuffer)
                self?.extractVideoSize(from: pixelBuffer)
            }
        }

        func setup(view: MTKView) {
            guard let device = view.device else { return }
            renderer = MetalVideoRenderer(device: device)
        }

        func updateAspectRatio(_ mode: AspectRatioMode) {
            currentAspectRatio = mode
        }

        private func extractVideoSize(from buffer: CVPixelBuffer) {
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            nativeVideoSize = CGSize(width: width, height: height)
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.resize(to: size)
        }

        func draw(in view: MTKView) {
            guard let renderer,
                  let drawable = view.currentDrawable,
                  let passDescriptor = view.currentRenderPassDescriptor else { return }

            let viewSize = view.drawableSize
            let destRect = computeDestRect(videoSize: nativeVideoSize, viewSize: viewSize)

            renderer.render(
                passDescriptor: passDescriptor,
                drawable: drawable,
                destRect: destRect
            )
        }

        private func computeDestRect(videoSize: CGSize, viewSize: CGSize) -> CGRect {
            switch currentAspectRatio {
            case .fill:
                return CGRect(origin: .zero, size: viewSize)

            case .original:
                let x = (viewSize.width - videoSize.width) / 2
                let y = (viewSize.height - videoSize.height) / 2
                return CGRect(x: x, y: y, width: videoSize.width, height: videoSize.height)

            case .fit, .r4x3, .r16x9, .r16x10, .r21x9, .r185x1, .r235x1:
                let ratio = currentAspectRatio.ratio ?? (videoSize.width / videoSize.height)
                return aspectFitRect(ratio: ratio, in: viewSize)
            }
        }

        private func aspectFitRect(ratio: CGFloat, in size: CGSize) -> CGRect {
            let viewRatio = size.width / size.height
            var w, h: CGFloat
            if viewRatio > ratio {
                h = size.height
                w = h * ratio
            } else {
                w = size.width
                h = w / ratio
            }
            let x = (size.width - w) / 2
            let y = (size.height - h) / 2
            return CGRect(x: x, y: y, width: w, height: h)
        }
    }
}

// MARK: - MetalVideoRenderer

class MetalVideoRenderer {
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var currentTexture: MTLTexture?
    private var viewportSize: CGSize = .zero

    // 滤镜参数
    private var brightness: Float = 0
    private var contrast: Float = 1
    private var saturation: Float = 1

    init(device: MTLDevice) {
        self.device = device
        setup()
    }

    private func setup() {
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        setupPipeline()
    }

    private func setupPipeline() {
        let vertexShader = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertex_shader(
            uint vid [[vertex_id]],
            constant float4 *vertices [[buffer(0)]],
            constant float2 *texCoords [[buffer(1)]])
        {
            VertexOut out;
            out.position = vertices[vid];
            out.texCoord = texCoords[vid];
            return out;
        }
        """

        let fragmentShader = """
        #include <metal_stdlib>
        using namespace metal;

        struct FilterParams {
            float brightness;
            float contrast;
            float saturation;
        };

        fragment float4 fragment_shader(
            VertexOut in [[stage_in]],
            texture2d<float> texture [[texture(0)]],
            constant FilterParams &params [[buffer(0)]])
        {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            float4 color = texture.sample(textureSampler, in.texCoord);

            // 亮度
            color.rgb += params.brightness;

            // 对比度
            color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;

            // 饱和度
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            color.rgb = mix(float3(gray), color.rgb, params.saturation);

            return saturate(color);
        }
        """

        do {
            let library = try device.makeLibrary(source: vertexShader + fragmentShader, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_shader")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_shader")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Metal pipeline error: \(error)")
        }
    }

    func update(pixelBuffer: CVPixelBuffer) {
        guard let cache = textureCache else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var textureRef: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width, height,
            0,
            &textureRef
        )

        if let ref = textureRef {
            currentTexture = CVMetalTextureGetTexture(ref)
        }
    }

    func resize(to size: CGSize) {
        viewportSize = size
    }

    func setFilter(brightness: Float, contrast: Float, saturation: Float) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
    }

    func render(passDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable, destRect: CGRect) {
        guard let commandQueue,
              let pipeline = pipelineState,
              let texture = currentTexture,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        encoder.setRenderPipelineState(pipeline)

        // 顶点坐标（归一化设备坐标）
        let vw = viewportSize.width
        let vh = viewportSize.height
        let x0 = Float(destRect.minX / vw * 2 - 1)
        let x1 = Float(destRect.maxX / vw * 2 - 1)
        let y0 = Float(1 - destRect.maxY / vh * 2)
        let y1 = Float(1 - destRect.minY / vh * 2)

        var vertices: [Float] = [
            x0, y0, 0, 1,
            x1, y0, 0, 1,
            x0, y1, 0, 1,
            x1, y1, 0, 1
        ]
        var texCoords: [Float] = [
            0, 1,  1, 1,  0, 0,  1, 0
        ]

        encoder.setVertexBytes(&vertices, length: vertices.count * 4, index: 0)
        encoder.setVertexBytes(&texCoords, length: texCoords.count * 4, index: 1)

        struct FilterParams { var brightness: Float; var contrast: Float; var saturation: Float }
        var params = FilterParams(brightness: brightness, contrast: contrast, saturation: saturation)
        encoder.setFragmentBytes(&params, length: MemoryLayout<FilterParams>.size, index: 0)
        encoder.setFragmentTexture(texture, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
