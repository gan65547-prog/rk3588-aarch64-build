# Qt Creator 配置 RK3568/RK3588 交叉编译

Qt Creator 只负责项目编辑、CMake 配置和编译；Sysroot 同步、板端依赖安装仍建议先由根目录的 `setup-rk3568-qt.sh` 完成。

## 一、准备工作

先在终端完成一次环境准备（以 RK3568 为例；RK3588 测试时把型号改为 `rk3588`）：

```bash
./setup-rk3568-qt.sh --board <用户>@<目标IP> \
  --target-chip rk3568 --profile ubuntu24 \
  --install-target-deps --target-qml --no-deploy
```

确认以下文件存在：

```text
$HOME/rk3568-qt/sysroot/usr/lib/aarch64-linux-gnu/cmake/Qt5/Qt5Config.cmake
$HOME/rk3568-qt/sysroot/usr/lib/aarch64-linux-gnu/qt5/bin/qmake
```

## 二、Qt Creator 的 Kit 配置

打开 Qt Creator，进入“工具 → 选项 → Kits”。

### 1. 编译器

新增 C 编译器：

```text
/usr/bin/aarch64-linux-gnu-gcc
```

新增 C++ 编译器：

```text
/usr/bin/aarch64-linux-gnu-g++
```

编译器 ABI 选择 AArch64、Linux、GCC。不要把主机的 `/usr/bin/g++` 当成交叉编译器。

### 2. CMake

选择系统 CMake，例如：

```text
/usr/bin/cmake
```

### 3. Qt 版本

Qt Creator 使用 CMake 项目时，不需要把目标板的 ARM64 `qmake` 当作主机 Qt。推荐直接使用 CMake 工具链文件，并在项目配置中指定 Qt 的 CMake 前缀路径。

### 4. Kit 的 CMake 配置

在 Kit 的 CMake Configuration 中加入：

```text
CMAKE_TOOLCHAIN_FILE:FILEPATH=<交付包目录>/cmake/rk3568-aarch64.cmake
RK3568_SYSROOT:PATH=<用户家目录>/rk3568-qt/sysroot
RK3568_TRIPLE:STRING=aarch64-linux-gnu
CMAKE_PREFIX_PATH:PATH=<用户家目录>/rk3568-qt/sysroot/usr/lib/aarch64-linux-gnu/cmake
```

例如：

```text
CMAKE_TOOLCHAIN_FILE:FILEPATH=/opt/rk3568-qt-delivery/cmake/rk3568-aarch64.cmake
RK3568_SYSROOT:PATH=/home/gan/rk3568-qt/sysroot
RK3568_TRIPLE:STRING=aarch64-linux-gnu
CMAKE_PREFIX_PATH:PATH=/home/gan/rk3568-qt/sysroot/usr/lib/aarch64-linux-gnu/cmake
```

路径必须替换为当前用户的实际路径，不要照抄 `/home/gan`。

## 三、x86_64 编译机的 Qt Creator

x86_64 编译机必须同时具备：

- x86_64 主机 Qt 5 工具（至少 `moc`、`rcc`、`uic`）；
- AArch64 交叉编译器；
- 目标板 Sysroot。

在 CMake Configuration 额外加入：

```text
RK3568_QT_HOST_MOC:FILEPATH=/usr/lib/qt5/bin/moc
```

这里的 `moc` 必须是 x86_64 可执行文件，不能填写 Sysroot 里的 ARM64 `moc`。

如果使用交付包中的 Arm 独立工具链：

```text
RK3568_TRIPLE:STRING=aarch64-none-linux-gnu
```

并确保该工具链的 `bin/` 已加入 Qt Creator 启动环境的 `PATH`，或在 Kit 中选择对应的 `aarch64-none-linux-gnu-g++`。

## 四、构建项目

打开 `examples/hello-qt`，选择刚创建的 Kit，点击“配置项目”，然后点击构建。构建产物应满足：

```bash
file <构建目录>/hello-rk3568
```

输出必须包含：

```text
ARM aarch64
```

## 五、部署和运行

Qt Creator 中的构建成功不等于板端显示成功。推荐使用终端部署：

```bash
scp <构建目录>/hello-rk3568 <用户>@<目标IP>:/tmp/
ssh <用户>@<目标IP> 'QT_QPA_PLATFORM=eglfs /tmp/hello-rk3568'
```

`eglfs` 需要目标板检测到显示器和 DRM 连接器；如果通过 SSH 启动提示 `no screens available`，检查 HDMI、`/sys/class/drm/*/status` 和本地 TTY。Wayland 桌面使用 `QT_QPA_PLATFORM=wayland`。

## 六、常见错误

| 错误 | 原因 | 处理 |
|---|---|---|
| 使用 `/usr/bin/g++` | 选成了主机编译器 | 改为 `aarch64-linux-gnu-g++` |
| `RK3568_SYSROOT must be set` | Kit 没传 Sysroot | 添加 `RK3568_SYSROOT:PATH=...` |
| `Qt5Config.cmake not found` | CMake 前缀路径错误 | 指向 Sysroot 下的 `usr/lib/aarch64-linux-gnu/cmake` |
| x86_64 主机缺少 `moc` | 没有 Qt Host Tools | 安装 x86_64 Qt5 工具并设置 `RK3568_QT_HOST_MOC` |
| `no screens available` | 板端无显示器或无 DRM 会话 | 接显示器并在板端本地 TTY 运行 |
