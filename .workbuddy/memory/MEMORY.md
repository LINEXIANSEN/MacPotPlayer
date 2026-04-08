# MEMORY.md - MacPotPlayer 项目长期记忆

## 项目信息
- **项目名称**: MacPotPlayer
- **目标**: Mac 原生视频播放器，功能对标 PotPlayer
- **技术方案**: 方案A — Swift + AVFoundation + FFmpeg + Metal + libass
- **项目路径**: c:/Users/Administrator/Videos/MacPotPlayer/
- **开始时间**: 2026-04-07

## 架构决策
- UI层: SwiftUI + AppKit (macOS 13+)
- 视频渲染: Metal (MTKView + MetalVideoRenderer)
- 解码引擎: FFmpeg C API (通过 Objective-C++ 桥接)
- 硬件解码: VideoToolbox
- 音频处理: AVAudioEngine + AVAudioUnitEQ
- 字幕渲染: libass (通过 ObjC++ ASSBridge)
- 项目管理: XcodeGen (project.yml)
- 依赖安装: Scripts/setup_dependencies.sh

## 代码完成状态 (2026-04-08 更新)
全部14个核心模块已完成，可在 macOS 上用 Xcode 构建。
新增：360° 全景/VR 视频支持（VRCameraController + VRPlayerView + Metal 球面渲染器），支持自动检测全景视频并切换 VR 模式。
新增：GitHub Actions CI/CD（`.github/workflows/build.yml` + `release.yml`），push 代码自动构建，打 tag 自动发布 .dmg。
