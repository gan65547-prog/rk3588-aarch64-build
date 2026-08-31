# RK3568 Qt 交叉编译交付包使用说明

本文档对应唯一入口 `setup-rk3568-qt.sh`，客户无需手工运行 `scripts/` 下的脚本。

## 支持范围

- 编译机：Ubuntu 24.04 ARM64，`uname -m` 必须为 `aarch64`；
- 目标板：Ubuntu 24.04、ARM64，设备树包含 `rockchip,rk3568`；
- SSH 账号可执行 `sudo apt-get`；
- Qt、glibc、GPU 图形栈以目标板实际版本为准。

x86_64 编译机需要“x86_64 Qt Host Tools + AArch64 GNU/Linux 工具链 + 与板端一致的 target sysroot”。交付包 `package/` 已提供可离线随包交付的工具链和 Qt Host Tools 示例，但 Qt Host Tools 的依赖闭包仍必须与客户 Ubuntu 版本匹配；未完成该匹配前，使用 ARM64 编译机是当前已验证路径。厂商 BSP、Buildroot、Yocto 或非 Ubuntu 系统使用 `--profile sdk`，不要注入 Ubuntu Mesa 包。

## 芯片型号校验

入口默认期望目标为 RK3568，并读取目标板设备树的 `compatible` 严格比对。测试其他 Rockchip 板时显式指定型号，例如：

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3588_IP> \
  --target-chip rk3588 --profile ubuntu24 --no-deploy
```

期望型号与设备树不一致时，脚本会停止，不会同步 Sysroot 或下载目标包。该参数只控制芯片身份校验，不会让 RK3588 的 GPU/图形库变成 RK3568 兼容库。

在 x86_64 Ubuntu 主机使用随包 Arm GNU 工具链时：

```bash
cd <资料包目录>/package/toolchains
tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
export PATH="$PWD/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH"
export RK3568_TOOLCHAIN_TRIPLE=aarch64-none-linux-gnu
```

安装 x86_64 Qt Host Tools 后，找到本机 `moc` 路径（Ubuntu 常见为 `/usr/lib/qt5/bin/moc`），再执行：

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile ubuntu24 \
  --toolchain-triple aarch64-none-linux-gnu \
  --qt-host-moc /usr/lib/qt5/bin/moc
```

`package/qt-host-tools/ubuntu24-amd64/` 随包提供 Qt 5.15.13 的 `qtbase5-dev-tools`、`qt5-qmake-bin`、`qt5-qmake` 安装包。它们只适用于 Ubuntu 24 x86_64；其依赖库必须与客户 Ubuntu 版本匹配。

## 1. 解包、自检和路径

```bash
cd <资料包目录>
chmod +x setup-rk3568-qt.sh scripts/*.sh
./setup-rk3568-qt.sh --self-test
```

默认工作目录由当前登录用户动态推导为 `$HOME/rk3568-qt`，不会写死 `/home/gan`。可自定义：

```bash
export RK3568_QT_ROOT="$HOME/rk3568-qt"
export RK3568_SYSROOT="$RK3568_QT_ROOT/sysroot"
```

## 2. 连接并识别 RK3568

将 `<用户>`、`<RK3568_IP>` 替换为真实值：

```bash
ssh <用户>@<RK3568_IP> 'uname -m; tr "\000" "\n" </proc/device-tree/compatible'
./setup-rk3568-qt.sh --doctor --board <用户>@<RK3568_IP>
```

必须看到 `aarch64` 和 `rockchip,rk3568`。Qt 缺失警告允许出现，因为下一步会安装依赖。

## 3. 在板端安装开发依赖

Ubuntu Mesa 图形栈才执行下面的完整命令：

```bash
ssh <用户>@<RK3568_IP> 'sudo apt-get update && sudo apt-get install -y libc6-dev linux-libc-dev qtbase5-dev qtbase5-dev-tools qtdeclarative5-dev libegl1-mesa-dev libgles2-mesa-dev libgbm-dev libdrm-dev libinput-dev libxkbcommon-dev'
```

若是 Rockchip BSP、厂商 Mali 用户态，禁止用 Mesa 替换图形库，只安装通用包：

```bash
ssh <用户>@<RK3568_IP> 'sudo apt-get update && sudo apt-get install -y libc6-dev linux-libc-dev qtbase5-dev qtbase5-dev-tools qtdeclarative5-dev libgbm-dev libdrm-dev libinput-dev libxkbcommon-dev'
```

也可由入口脚本执行（需要板端 sudo）：

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile ubuntu24 --install-target-deps --target-qml
```

确认板端为 Mesa 时再追加 `--target-mesa`。

## 4. 从板端同步 sysroot、下载同源软件包

板端没有 `sysroot/` 目录是正常的。入口会从板端同步 `/usr/lib` 和 `/usr/include`，再从板端配置的软件源下载依赖并解包到 `$HOME/rk3568-qt/sysroot`。推荐一条命令完成：

```bash
./setup-rk3568-qt.sh \
  --board <用户>@<RK3568_IP> \
  --profile ubuntu24 \
  --install-host-deps \
  --install-target-deps \
  --target-qml \
  --no-deploy
```

确认 Mesa 时加 `--target-mesa`。脚本会拒绝 RK3588 或其他型号，避免误用 sysroot。

离线重复构建时，使用同一块 RK3568 板下载的 `.deb`：

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile ubuntu24 --offline-debs <同源deb目录> --no-deploy
```

资料包内 `package/qt-target-debs/ubuntu24-arm64` 仅作格式参考，不默认注入 RK3568；其中图形包来自 RK3588，不能视为 RK3568 兼容包。必须通过 `--offline-debs` 显式指定已从真实 RK3568 板采集的包目录。

## 5. 编译、部署和运行

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile ubuntu24 --qpa eglfs
ssh <用户>@<RK3568_IP> '/tmp/hello-rk3568/run.sh'
```

脚本会编译示例、复制到板端 `/tmp/hello-rk3568` 并生成启动脚本。已有 Wayland/X11 会话时使用 `--qpa wayland` 或 `--qpa xcb`；需要部署后立即启动时增加 `--run`。`eglfs` 需要 `/dev/dri/card0`、匹配的 EGL/GBM 和 QPA 插件。

## 6. 不使用 CMake：直接用 Makefile

交付包提供 `examples/hello-qt-make/`，默认使用当前用户 Sysroot 和 AArch64 交叉编译器：

```text
编译器：aarch64-linux-gnu-g++
Sysroot：$HOME/rk3568-qt/sysroot
Qt 库：$HOME/rk3568-qt/sysroot/usr/lib/aarch64-linux-gnu
Qt 头文件：$HOME/rk3568-qt/sysroot/usr/include/aarch64-linux-gnu/qt5
```

执行：

```bash
cd examples/hello-qt-make
make print-config
make -j2
file hello-qt-make
```

`file` 应显示 `ARM aarch64`。也可以显式指定工具链：

```bash
make SYSROOT="$HOME/rk3568-qt/sysroot" \
  TRIPLE=aarch64-linux-gnu CXX=aarch64-linux-gnu-g++
```

使用 Arm 独立工具链时，将其 `bin/` 加入 `PATH` 后改用 `TRIPLE=aarch64-none-linux-gnu`。工具链、Sysroot 和 Qt 目标库必须保持同一目标环境。

## 7. 验收与排障

```bash
file "$HOME/rk3568-qt/build/hello-qt/hello-rk3568"
ssh <用户>@<RK3568_IP> 'ldd /tmp/hello-rk3568/hello-rk3568'
ssh <用户>@<RK3568_IP> 'QT_DEBUG_PLUGINS=1 /tmp/hello-rk3568/run.sh'
```

`file` 必须显示 `ARM aarch64`。QPA 插件错误检查 `--qpa` 与板端插件；EGL/GBM 错误检查板端 GPU 栈，不能直接复制 RK3588 的 Mesa/Mali 库。

## 8. 厂商 SDK 模式

```bash
./setup-rk3568-qt.sh --board <用户>@<RK3568_IP> --profile sdk --sdk-sysroot <SDK目标sysroot> --no-deploy
```

SDK 必须同时提供匹配的交叉编译器、Qt 开发文件和图形库；若有 `environment-setup-*`，先在当前终端执行。当前 SDK 模式不替换厂商编译器，任意 Yocto/Buildroot SDK 可能需要工具链文件调整。

## 9. 交付边界

已验证脚本语法、包架构检查、RK3588 共用 ARM64/DRM/EGL 路径和错误板卡拦截；无真实 RK3568 硬件时，不能宣称显示时序、触摸、字体、GPU 或开机启动已验证。正式销售前必须用客户 RK3568 镜像完成“安装—同步—编译—部署—运行”验收。
