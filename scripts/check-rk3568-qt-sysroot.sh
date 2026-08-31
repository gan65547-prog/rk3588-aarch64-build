#!/usr/bin/env bash
set -euo pipefail
USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
SYSROOT="${USER_HOME}/rk3568-qt/sysroot"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --sysroot) SYSROOT="${2:?missing sysroot}"; shift 2 ;;
        -h|--help) echo "Usage: $0 [--sysroot DIR]"; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    esac
done

required=(
    "$SYSROOT/lib/aarch64-linux-gnu/libc.so.6"
    "$SYSROOT/usr/include/stdio.h"
    "$SYSROOT/usr/include/aarch64-linux-gnu/bits/libc-header-start.h"
)
for item in "${required[@]}"; do
    [ -e "$item" ] || { echo "FAIL: missing $item" >&2; exit 1; }
done

require_any() {
    local description="$1"
    shift
    for pattern in "$@"; do
        if find "$SYSROOT" -path "$pattern" -print -quit 2>/dev/null | grep -q .; then
            return 0
        fi
    done
    echo "FAIL: missing $description" >&2
    return 1
}

require_any "Qt public header (qglobal.h)" '*/qglobal.h'
require_any "Qt CMake package configuration" '*/cmake/Qt5/Qt5Config.cmake' '*/cmake/Qt6/Qt6Config.cmake'
require_any "Qt Core development library" '*/libQt5Core.so' '*/libQt6Core.so'
require_any "EGL public header" '*/EGL/egl.h'
require_any "EGL development library" '*/libEGL.so'
require_any "OpenGL ES development library" '*/libGLESv2.so'
require_any "DRM public header" '*/xf86drm.h'
require_any "DRM development library" '*/libdrm.so'

echo "== identity =="
cat "$SYSROOT/BOARD-MANIFEST.txt" 2>/dev/null || true
echo "== graphics =="
find "$SYSROOT/usr/lib" -maxdepth 5 \
    \( -name 'libEGL.so*' -o -name 'libGLESv2.so*' -o -name 'libgbm.so*' -o -name 'libdrm.so*' \) \
    -print | sort
echo "== Qt =="
find "$SYSROOT/usr/include" -name qglobal.h -print | head -5
find "$SYSROOT/usr/lib" \
    \( -path '*/cmake/Qt5/Qt5Config.cmake' -o -path '*/cmake/Qt6/Qt6Config.cmake' \) \
    -print
echo "PASS: required RK3568 sysroot files are present"
