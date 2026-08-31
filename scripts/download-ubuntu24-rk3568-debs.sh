#!/usr/bin/env bash
set -euo pipefail

BOARD=""
EXPECTED_CHIP="rk3568"
USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
OUT_DIR="${USER_HOME}/rk3568-qt/debs"
WITH_MESA=0
WITH_QML=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --board) BOARD="${2:?missing board}"; shift 2 ;;
        --target-chip) EXPECTED_CHIP="${2:?missing target chip}"; shift 2 ;;
        --out) OUT_DIR="${2:?missing output directory}"; shift 2 ;;
        --with-mesa) WITH_MESA=1; shift ;;
        --with-qml) WITH_QML=1; shift ;;
        -h|--help) echo "Usage: $0 --board user@board [--target-chip rk3568|rk3588] [--out DIR] [--with-qml] [--with-mesa]"; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    esac
done
case "$EXPECTED_CHIP" in rk3568|rk3588) ;; *) echo "ERROR: --target-chip must be rk3568 or rk3588" >&2; exit 2 ;; esac
[ -n "$BOARD" ] || { echo "ERROR: --board is required" >&2; exit 2; }
mkdir -p "$OUT_DIR"

TARGET_INFO="$(ssh "$BOARD" 'printf "arch=%s\n" "$(uname -m)"; printf "compatible="; tr "\000" "\n" </proc/device-tree/compatible 2>/dev/null | paste -sd, -')"
echo "$TARGET_INFO"
printf '%s\n' "$TARGET_INFO" | grep -q '^arch=aarch64$' || { echo "ERROR: target is not aarch64" >&2; exit 1; }
printf '%s\n' "$TARGET_INFO" | grep -q "rockchip,$EXPECTED_CHIP" || { echo "ERROR: target does not match --target-chip $EXPECTED_CHIP; refusing package download" >&2; exit 1; }

# apt-get --download-only resolves the complete package dependency closure but
# does not install or upgrade packages on the target board.
REMOTE_DIR="$(ssh "$BOARD" 'd=$(mktemp -d /tmp/rk3568-qt-debs.XXXXXX); mkdir -p "$d/archives"; printf "%s" "$d"')"
PACKAGES="qtbase5-dev qtbase5-dev-tools libgbm-dev libdrm-dev libinput-dev libxkbcommon-dev libc6-dev linux-libc-dev"
if [ "$WITH_QML" -eq 1 ]; then PACKAGES="$PACKAGES qtdeclarative5-dev"; fi
if [ "$WITH_MESA" -eq 1 ]; then
    PACKAGES="$PACKAGES libegl1-mesa-dev libgles2-mesa-dev"
    echo "WARN: downloading Mesa packages; use only with a Mesa-based RK3568 image"
fi
ssh -tt "$BOARD" "sudo apt-get update && sudo apt-get --download-only --reinstall -y -o Dir::Cache::archives='$REMOTE_DIR/archives/' install $PACKAGES"
scp "$BOARD:$REMOTE_DIR/archives"/*.deb "$OUT_DIR/"
ssh "$BOARD" "sha256sum '$REMOTE_DIR/archives'/*.deb" > "$OUT_DIR/BOARD-DEB-SHA256SUMS.txt"
echo "PASS: resolved target development package closure copied to $OUT_DIR"
echo "INFO: target download cache retained at $REMOTE_DIR for traceability"
