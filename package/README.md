# 可离线随包交付的工具与开发包

本目录面向普通 Linux x86_64 编译机；实际 RK3568 目标库仍必须来自目标板或厂商 SDK。

## 目录

```text
toolchains/
  arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
qt-host-tools/ubuntu24-amd64/
  Qt 5.15.13 的 qmake/moc 主机工具安装包
qt-target-debs/ubuntu24-arm64/
  ARM64 目标开发包参考目录（现有文件来自 RK3588，仅作格式参考）
official-reference/
  Rockchip 官方 RK3568/RK3588 简版数据手册
```

## Arm GNU 交叉编译器

`toolchains/` 中的 Arm GNU Toolchain 由 Arm 官方发布，宿主为 Linux x86_64，目标为 AArch64 GNU/Linux。解压后将其 `bin/` 添加到 `PATH`：

```bash
tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
export PATH="$PWD/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH"
aarch64-none-linux-gnu-g++ --version
```

此工具链可编译 ARM64 Linux 程序，但不能替代 RK3568 的 sysroot、Qt target 库和 GPU 用户态库。

## Qt Host Tools

`qt-host-tools/ubuntu24-amd64/` 的包用于 x86_64 Ubuntu 24 主机上的 `moc`、`qmake` 等工具。它们必须与目标 sysroot 的 Qt 版本匹配；本目录提供的是 Qt 5.15.13 示例，不得与其他 Qt 版本混用。

安装前需先核验依赖闭包；若主机可联网，推荐使用同版本 Ubuntu 软件源安装依赖后再用本目录覆盖安装。完整离线依赖闭包应由目标客户的 Ubuntu 版本生成。

## Qt Target 开发包

把从真实 RK3568 板的软件源下载出的 `.deb` 放入 `qt-target-debs/ubuntu24-arm64/`，并通过入口脚本显式使用：

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile ubuntu24 \
  --offline-debs ./package/qt-target-debs/ubuntu24-arm64
```

不得将 RK3588 的 EGL/Mesa/Mali 图形库作为 RK3568 目标包。

## 校验

生成或更新全部文件后，在本目录执行：

```bash
find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
sha256sum -c SHA256SUMS
```

## 官方来源

- [Arm GNU Toolchain 14.2.Rel1](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads/12-2-rel1)
- [Ubuntu Qt 源包目录](https://archive.ubuntu.com/ubuntu/pool/universe/q/qtbase-opensource-src/)
