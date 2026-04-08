// ASSBridge.h - libass Objective-C++ 封装
// 为 Swift 提供 ASS/SSA 字幕渲染能力

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASSBridge : NSObject

/// 初始化 libass 渲染器
- (instancetype)initWithContent:(NSString *)assContent;

/// 在指定时间渲染字幕为 CGImage（透明背景）
/// @param timeMs 时间，毫秒
/// @param width  目标宽度
/// @param height 目标高度
- (nullable CGImageRef)renderAtTimeMs:(long long)timeMs
                                width:(int)width
                               height:(int)height CF_RETURNS_RETAINED;

/// 更新字体目录（用于自定义字体）
- (void)setFontsDirPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
