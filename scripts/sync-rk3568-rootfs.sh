#!/usr/bin/env bash
set -euo pipefail

# Build a local RK3568 sysroot from the target board's runtime filesystem.
# Run this on the Ubuntu build host, never on the target board.

BOARD=""
EXPECTED_CHIP="rk3568"
USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
SYSROOT="${USER_HOME}/rk3568-qt/sysroot"
MANIFEST=""

usage() {
    echo "Usage: $0 --board user@board [--target-chip rk3568|rk3588] [--sysroot DIR] [--manifest FILE]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --board) BOARD="${2:?missing board}"; shift 2 ;;
        --target-chip) EXPECTED_CHIP="${2:?missing target chip}"; shift 2 ;;
        --sysroot) SYSROOT="${2:?missing sysroot}"; shift 2 ;;
        --manifest) MANIFEST="${2:?missing manifest}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$EXPECTED_CHIP" in rk3568|rk3588) ;; *) echo "ERROR: --target-chip must be rk3568 or rk3588" >&2; exit 2 ;; esac

if [ -z "$BOARD" ]; then
    echo "ERROR: --board is required; never guess the RK3568 board" >&2
    usage >&2
    exit 2
fi

command -v rsync >/dev/null || { echo "ERROR: rsync is required" >&2; exit 1; }
command -v ssh >/dev/null || { echo "ERROR: ssh is required" >&2; exit 1; }

TARGET_INFO="$(ssh "$BOARD" 'printf "arch=%s\n" "$(uname -m)"; printf "compatible="; tr "\000" "\n" </proc/device-tree/compatible 2>/dev/null | paste -sd, -')"
echo "$TARGET_INFO"
printf '%s\n' "$TARGET_INFO" | grep -q '^arch=aarch64$' || {
    echo "ERROR: target is not aarch64" >&2; exit 1;
}
printf '%s\n' "$TARGET_INFO" | grep -q "rockchip,$EXPECTED_CHIP" || {
    echo "ERROR: target does not match --target-chip $EXPECTED_CHIP; refusing to sync" >&2; exit 1;
}

mkdir -p "$SYSROOT/usr/lib" "$SYSROOT/usr/include"

# Ubuntu 24 uses usr-merge.  Keep one canonical library tree.
if [ -e "$SYSROOT/lib" ] || [ -L "$SYSROOT/lib" ]; then
    mv "$SYSROOT/lib" "${SYSROOT}/lib.previous.$$.backup"
fi
ln -s usr/lib "$SYSROOT/lib"

for path in /usr/lib /usr/include; do
    rsync -aH --delete --safe-links --human-readable --info=progress2 \
        "$BOARD:$path/" "$SYSROOT$path/"
done

test -f "$SYSROOT/lib/aarch64-linux-gnu/libc.so.6" || {
    echo "ERROR: target libc.so.6 missing; wrong board or incomplete sync" >&2
    exit 1
}

if [ -z "$MANIFEST" ]; then
    MANIFEST="$SYSROOT/BOARD-MANIFEST.txt"
fi
{
    echo "board=$BOARD"
    echo "captured_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ssh "$BOARD" 'uname -a; cat /etc/os-release; tr "\000" "\n" </proc/device-tree/compatible 2>/dev/null || true; ldd --version 2>&1 | head -1'
} > "$MANIFEST"

echo "PASS: $EXPECTED_CHIP rootfs sysroot synchronized at $SYSROOT"
echo "INFO: any previous lib tree was preserved as ${SYSROOT}/lib.previous.*.backup"
