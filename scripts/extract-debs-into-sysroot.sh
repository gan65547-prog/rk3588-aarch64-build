#!/usr/bin/env bash
set -euo pipefail

USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
SYSROOT="${USER_HOME}/rk3568-qt/sysroot"
DEB_DIR=""

usage() { echo "Usage: $0 --debs DIR [--sysroot DIR]"; }
while [ "$#" -gt 0 ]; do
    case "$1" in
        --debs) DEB_DIR="${2:?missing deb directory}"; shift 2 ;;
        --sysroot) SYSROOT="${2:?missing sysroot}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done
[ -n "$DEB_DIR" ] || { echo "ERROR: --debs is required" >&2; exit 2; }
[ -d "$DEB_DIR" ] || { echo "ERROR: directory not found: $DEB_DIR" >&2; exit 1; }
shopt -s nullglob
debs=("$DEB_DIR"/*.deb)
[ "${#debs[@]}" -gt 0 ] || { echo "ERROR: no .deb files in $DEB_DIR" >&2; exit 1; }

for deb in "${debs[@]}"; do
    echo "extracting $(basename "$deb")"
    dpkg-deb -x "$deb" "$SYSROOT"
done
# Ubuntu's Qt CMake metadata may refer to a multiarch qmake path while the
# package installs the executable under /usr/lib/qt5/bin.  Provide the
# expected compatibility symlink inside the target sysroot.
if [ -x "$SYSROOT/usr/lib/qt5/bin/qmake" ]; then
    mkdir -p "$SYSROOT/usr/lib/aarch64-linux-gnu/qt5/bin"
    ln -sfn ../../../qt5/bin/qmake "$SYSROOT/usr/lib/aarch64-linux-gnu/qt5/bin/qmake"
fi
echo "PASS: development packages extracted into $SYSROOT"
