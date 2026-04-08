#!/bin/bash
# setup_dependencies.sh
# 自动安装 MacPotPlayer 所需的 FFmpeg 和 libass 依赖
# 运行环境：macOS，需要 Homebrew 和 Xcode Command Line Tools

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FFMPEG_DIR="$PROJECT_DIR/FFmpeg"

echo "================================================"
echo "  MacPotPlayer 依赖安装脚本"
echo "================================================"
echo "项目目录: $PROJECT_DIR"
echo ""

# 1. 检查 Homebrew
if ! command -v brew &>/dev/null; then
    echo "❌ 未找到 Homebrew，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
echo "✅ Homebrew: $(brew --version | head -1)"

# 2. 安装 FFmpeg (with all codecs)
echo ""
echo "📦 安装 FFmpeg..."
brew install ffmpeg --with-all-targets 2>/dev/null || brew install ffmpeg

FFMPEG_CELLAR=$(brew --cellar ffmpeg)/$(brew list --versions ffmpeg | awk '{print $2}')
echo "✅ FFmpeg: $FFMPEG_CELLAR"

# 3. 安装 libass
echo ""
echo "📦 安装 libass..."
brew install libass
LIBASS_CELLAR=$(brew --cellar libass)/$(brew list --versions libass | awk '{print $2}')
echo "✅ libass: $LIBASS_CELLAR"

# 4. 创建 FFmpeg 目录结构
echo ""
echo "🔧 配置 FFmpeg 头文件和库..."
mkdir -p "$FFMPEG_DIR/include"
mkdir -p "$FFMPEG_DIR/lib"
mkdir -p "$FFMPEG_DIR/include/ass"

# 5. 复制头文件
echo "  → 复制 FFmpeg 头文件..."
cp -Rf "$FFMPEG_CELLAR/include/"* "$FFMPEG_DIR/include/"

echo "  → 复制 libass 头文件..."
cp -Rf "$LIBASS_CELLAR/include/ass/"* "$FFMPEG_DIR/include/ass/"

# 6. 复制库文件
echo "  → 复制库文件..."
for lib in avcodec avformat avutil swscale swresample avfilter; do
    # 复制 .dylib
    DYLIB_SRC=$(find "$FFMPEG_CELLAR/lib" -name "lib${lib}.dylib" | head -1)
    if [ -n "$DYLIB_SRC" ]; then
        cp "$DYLIB_SRC" "$FFMPEG_DIR/lib/"
        echo "    ✓ lib${lib}.dylib"
    fi
done

# libass
LIBASS_DYLIB=$(find "$LIBASS_CELLAR/lib" -name "libass.dylib" | head -1)
if [ -n "$LIBASS_DYLIB" ]; then
    cp "$LIBASS_DYLIB" "$FFMPEG_DIR/lib/"
    echo "    ✓ libass.dylib"
fi

# 7. 修复 @rpath
echo ""
echo "🔧 修复动态库 rpath..."
for dylib in "$FFMPEG_DIR/lib/"*.dylib; do
    libname=$(basename "$dylib")
    install_name_tool -id "@rpath/$libname" "$dylib" 2>/dev/null || true
    echo "  → @rpath/$libname"
done

# 8. 生成 xcconfig
cat > "$PROJECT_DIR/FFmpeg.xcconfig" << EOF
// FFmpeg & libass 构建配置
// 由 setup_dependencies.sh 自动生成

FFMPEG_DIR = \$(SRCROOT)/FFmpeg
HEADER_SEARCH_PATHS = \$(inherited) \$(FFMPEG_DIR)/include
LIBRARY_SEARCH_PATHS = \$(inherited) \$(FFMPEG_DIR)/lib
OTHER_LDFLAGS = \$(inherited) -lavcodec -lavformat -lavutil -lswscale -lswresample -lavfilter -lass
LD_RUNPATH_SEARCH_PATHS = \$(inherited) @executable_path/../Frameworks @loader_path
EOF

echo ""
echo "================================================"
echo "  ✅ 依赖安装完成！"
echo "================================================"
echo ""
echo "下一步："
echo "  1. 安装 XcodeGen:  brew install xcodegen"
echo "  2. 生成 Xcode 项目: xcodegen generate"
echo "  3. 打开项目:        open MacPotPlayer.xcodeproj"
echo ""
