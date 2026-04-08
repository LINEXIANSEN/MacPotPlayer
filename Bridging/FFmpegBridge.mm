// FFmpegBridge.mm - FFmpeg 解码器 Objective-C++ 实现
// 通过 FFmpeg C API 实现视频/音频解码，并提供 Swift 可用的 Objective-C 接口

#import "FFmpegBridge.h"

extern "C" {
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avutil.h"
#include "libavutil/imgutils.h"
#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavutil/hwcontext.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
}

#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>

// -------------------------------------------------------
// MPStreamInfo Implementation
// -------------------------------------------------------
@implementation MPStreamInfo
@end

// -------------------------------------------------------
// MPVideoFrame Implementation
// -------------------------------------------------------
@implementation MPVideoFrame

- (void)dealloc {
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
}

@end

// -------------------------------------------------------
// MPAudioSamples Implementation
// -------------------------------------------------------
@implementation MPAudioSamples
@end

// -------------------------------------------------------
// FFmpegBridge Implementation
// -------------------------------------------------------
@interface FFmpegBridge () {
    AVFormatContext  *_formatCtx;
    AVCodecContext   *_videoCodecCtx;
    AVCodecContext   *_audioCodecCtx;
    AVFrame          *_videoFrame;
    AVFrame          *_audioFrame;
    AVPacket         *_packet;
    struct SwsContext *_swsCtx;
    SwrContext        *_swrCtx;
    AVBufferRef       *_hwDeviceCtx;

    // 视频过滤器图
    AVFilterGraph    *_filterGraph;
    AVFilterContext  *_buffersrcCtx;
    AVFilterContext  *_buffersinkCtx;
    BOOL              _filterInitialized;
}

@property (nonatomic, assign) int videoStreamIndex;
@property (nonatomic, assign) int audioStreamIndex;

@end

@implementation FFmpegBridge

- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError **)error {
    if (!(self = [super init])) return nil;

    _videoStreamIndex = -1;
    _audioStreamIndex = -1;
    _activeVideoStreamIndex = -1;
    _activeAudioStreamIndex = -1;
    _activeSubtitleStreamIndex = -1;

    // 初始化 FFmpeg 网络
    avformat_network_init();

    // 打开格式上下文
    AVDictionary *opts = NULL;
    av_dict_set(&opts, "timeout", "10000000", 0);   // 10s 超时
    av_dict_set(&opts, "reconnect", "1", 0);
    av_dict_set(&opts, "reconnect_at_eof", "1", 0);

    const char *urlCStr = url.absoluteString.UTF8String;
    _formatCtx = avformat_alloc_context();

    if (avformat_open_input(&_formatCtx, urlCStr, NULL, &opts) < 0) {
        av_dict_free(&opts);
        if (error) {
            *error = [NSError errorWithDomain:@"FFmpegBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法打开文件"}];
        }
        return nil;
    }
    av_dict_free(&opts);

    // 探测流信息
    if (avformat_find_stream_info(_formatCtx, NULL) < 0) {
        avformat_close_input(&_formatCtx);
        if (error) {
            *error = [NSError errorWithDomain:@"FFmpegBridge"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法读取流信息"}];
        }
        return nil;
    }

    // 查找最佳视频/音频流
    _videoStreamIndex = av_find_best_stream(_formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    _audioStreamIndex = av_find_best_stream(_formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    _activeVideoStreamIndex = _videoStreamIndex;
    _activeAudioStreamIndex = _audioStreamIndex;

    // 初始化视频解码器
    if (_videoStreamIndex >= 0) {
        [self setupVideoDecoder];
    }

    // 初始化音频解码器
    if (_audioStreamIndex >= 0) {
        [self setupAudioDecoder];
    }

    _videoFrame = av_frame_alloc();
    _audioFrame = av_frame_alloc();
    _packet     = av_packet_alloc();

    return self;
}

- (void)setupVideoDecoder {
    AVStream *stream = _formatCtx->streams[_videoStreamIndex];
    const AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) return;

    _videoCodecCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(_videoCodecCtx, stream->codecpar);

    // 尝试 VideoToolbox 硬件加速
    AVBufferRef *hwCtx = NULL;
    if (av_hwdevice_ctx_create(&hwCtx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, NULL, NULL, 0) >= 0) {
        _videoCodecCtx->hw_device_ctx = av_buffer_ref(hwCtx);
        av_buffer_unref(&hwCtx);
    }

    _videoCodecCtx->thread_count = 0; // 自动线程数

    AVDictionary *opts = NULL;
    avcodec_open2(_videoCodecCtx, codec, &opts);
    av_dict_free(&opts);
}

- (void)setupAudioDecoder {
    AVStream *stream = _formatCtx->streams[_audioStreamIndex];
    const AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) return;

    _audioCodecCtx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(_audioCodecCtx, stream->codecpar);
    avcodec_open2(_audioCodecCtx, codec, NULL);

    // 重采样：输出为 float32 stereo 48000Hz
    _swrCtx = swr_alloc();
    av_opt_set_int(_swrCtx, "in_channel_layout",  _audioCodecCtx->ch_layout.nb_channels == 1
                   ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO, 0);
    av_opt_set_int(_swrCtx, "in_sample_rate",     _audioCodecCtx->sample_rate, 0);
    av_opt_set_sample_fmt(_swrCtx, "in_sample_fmt", _audioCodecCtx->sample_fmt, 0);
    av_opt_set_int(_swrCtx, "out_channel_layout", AV_CH_LAYOUT_STEREO, 0);
    av_opt_set_int(_swrCtx, "out_sample_rate",    48000, 0);
    av_opt_set_sample_fmt(_swrCtx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
    swr_init(_swrCtx);
}

- (double)duration {
    if (!_formatCtx) return 0;
    return _formatCtx->duration / (double)AV_TIME_BASE;
}

- (NSArray<MPStreamInfo *> *)streams {
    NSMutableArray *result = [NSMutableArray array];
    if (!_formatCtx) return result;

    for (unsigned int i = 0; i < _formatCtx->nb_streams; i++) {
        AVStream *st = _formatCtx->streams[i];
        MPStreamInfo *info = [[MPStreamInfo alloc] init];
        info.index = (int)i;

        switch (st->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:    info.type = MPStreamTypeVideo;    break;
            case AVMEDIA_TYPE_AUDIO:    info.type = MPStreamTypeAudio;    break;
            case AVMEDIA_TYPE_SUBTITLE: info.type = MPStreamTypeSubtitle; break;
            default:                    info.type = MPStreamTypeUnknown;  break;
        }

        const AVCodecDescriptor *desc = avcodec_descriptor_get(st->codecpar->codec_id);
        info.codecName = desc ? [NSString stringWithUTF8String:desc->name] : @"unknown";
        info.width  = st->codecpar->width;
        info.height = st->codecpar->height;
        info.sampleRate = st->codecpar->sample_rate;
        info.channels   = st->codecpar->ch_layout.nb_channels;
        info.duration   = st->duration * av_q2d(st->time_base);

        // 标题和语言
        AVDictionaryEntry *titleEntry = av_dict_get(st->metadata, "title",    NULL, 0);
        AVDictionaryEntry *langEntry  = av_dict_get(st->metadata, "language", NULL, 0);
        if (titleEntry) info.title    = [NSString stringWithUTF8String:titleEntry->value];
        if (langEntry)  info.language = [NSString stringWithUTF8String:langEntry->value];

        [result addObject:info];
    }
    return result;
}

- (nullable id)readNextFrame {
    if (!_formatCtx) return nil;

    while (av_read_frame(_formatCtx, _packet) >= 0) {
        @autoreleasepool {
            int streamIdx = _packet->stream_index;

            if (streamIdx == _activeVideoStreamIndex && _videoCodecCtx) {
                id frame = [self decodeVideoPacket:_packet];
                av_packet_unref(_packet);
                if (frame) return frame;

            } else if (streamIdx == _activeAudioStreamIndex && _audioCodecCtx) {
                id samples = [self decodeAudioPacket:_packet];
                av_packet_unref(_packet);
                if (samples) return samples;

            } else {
                av_packet_unref(_packet);
            }
        }
    }
    return nil; // EOF
}

- (nullable MPVideoFrame *)decodeVideoPacket:(AVPacket *)packet {
    if (avcodec_send_packet(_videoCodecCtx, packet) < 0) return nil;

    if (avcodec_receive_frame(_videoCodecCtx, _videoFrame) < 0) return nil;

    // 硬件帧转 CPU
    AVFrame *cpuFrame = _videoFrame;
    AVFrame *swFrame  = NULL;
    if (_videoFrame->format == AV_PIX_FMT_VIDEOTOOLBOX) {
        swFrame = av_frame_alloc();
        if (av_hwframe_transfer_data(swFrame, _videoFrame, 0) < 0) {
            av_frame_free(&swFrame);
            return nil;
        }
        cpuFrame = swFrame;
    }

    int w = cpuFrame->width;
    int h = cpuFrame->height;

    // 创建 CVPixelBuffer
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *attrs = @{
        (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    CVPixelBufferCreate(kCFAllocatorDefault, w, h,
                        kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef)attrs,
                        &pixelBuffer);

    // 转换像素格式 -> BGRA
    if (!_swsCtx || (int)cpuFrame->format != AV_PIX_FMT_BGRA) {
        sws_freeContext(_swsCtx);
        _swsCtx = sws_getContext(w, h, (AVPixelFormat)cpuFrame->format,
                                  w, h, AV_PIX_FMT_BGRA,
                                  SWS_BILINEAR, NULL, NULL, NULL);
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *dst[4] = { (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer), NULL, NULL, NULL };
    int dstStride[4] = { (int)CVPixelBufferGetBytesPerRow(pixelBuffer), 0, 0, 0 };
    sws_scale(_swsCtx, cpuFrame->data, cpuFrame->linesize, 0, h, dst, dstStride);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    if (swFrame) av_frame_free(&swFrame);

    MPVideoFrame *frame = [[MPVideoFrame alloc] init];
    frame.pixelBuffer = pixelBuffer;
    frame.pts   = _videoFrame->pts * av_q2d(_formatCtx->streams[_activeVideoStreamIndex]->time_base);
    frame.width = w;
    frame.height = h;

    av_frame_unref(_videoFrame);
    return frame;
}

- (nullable MPAudioSamples *)decodeAudioPacket:(AVPacket *)packet {
    if (avcodec_send_packet(_audioCodecCtx, packet) < 0) return nil;
    if (avcodec_receive_frame(_audioCodecCtx, _audioFrame) < 0) return nil;

    int outSamples = (int)av_rescale_rnd(
        swr_get_delay(_swrCtx, _audioCodecCtx->sample_rate) + _audioFrame->nb_samples,
        48000, _audioCodecCtx->sample_rate, AV_ROUND_UP);

    int bufSize = outSamples * 2 * sizeof(float); // stereo float32
    NSMutableData *data = [NSMutableData dataWithLength:bufSize];
    uint8_t *outBuf = (uint8_t *)data.mutableBytes;

    int converted = swr_convert(_swrCtx, &outBuf, outSamples,
                                 (const uint8_t **)_audioFrame->data,
                                 _audioFrame->nb_samples);

    if (converted <= 0) {
        av_frame_unref(_audioFrame);
        return nil;
    }

    data.length = converted * 2 * sizeof(float);

    MPAudioSamples *samples = [[MPAudioSamples alloc] init];
    samples.data         = data;
    samples.pts          = _audioFrame->pts * av_q2d(_formatCtx->streams[_activeAudioStreamIndex]->time_base);
    samples.sampleRate   = 48000;
    samples.channels     = 2;
    samples.bytesPerSample = sizeof(float);

    av_frame_unref(_audioFrame);
    return samples;
}

- (BOOL)seekToTime:(double)seconds {
    if (!_formatCtx) return NO;
    int64_t ts = (int64_t)(seconds * AV_TIME_BASE);
    int ret = av_seek_frame(_formatCtx, -1, ts, AVSEEK_FLAG_BACKWARD);
    if (_videoCodecCtx) avcodec_flush_buffers(_videoCodecCtx);
    if (_audioCodecCtx) avcodec_flush_buffers(_audioCodecCtx);
    return ret >= 0;
}

- (void)setHardwareDecodingEnabled:(BOOL)enabled {
    // 重新初始化解码器
    if (_videoStreamIndex >= 0) {
        if (_videoCodecCtx) {
            avcodec_free_context(&_videoCodecCtx);
        }
        [self setupVideoDecoder];
    }
}

- (void)setFilterBrightness:(float)brightness contrast:(float)contrast saturation:(float)saturation {
    // 通过 ffmpeg lavfi 实现 eq 滤镜
    // 在下一帧时重新初始化 filter graph
    // （简化实现：通过 Metal 着色器已处理，此处留空）
}

- (void)close {
    if (_swsCtx)  { sws_freeContext(_swsCtx); _swsCtx = NULL; }
    if (_swrCtx)  { swr_free(&_swrCtx); }
    if (_videoFrame) { av_frame_free(&_videoFrame); }
    if (_audioFrame) { av_frame_free(&_audioFrame); }
    if (_packet)     { av_packet_free(&_packet); }
    if (_videoCodecCtx) { avcodec_free_context(&_videoCodecCtx); }
    if (_audioCodecCtx) { avcodec_free_context(&_audioCodecCtx); }
    if (_formatCtx) { avformat_close_input(&_formatCtx); }
    if (_hwDeviceCtx) { av_buffer_unref(&_hwDeviceCtx); }
}

- (void)dealloc {
    [self close];
}

@end
