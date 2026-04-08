import SwiftUI
import Metal
import MetalKit
import simd

/// VRPlayerView - 360° 全景视频 Metal 渲染视图
/// 将等距柱状投影（Equirectangular）视频帧映射到球体内部，实现沉浸式全景播放
struct VRPlayerView: NSViewRepresentable {

    @EnvironmentObject var player: PlayerManager
    @ObservedObject var camera: VRCameraController

    func makeCoordinator() -> Coordinator {
        Coordinator(player: player, camera: camera)
    }

    func makeNSView(context: Context) -> VRMTKView {
        let view = VRMTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 120
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.vrCamera = camera
        context.coordinator.setup(view: view)
        return view
    }

    func updateNSView(_ nsView: VRMTKView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        weak var player: PlayerManager?
        weak var camera: VRCameraController?
        private var renderer: VRSphereRenderer?

        init(player: PlayerManager, camera: VRCameraController) {
            self.player = player
            self.camera = camera
            super.init()
            player.engine?.onFrameReady = { [weak self] pixelBuffer in
                self?.renderer?.update(pixelBuffer: pixelBuffer)
            }
        }

        func setup(view: MTKView) {
            guard let device = view.device else { return }
            renderer = VRSphereRenderer(device: device)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer,
                  let camera,
                  let drawable = view.currentDrawable,
                  let passDescriptor = view.currentRenderPassDescriptor else { return }
            let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
            let vpMatrix = camera.viewProjectionMatrix(aspectRatio: aspect)
            renderer.render(passDescriptor: passDescriptor, drawable: drawable, vpMatrix: vpMatrix)
        }
    }
}

// MARK: - VRMTKView（捕获鼠标和滚轮事件）

class VRMTKView: MTKView {
    weak var vrCamera: VRCameraController?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        vrCamera?.beginDrag(at: loc)
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        vrCamera?.updateDrag(to: loc)
    }

    override func mouseUp(with event: NSEvent) {
        vrCamera?.endDrag()
    }

    override func scrollWheel(with event: NSEvent) {
        vrCamera?.zoom(by: Float(event.deltaY))
    }

    override func magnify(with event: NSEvent) {
        // 触摸板捏合缩放
        vrCamera?.zoom(by: Float(-event.magnification * 20))
    }
}

// MARK: - VRSphereRenderer

/// 球面 Metal 渲染器
/// 算法：在球体内部放置摄像机，把 equirectangular 贴图贴到球面内壁
class VRSphereRenderer {

    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var currentTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount: Int = 0

    init(device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        buildSphere(stacks: 64, slices: 64)
        buildPipeline()
    }

    // MARK: - 球体网格生成

    private func buildSphere(stacks: Int, slices: Int) {
        var vertices: [Float] = []
        var indices: [UInt32] = []

        for stack in 0...stacks {
            let phi = Float.pi * Float(stack) / Float(stacks)  // 0 ~ π
            for slice in 0...slices {
                let theta = 2 * Float.pi * Float(slice) / Float(slices) // 0 ~ 2π

                // 球面坐标
                let x = sin(phi) * cos(theta)
                let y = cos(phi)
                let z = sin(phi) * sin(theta)

                // UV 坐标（equirectangular 映射）
                let u = Float(slice) / Float(slices)
                let v = Float(stack) / Float(stacks)

                vertices += [x, y, z, u, v]
            }
        }

        for stack in 0..<stacks {
            for slice in 0..<slices {
                let row  = UInt32(stack * (slices + 1))
                let next = UInt32((stack + 1) * (slices + 1))
                let s    = UInt32(slice)

                indices += [row + s, next + s, row + s + 1]
                indices += [row + s + 1, next + s, next + s + 1]
            }
        }

        indexCount = indices.count

        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: []
        )
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt32>.size,
            options: []
        )
    }

    // MARK: - Metal Pipeline

    private func buildPipeline() {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float3 position;
            float2 uv;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        vertex VertexOut vr_vertex(
            const device VertexIn* vertices [[buffer(0)]],
            uint vid [[vertex_id]],
            constant float4x4& vpMatrix [[buffer(1)]])
        {
            VertexOut out;
            // 翻转 X 使摄像机在球体内部时贴图方向正确
            float4 worldPos = float4(-vertices[vid].position, 1.0);
            out.position = vpMatrix * worldPos;
            out.uv = vertices[vid].uv;
            return out;
        }

        fragment float4 vr_fragment(
            VertexOut in [[stage_in]],
            texture2d<float> tex [[texture(0)]])
        {
            constexpr sampler s(mag_filter::linear, min_filter::linear, address::repeat);
            return tex.sample(s, in.uv);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction  = library.makeFunction(name: "vr_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "vr_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // 顶点描述符
            let vtxDesc = MTLVertexDescriptor()
            // position (float3 offset 0)
            vtxDesc.attributes[0].format = .float3
            vtxDesc.attributes[0].offset = 0
            vtxDesc.attributes[0].bufferIndex = 0
            // uv (float2 offset 12)
            vtxDesc.attributes[1].format = .float2
            vtxDesc.attributes[1].offset = 12
            vtxDesc.attributes[1].bufferIndex = 0
            vtxDesc.layouts[0].stride = 20 // 5 floats * 4 bytes
            descriptor.vertexDescriptor = vtxDesc

            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("[VRSphereRenderer] Pipeline error: \(error)")
        }
    }

    // MARK: - Frame Update

    func update(pixelBuffer: CVPixelBuffer) {
        guard let cache = textureCache else { return }
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var ref: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &ref
        )
        if let r = ref { currentTexture = CVMetalTextureGetTexture(r) }
    }

    // MARK: - Render

    func render(passDescriptor: MTLRenderPassDescriptor,
                drawable: CAMetalDrawable,
                vpMatrix: simd_float4x4) {
        guard let commandQueue,
              let pipeline  = pipelineState,
              let texture   = currentTexture,
              let vBuf      = vertexBuffer,
              let iBuf      = indexBuffer,
              let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder   = cmdBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vBuf, offset: 0, index: 0)

        var mvp = vpMatrix
        encoder.setVertexBytes(&mvp, length: MemoryLayout<simd_float4x4>.size, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.front)  // 摄像机在球体内部，裁剪正面（球体外壁）

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: iBuf,
            indexBufferOffset: 0
        )

        encoder.endEncoding()
        cmdBuffer.present(drawable)
        cmdBuffer.commit()
    }
}
