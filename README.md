# RK3568 Qt ARM64 一键交付包

这是一个面向 Ubuntu ARM64 编译机、Ubuntu 24 ARM64 RK3568 目标板的 Qt 交叉编译和部署资料包。

## 快速开始

```bash

./setup-rk3568-qt.sh --board 用户名@IP --target-chip rk3568 --profile ubuntu24 --install-target-deps --target-qml --no-deploy

```

编译完成后程序会自动上传到目标板 `/tmp/hello-rk3568`，启动方式：

```bash
ssh 用户名@RK3568_IP '/tmp/hello-rk3568/run.sh'
```

需要直接启动时增加 `--run`，图形后端通过 `--qpa eglfs|wayland|xcb|linuxfb` 选择。

完整中文教程见 [`docs/INSTALL.md`](docs/INSTALL.md)。脚本会拒绝非 ARM64 主机和未识别为 RK3568 的目标板；RK3588 只能用于验证共用的 ARM64/Qt/DRM 基础链路，不能替代 RK3568 实机验收。

常见问题见 [`docs/FAQ.md`](docs/FAQ.md)。

离线原理说明见 [`docs/RK3568-Qt-离线技术说明.md`](docs/RK3568-Qt-离线技术说明.md)。
