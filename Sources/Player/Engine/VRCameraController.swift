import Foundation
import simd
import AppKit

/// VRCameraController - 360° 全景视频视角控制器
/// 负责管理摄像机的偏航(Yaw)/俯仰(Pitch)角度，响应鼠标拖拽和滚轮缩放
final class VRCameraController: ObservableObject {

    // MARK: - Published

    /// 水平偏转角（度），0~360
    @Published var yaw: Float = 0
    /// 垂直仰角（度），-85~85
    @Published var pitch: Float = 0
    /// 视野角（度），30~120
    @Published var fov: Float = 90

    // MARK: - Constants

    static let minPitch: Float = -85
    static let maxPitch: Float =  85
    static let minFov:   Float =  30
    static let maxFov:   Float = 120
    static let defaultFov: Float = 90

    // MARK: - Drag State

    private var lastDragLocation: CGPoint = .zero
    private var isDragging: Bool = false

    /// 灵敏度（像素/度）
    var sensitivity: Float = 0.3

    // MARK: - View Matrix

    /// 计算当前观察方向的 View-Projection 矩阵（用于球面顶点变换）
    func viewProjectionMatrix(aspectRatio: Float) -> simd_float4x4 {
        let projMatrix = perspectiveMatrix(fovDegrees: fov, aspect: aspectRatio, near: 0.1, far: 10)
        let viewMatrix = rotationMatrix(yawDeg: yaw, pitchDeg: pitch)
        return projMatrix * viewMatrix
    }

    // MARK: - Input Handling

    func beginDrag(at point: CGPoint) {
        lastDragLocation = point
        isDragging = true
    }

    func updateDrag(to point: CGPoint) {
        guard isDragging else { return }
        let dx = Float(point.x - lastDragLocation.x)
        let dy = Float(point.y - lastDragLocation.y)
        lastDragLocation = point

        yaw   = (yaw - dx * sensitivity).truncatingRemainder(dividingBy: 360)
        pitch = max(VRCameraController.minPitch, min(VRCameraController.maxPitch, pitch + dy * sensitivity))
    }

    func endDrag() {
        isDragging = false
    }

    func zoom(by delta: Float) {
        fov = max(VRCameraController.minFov, min(VRCameraController.maxFov, fov - delta * 2))
    }

    func reset() {
        yaw   = 0
        pitch = 0
        fov   = VRCameraController.defaultFov
    }

    // MARK: - Math Helpers

    private func perspectiveMatrix(fovDegrees: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let fovRad = fovDegrees * .pi / 180
        let y = 1 / tan(fovRad * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        return simd_float4x4(columns: (
            simd_float4(x,  0,  0,  0),
            simd_float4(0,  y,  0,  0),
            simd_float4(0,  0,  z, -1),
            simd_float4(0,  0,  z * near, 0)
        ))
    }

    private func rotationMatrix(yawDeg: Float, pitchDeg: Float) -> simd_float4x4 {
        let yRad = yawDeg   * .pi / 180
        let pRad = pitchDeg * .pi / 180

        // 绕 Y 轴旋转（偏航）
        let cosY = cos(yRad), sinY = sin(yRad)
        let yawMat = simd_float4x4(columns: (
            simd_float4( cosY, 0, sinY, 0),
            simd_float4(    0, 1,    0, 0),
            simd_float4(-sinY, 0, cosY, 0),
            simd_float4(    0, 0,    0, 1)
        ))

        // 绕 X 轴旋转（俯仰）
        let cosP = cos(pRad), sinP = sin(pRad)
        let pitchMat = simd_float4x4(columns: (
            simd_float4(1,     0,    0, 0),
            simd_float4(0,  cosP, -sinP, 0),
            simd_float4(0,  sinP,  cosP, 0),
            simd_float4(0,     0,     0, 1)
        ))

        return pitchMat * yawMat
    }
}
