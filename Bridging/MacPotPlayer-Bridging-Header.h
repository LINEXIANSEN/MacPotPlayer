// MacPotPlayer-Bridging-Header.h
// Objective-C++ 到 Swift 的桥接头文件
// 引入 FFmpeg 和 libass 的 C 头文件

#ifndef MacPotPlayer_Bridging_Header_h
#define MacPotPlayer_Bridging_Header_h

// FFmpeg Headers
#ifdef __cplusplus
extern "C" {
#endif

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/imgutils.h"
#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavutil/hwcontext.h"
#include "libavutil/hwcontext_videotoolbox.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavfilter/avfilter.h"
#include "libavfilter/buffersink.h"
#include "libavfilter/buffersrc.h"

// libass
#include "ass/ass.h"
#include "ass/ass_types.h"

#ifdef __cplusplus
}
#endif

// Objective-C++ 桥接类
#import "FFmpegBridge.h"
#import "ASSBridge.h"

#endif /* MacPotPlayer_Bridging_Header_h */
