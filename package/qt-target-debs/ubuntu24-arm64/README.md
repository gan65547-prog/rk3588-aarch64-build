# Ubuntu 24 ARM64 离线开发包

本目录包含从已验证的 Ubuntu 24 ARM64 环境收集的 Qt 5、Qt Quick、EGL、GLES、GBM、DRM、输入库及其开发依赖包，共 51 个 `.deb` 文件。

## 使用方式

本目录不会被入口脚本自动使用。原因是离线包必须来自与 RK3568 目标板相同的系统版本、Qt 版本和图形栈；自动使用来源为 RK3588 的参考包会有 ABI 风险。

只有在已核对该目录与目标板完全同源时，才显式传入：

```bash
./setup-rk3568-qt.sh \
  --board <用户>@<RK3568_IP> \
  --profile ubuntu24 \
  --offline-debs ./package/qt-target-debs/ubuntu24-arm64
```

## 适用范围

仅适用于 Ubuntu 24 ARM64，且目标板基础系统、glibc、Qt runtime 与该包版本兼容。交付前使用：

```bash
sha256sum -c SHA256SUMS
```

这些 `.deb` 仅补齐 sysroot 的开发头文件、链接库和 CMake 配置；目标板运行时仍以其自身系统镜像和图形栈为准。
