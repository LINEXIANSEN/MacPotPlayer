// FFmpegBridge.h - FFmpeg Objective-C++ 封装
// 为 Swift 提供 FFmpeg 解码能力

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// -------------------------------------------------------
// 流信息
// -------------------------------------------------------
typedef NS_ENUM(NSInteger, MPStreamType) {
    MPStreamTypeVideo,
    MPStreamTypeAudio,
    MPStreamTypeSubtitle,
    MPStreamTypeUnknown
};

@interface MPStreamInfo : NSObject
@property (nonatomic, assign) int index;
@property (nonatomic, assign) MPStreamType type;
@property (nonatomic, copy)   NSString *codecName;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *language;
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channels;
@property (nonatomic, assign) double duration;
@end

// -------------------------------------------------------
// 视频帧
// -------------------------------------------------------
@interface MPVideoFrame : NSObject
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, assign) double pts;   // 秒
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@end

// -------------------------------------------------------
// 音频采样
// -------------------------------------------------------
@interface MPAudioSamples : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channels;
@property (nonatomic, assign) int bytesPerSample;
@end

// -------------------------------------------------------
// FFmpegBridge - 核心解码器
// -------------------------------------------------------
@interface FFmpegBridge : NSObject

/// 打开文件或 URL
- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError **)error;

/// 媒体时长（秒）
@property (nonatomic, readonly) double duration;

/// 所有流信息
@property (nonatomic, readonly) NSArray<MPStreamInfo *> *streams;

/// 选择当前活跃的视频/音频/字幕流
@property (nonatomic, assign) int activeVideoStreamIndex;
@property (nonatomic, assign) int activeAudioStreamIndex;
@property (nonatomic, assign) int activeSubtitleStreamIndex;

/// 读取下一帧（视频或音频）
/// 返回 MPVideoFrame 或 MPAudioSamples，根据 streamType 判断
- (nullable id)readNextFrame;

/// 跳转到指定时间（秒）
- (BOOL)seekToTime:(double)seconds;

/// 启用 VideoToolbox 硬件解码
- (void)setHardwareDecodingEnabled:(BOOL)enabled;

/// 设置视频滤镜（亮度/对比度/饱和度）
- (void)setFilterBrightness:(float)brightness
                   contrast:(float)contrast
                 saturation:(float)saturation;

/// 关闭解码器，释放资源
- (void)close;

@end

NS_ASSUME_NONNULL_END
