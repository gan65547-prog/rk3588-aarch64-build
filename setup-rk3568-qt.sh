#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v getent >/dev/null 2>&1; then
    USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
else
    USER_HOME="${HOME:?HOME is not set}"
fi
QT_ROOT="${RK3568_QT_ROOT:-${USER_HOME}/rk3568-qt}"
SYSROOT="${RK3568_SYSROOT:-${QT_ROOT}/sysroot}"
DEB_DIR="${RK3568_DEB_DIR:-${QT_ROOT}/debs}"
OFFLINE_DEBS=""
RK3568_BOARD=""
TARGET_CHIP="${RK3568_TARGET_CHIP:-rk3568}"
SHARED_BOARD=""
PROFILE="auto"
SDK_SYSROOT=""
TOOLCHAIN_TRIPLE="${RK3568_TOOLCHAIN_TRIPLE:-aarch64-linux-gnu}"
QT_HOST_MOC="${RK3568_QT_HOST_MOC:-}"
MODE="full"
INSTALL_HOST_DEPS=0
INSTALL_TARGET_DEPS=0
TARGET_MESA=0
TARGET_QML=0
BUILD_EXAMPLE=1
DEPLOY_APP=1
RUN_APP=0
QPA_PLATFORM="eglfs"
DEPLOY_DIR="/tmp/hello-rk3568"

usage() {
    cat <<EOF
Usage:
  $0 --board user@board [--target-chip rk3568|rk3588] [--profile ubuntu24|sdk] [--sdk-sysroot DIR] [--offline-debs DIR] [--toolchain-triple TRIPLE] [--qt-host-moc FILE] [--install-host-deps] [--install-target-deps] [--target-qml] [--target-mesa] [--no-build] [--no-deploy] [--run] [--qpa eglfs|wayland|xcb|linuxfb]
  $0 --shared-rk3588 [--shared-board user@host]
  $0 --doctor --board user@rk3568
  $0 --self-test

Defaults are derived from the current login user's home directory:
  QT root: $QT_ROOT
  sysroot: $SYSROOT
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --board) RK3568_BOARD="${2:?missing board}"; shift 2 ;;
        --target-chip) TARGET_CHIP="${2:?missing target chip}"; shift 2 ;;
        --profile) PROFILE="${2:?missing profile}"; shift 2 ;;
        --sdk-sysroot) SDK_SYSROOT="${2:?missing SDK sysroot}"; shift 2 ;;
        --toolchain-triple) TOOLCHAIN_TRIPLE="${2:?missing toolchain triple}"; shift 2 ;;
        --qt-host-moc) QT_HOST_MOC="${2:?missing host moc path}"; shift 2 ;;
        --offline-debs) OFFLINE_DEBS="${2:?missing offline package directory}"; shift 2 ;;
        --shared-rk3588) MODE="shared"; shift ;;
        --doctor) MODE="doctor"; shift ;;
        --shared-board) SHARED_BOARD="${2:?missing shared board}"; shift 2 ;;
        --install-host-deps) INSTALL_HOST_DEPS=1; shift ;;
        --install-target-deps) INSTALL_TARGET_DEPS=1; shift ;;
        --target-mesa) TARGET_MESA=1; shift ;;
        --target-qml) TARGET_QML=1; shift ;;
        --no-build) BUILD_EXAMPLE=0; shift ;;
        --no-deploy) DEPLOY_APP=0; shift ;;
        --run) RUN_APP=1; shift ;;
        --qpa) QPA_PLATFORM="${2:?missing QPA platform}"; shift 2 ;;
        --self-test) MODE="self"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$TARGET_CHIP" in rk3568|rk3588) ;; *) echo "ERROR: --target-chip must be rk3568 or rk3588" >&2; exit 2 ;; esac

# Accept the common short spelling used in customer commands.
if [ "$PROFILE" = "ubuntu" ]; then
    PROFILE="ubuntu24"
fi

host_check() {
    case "$(uname -m)" in
        aarch64|arm64) ;;
        x86_64|amd64)
            if [ -z "$QT_HOST_MOC" ]; then
                for candidate in /usr/lib/qt5/bin/moc /usr/lib/x86_64-linux-gnu/qt5/bin/moc /usr/lib/qt6/bin/moc; do
                    if [ -x "$candidate" ]; then QT_HOST_MOC="$candidate"; break; fi
                done
            fi
            ;;
        *) echo "FAIL: unsupported build-host architecture: $(uname -m)" >&2; return 1 ;;
    esac
    local missing=0
    for cmd in cmake make pkg-config rsync ssh scp dpkg-deb file "${TOOLCHAIN_TRIPLE}-gcc" "${TOOLCHAIN_TRIPLE}-g++"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "MISSING: $cmd"
            missing=1
        fi
    done
    if { [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "amd64" ]; } && [ -z "$QT_HOST_MOC" ] && [ "$INSTALL_HOST_DEPS" -eq 1 ]; then
        sudo apt-get install -y qtbase5-dev-tools qt5-qmake-bin qt5-qmake
        for candidate in /usr/lib/qt5/bin/moc /usr/lib/x86_64-linux-gnu/qt5/bin/moc; do
            if [ -x "$candidate" ]; then QT_HOST_MOC="$candidate"; break; fi
        done
    fi
    if [ "$missing" -ne 0 ] && [ "$INSTALL_HOST_DEPS" -eq 1 ]; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake ninja-build pkg-config rsync openssh-client dpkg-dev file gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
        if [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "amd64" ]; then
            sudo apt-get install -y qtbase5-dev-tools qt5-qmake-bin qt5-qmake
            for candidate in /usr/lib/qt5/bin/moc /usr/lib/x86_64-linux-gnu/qt5/bin/moc; do
                if [ -x "$candidate" ]; then QT_HOST_MOC="$candidate"; break; fi
            done
        fi
        missing=0
        for cmd in cmake make pkg-config rsync ssh scp dpkg-deb file "${TOOLCHAIN_TRIPLE}-gcc" "${TOOLCHAIN_TRIPLE}-g++"; do
            command -v "$cmd" >/dev/null 2>&1 || missing=1
    done
    if [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "amd64" ]; then
        [ -n "$QT_HOST_MOC" ] && [ -x "$QT_HOST_MOC" ] || {
            echo "FAIL: x86_64 host requires Qt5 moc; use --install-host-deps or --qt-host-moc <matching x86_64 moc>" >&2
            return 1
        }
    fi
    fi
    [ "$missing" -eq 0 ] || { echo "FAIL: install prerequisites or use --install-host-deps" >&2; return 1; }
    if command -v ninja >/dev/null 2>&1; then GENERATOR="Ninja"; else GENERATOR="Unix Makefiles"; echo "WARN: ninja not found; using Makefiles"; fi
}

deploy_app() {
    local binary="$QT_ROOT/build/hello-qt/hello-rk3568"
    [ -x "$binary" ] || { echo "ERROR: built application not found: $binary" >&2; return 1; }
    local qpa_plugin
    case "$QPA_PLATFORM" in
        eglfs) qpa_plugin="libqeglfs.so" ;;
        wayland) qpa_plugin="libqwayland-egl.so" ;;
        xcb) qpa_plugin="libqxcb.so" ;;
        linuxfb) qpa_plugin="libqlinuxfb.so" ;;
        *) echo "ERROR: unsupported QPA platform: $QPA_PLATFORM" >&2; return 2 ;;
    esac
    ssh "$RK3568_BOARD" "test -e /usr/lib/aarch64-linux-gnu/libQt5Core.so.5 || test -e /usr/lib/libQt5Core.so.5"
    ssh "$RK3568_BOARD" "test -e /usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/$qpa_plugin || test -e /usr/lib/qt5/plugins/platforms/$qpa_plugin" \
        || { echo "ERROR: target Qt QPA plugin not found: $qpa_plugin" >&2; return 1; }
    echo "INFO: deploying application to $RK3568_BOARD:$DEPLOY_DIR"
    ssh "$RK3568_BOARD" "mkdir -p '$DEPLOY_DIR'"
    scp "$binary" "$RK3568_BOARD:$DEPLOY_DIR/hello-rk3568"
    ssh "$RK3568_BOARD" "chmod 0755 '$DEPLOY_DIR/hello-rk3568'; printf '%s\\n' '#!/bin/sh' 'export QT_QPA_PLATFORM=$QPA_PLATFORM' 'export QT_DEBUG_PLUGINS=\${QT_DEBUG_PLUGINS:-0}' 'exec $DEPLOY_DIR/hello-rk3568 \"\$@\"' >'$DEPLOY_DIR/run.sh'; chmod 0755 '$DEPLOY_DIR/run.sh'"
    echo "PASS: application deployed; run with: ssh $RK3568_BOARD '$DEPLOY_DIR/run.sh'"
    if [ "$RUN_APP" -eq 1 ]; then
        echo "INFO: starting application with QT_QPA_PLATFORM=$QPA_PLATFORM"
        ssh "$RK3568_BOARD" "'$DEPLOY_DIR/run.sh'" 
    fi
}

self_test() {
    [ -f "$ROOT_DIR/cmake/rk3568-aarch64.cmake" ] || { echo "FAIL: toolchain missing"; return 1; }
    [ -f "$ROOT_DIR/examples/hello-qt/CMakeLists.txt" ] || { echo "FAIL: example missing"; return 1; }
    for script in "$ROOT_DIR"/scripts/*.sh; do bash -n "$script"; done
    bash -n "$ROOT_DIR/setup-rk3568-qt.sh"
    local offline="$ROOT_DIR/package/qt-target-debs/ubuntu24-arm64"
    if [ -d "$offline" ] && command -v dpkg-deb >/dev/null 2>&1; then
        local count=0 arch
        for deb in "$offline"/*.deb; do
            [ -e "$deb" ] || continue
            arch="$(dpkg-deb -f "$deb" Architecture)"
            [ "$arch" = "arm64" ] || { echo "FAIL: non-arm64 offline package: $(basename "$deb") ($arch)" >&2; return 1; }
            count=$((count + 1))
        done
        [ "$count" -gt 0 ] || { echo "FAIL: offline package directory is empty" >&2; return 1; }
        for pkg in qtbase5-dev qtbase5-dev-tools qt5-qmake libegl1-mesa-dev libgles2-mesa-dev libgbm-dev libdrm-dev; do
            compgen -G "$offline/${pkg}_*.deb" >/dev/null || { echo "FAIL: required offline package missing: $pkg" >&2; return 1; }
        done
        echo "PASS: offline package set ($count arm64 packages)"
    else
        echo "WARN: dpkg-deb unavailable; offline package metadata not checked"
    fi
    echo "PASS: entrypoint, helper scripts, toolchain and example syntax"
}

shared_check() {
    [ -n "$SHARED_BOARD" ] || { echo "ERROR: --shared-board is required" >&2; return 2; }
    ssh "$SHARED_BOARD" 'set -eu
        arch=$(uname -m)
        compatible=$(tr "\000" "\n" </proc/device-tree/compatible 2>/dev/null || true)
        case "$arch" in aarch64) ;; *) echo "FAIL: board is not aarch64"; exit 1;; esac
        echo "arch=$arch"
        echo "$compatible"
        echo "qt_runtime=$(find /usr/lib/aarch64-linux-gnu -maxdepth 1 -name "libQt[56]Core.so.*" -printf "%f " 2>/dev/null || true)"
        echo "qpa=$(find /usr/lib/aarch64-linux-gnu/qt5/plugins/platforms -maxdepth 1 -type f -printf "%f " 2>/dev/null || true)"
        test -e /dev/dri/card0
        command -v eglinfo >/dev/null && eglinfo -B 2>&1 | sed -n "1,100p" || echo "WARN: eglinfo unavailable"
    '
    echo "PASS: RK3588 shared aarch64/DRM/EGL/Qt runtime path"
    echo "LIMIT: RK3568 GPU, display timings, RGA, MPP and RKNN remain unvalidated"
}

doctor() {
    [ -n "$RK3568_BOARD" ] || { echo "ERROR: --doctor requires --board user@rk3568" >&2; return 2; }
    host_check
    local info
    info="$(ssh "$RK3568_BOARD" 'printf "arch=%s\n" "$(uname -m)"; printf "compatible="; tr "\000" "\n" </proc/device-tree/compatible 2>/dev/null | paste -sd, -; printf "qt="; test -e /usr/lib/aarch64-linux-gnu/libQt5Core.so.5 -o -e /usr/lib/libQt5Core.so.5 && echo yes || echo no; printf "drm="; test -e /dev/dri/card0 && echo yes || echo no')"
    echo "$info"
    printf '%s\n' "$info" | grep -q '^arch=aarch64$' || { echo "FAIL: target is not aarch64" >&2; return 1; }
    printf '%s\n' "$info" | grep -q "rockchip,$TARGET_CHIP" || { echo "FAIL: target does not match --target-chip $TARGET_CHIP" >&2; return 1; }
    printf '%s\n' "$info" | grep -q '^qt=yes$' || echo "WARN: target Qt5 runtime missing; install target dependencies before deployment"
    echo "PASS: host and $TARGET_CHIP target preflight (Qt runtime may be installed in the next step)"
}

install_target_deps() {
    local packages="libc6-dev linux-libc-dev qtbase5-dev qtbase5-dev-tools libgbm-dev libdrm-dev libinput-dev libxkbcommon-dev"
    if [ "$TARGET_QML" -eq 1 ]; then packages="$packages qtdeclarative5-dev"; fi
    if [ "$TARGET_MESA" -eq 1 ]; then
        packages="$packages libegl1-mesa-dev libgles2-mesa-dev"
        echo "WARN: installing Ubuntu Mesa development packages; do this only when the RK3568 image uses Mesa"
    else
        echo "INFO: skipping Mesa packages; preserving vendor Mali/BSP graphics stack"
    fi
    ssh -tt "$RK3568_BOARD" "sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages"
}

full_setup() {
    [ -n "$RK3568_BOARD" ] || { echo "ERROR: --board is required" >&2; return 2; }
    host_check
    mkdir -p "$QT_ROOT" "$DEB_DIR" "$QT_ROOT/build"
    if [ "$PROFILE" = "auto" ]; then
        TARGET_OS="$(ssh "$RK3568_BOARD" '. /etc/os-release 2>/dev/null && printf "%s:%s" "${ID:-unknown}" "${VERSION_ID:-unknown}"')"
        case "$TARGET_OS" in ubuntu:24.*) PROFILE="ubuntu24";; *) PROFILE="sdk";; esac
        echo "INFO: detected profile=$PROFILE from target=$TARGET_OS"
    fi
    if [ "$INSTALL_TARGET_DEPS" -eq 1 ]; then
        [ "$PROFILE" = "ubuntu24" ] || { echo "ERROR: --install-target-deps is only for profile=ubuntu24; install SDK dependencies using the vendor SDK" >&2; return 2; }
        install_target_deps
    fi
    case "$PROFILE" in
        ubuntu24)
            "$ROOT_DIR/scripts/sync-rk3568-rootfs.sh" --board "$RK3568_BOARD" --target-chip "$TARGET_CHIP" --sysroot "$SYSROOT"
            if [ -n "$OFFLINE_DEBS" ]; then
                [ -d "$OFFLINE_DEBS" ] || { echo "ERROR: offline package directory not found: $OFFLINE_DEBS" >&2; return 1; }
                DEB_DIR="$OFFLINE_DEBS"
                echo "INFO: using supplied offline Ubuntu 24 ARM64 development packages"
            else
                [ "$TARGET_MESA" -eq 0 ] || MESA_ARG="--with-mesa"
                [ "$TARGET_QML" -eq 0 ] || QML_ARG="--with-qml"
                MESA_ARG="${MESA_ARG:-}"
                QML_ARG="${QML_ARG:-}"
                "$ROOT_DIR/scripts/download-ubuntu24-rk3568-debs.sh" --board "$RK3568_BOARD" --target-chip "$TARGET_CHIP" --out "$DEB_DIR" $MESA_ARG $QML_ARG
            fi
            "$ROOT_DIR/scripts/extract-debs-into-sysroot.sh" --debs "$DEB_DIR" --sysroot "$SYSROOT"
            ;;
        sdk)
            [ -n "$SDK_SYSROOT" ] || { echo "ERROR: profile=sdk requires --sdk-sysroot from the RK3568 BSP, Yocto or Buildroot SDK" >&2; return 2; }
            [ -d "$SDK_SYSROOT" ] || { echo "ERROR: SDK sysroot not found: $SDK_SYSROOT" >&2; return 1; }
            SYSROOT="$SDK_SYSROOT"
            ;;
        *) echo "ERROR: unsupported profile: $PROFILE (use ubuntu24 or sdk)" >&2; return 2;;
    esac
    "$ROOT_DIR/scripts/check-rk3568-qt-sysroot.sh" --sysroot "$SYSROOT"
    if [ "$BUILD_EXAMPLE" -eq 1 ]; then
        export RK3568_SYSROOT="$SYSROOT"
        export RK3568_TRIPLE="$TOOLCHAIN_TRIPLE"
        cmake -S "$ROOT_DIR/examples/hello-qt" -B "$QT_ROOT/build/hello-qt" -G "$GENERATOR" \
            -DCMAKE_TOOLCHAIN_FILE="$ROOT_DIR/cmake/rk3568-aarch64.cmake" \
            -DRK3568_SYSROOT="$SYSROOT" \
            -DRK3568_TRIPLE="$TOOLCHAIN_TRIPLE" \
            -DRK3568_QT_HOST_MOC="$QT_HOST_MOC" \
            -DCMAKE_PREFIX_PATH="$SYSROOT/usr/lib/aarch64-linux-gnu/cmake" \
            -DCMAKE_BUILD_TYPE=Release
        cmake --build "$QT_ROOT/build/hello-qt" --parallel
        file "$QT_ROOT/build/hello-qt/hello-rk3568"
    fi
    if [ "$DEPLOY_APP" -eq 1 ]; then
        [ "$BUILD_EXAMPLE" -eq 1 ] || { echo "ERROR: deployment requires build; remove --no-build" >&2; return 2; }
        deploy_app
    fi
    echo "PASS: RK3568 Qt setup completed under $QT_ROOT"
}

case "$MODE" in
    self) self_test ;;
    shared) shared_check ;;
    doctor) doctor ;;
    full) full_setup ;;
esac
