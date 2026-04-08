// ASSBridge.mm - libass Objective-C++ 实现

#import "ASSBridge.h"
#include "ass/ass.h"

@interface ASSBridge () {
    ASS_Library  *_library;
    ASS_Renderer *_renderer;
    ASS_Track    *_track;
}
@end

@implementation ASSBridge

- (instancetype)initWithContent:(NSString *)assContent {
    if (!(self = [super init])) return nil;

    // 初始化 libass
    _library  = ass_library_init();
    _renderer = ass_renderer_init(_library);

    // 配置渲染器
    ass_set_fonts(_renderer, NULL, "PingFang SC", ASS_FONTPROVIDER_AUTODETECT, NULL, 1);
    ass_set_hinting(_renderer, ASS_HINTING_LIGHT);

    // 加载字幕轨道
    const char *content = assContent.UTF8String;
    _track = ass_read_memory(_library, (char *)content, strlen(content), NULL);

    return self;
}

- (nullable CGImageRef)renderAtTimeMs:(long long)timeMs
                                width:(int)width
                               height:(int)height {
    if (!_track || !_renderer) return NULL;

    ass_set_frame_size(_renderer, width, height);
    ass_set_storage_size(_renderer, width, height);

    int detectChange = 0;
    ASS_Image *img = ass_render_frame(_renderer, _track, timeMs, &detectChange);

    if (!img) return NULL;

    // 将 ASS_Image 链表合并为 RGBA bitmap
    size_t dataSize = width * height * 4;
    uint8_t *bitmap = (uint8_t *)calloc(dataSize, 1);
    if (!bitmap) return NULL;

    for (ASS_Image *cur = img; cur; cur = cur->next) {
        uint32_t color = cur->color;
        uint8_t r = (color >> 24) & 0xFF;
        uint8_t g = (color >> 16) & 0xFF;
        uint8_t b = (color >>  8) & 0xFF;
        uint8_t baseAlpha = 255 - (color & 0xFF);

        for (int y = 0; y < cur->h; y++) {
            for (int x = 0; x < cur->w; x++) {
                uint8_t maskA = cur->bitmap[y * cur->stride + x];
                if (maskA == 0) continue;

                int px = (cur->dst_y + y) * width + (cur->dst_x + x);
                if (px < 0 || px >= width * height) continue;

                uint8_t *dst = &bitmap[px * 4];
                uint8_t a = (uint8_t)((maskA * baseAlpha) / 255);

                // Alpha 混合
                uint8_t invA = 255 - a;
                dst[0] = (r * a + dst[0] * invA) / 255;
                dst[1] = (g * a + dst[1] * invA) / 255;
                dst[2] = (b * a + dst[2] * invA) / 255;
                dst[3] = a + dst[3] * invA / 255;
            }
        }
    }

    // 创建 CGImage
    CGColorSpaceRef cs   = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, bitmap, dataSize, NULL);

    CGImageRef image = CGImageCreate(
        width, height, 8, 32,
        width * 4, cs,
        kCGImageAlphaPremultipliedLast,
        dp, NULL, false,
        kCGRenderingIntentDefault
    );

    CGDataProviderRelease(dp);
    CGColorSpaceRelease(cs);
    free(bitmap);

    return image;
}

- (void)setFontsDirPath:(NSString *)path {
    if (_library) {
        ass_set_fonts_dir(_library, path.UTF8String);
    }
}

- (void)dealloc {
    if (_track)    { ass_free_track(_track); }
    if (_renderer) { ass_renderer_done(_renderer); }
    if (_library)  { ass_library_done(_library); }
}

@end
