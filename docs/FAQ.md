# RK3568 Qt 交叉编译 FAQ

## Q1：为什么不能直接使用 RK3588 的 sysroot？

CPU 都是 ARM64 只代表指令集相同，不代表 glibc、Qt、DRM、GBM、EGL、Mali/Mesa ABI 相同。必须从实际 RK3568 板同步运行库和头文件；RK3588 只能验证通用 ARM64/Qt 流程。

## Q2：板端没有 sysroot 目录怎么办？

不需要板端存在该目录。`sync-rk3568-rootfs.sh` 在编译机执行，通过 SSH 读取板端 `/usr/lib` 和 `/usr/include`，写入编译机 `$HOME/rk3568-qt/sysroot`。

## Q3：什么时候安装 `libegl1-mesa-dev` 和 `libgles2-mesa-dev`？

只有板端确认使用 Ubuntu Mesa 时才安装并使用 `--target-mesa`。Rockchip BSP、厂商 Mali、Buildroot、Yocto 不应安装 Ubuntu Mesa 替换图形栈，应使用厂商 SDK/sysroot。

## Q4：出现 `Exec format error` 怎么办？

目标 Qt 工具是 ARM64，不能在 x86_64 主机直接运行。使用 `package/toolchains/` 内的 AArch64 GNU/Linux 工具链，并安装 `package/qt-host-tools/ubuntu24-amd64/` 中与目标 Qt 同版本的 Host Tools；Host Tools 依赖必须与客户 Ubuntu 版本一致。ARM64 编译机仍是当前已验证路径。

## Q5：出现 `Could not find the Qt platform plugin` 怎么办？

检查板端是否安装对应插件，并选择正确的 `--qpa`：单应用 DRM 用 `eglfs`，Wayland 桌面用 `wayland`，X11 用 `xcb`，无桌面基础验证用 `linuxfb`。

## Q6：出现 EGL/GBM/DRM 初始化失败怎么办？

确认 `/dev/dri/card0` 存在、用户有访问权限，并核对板端实际 GPU 用户态库。不要从 RK3588 复制 Mesa/Mali 库覆盖 RK3568。

## Q7：为什么 `--doctor` 报 Qt 缺失警告？

`doctor` 只做身份和主机预检。先执行板端依赖安装命令或运行 `--install-target-deps`，再执行完整构建部署。

## Q8：Qt Widgets 能编译，QML 却失败怎么办？

重新执行入口时增加 `--target-qml`，并确保目标 sysroot 包含 `qtdeclarative5-dev` 及其依赖。QML 资源还需要随应用部署。

## Q9：重复运行会不会破坏 sysroot？

同步脚本会把旧的 `lib` 目录改名为 `lib.previous.*.backup` 后再同步。确认新 sysroot 通过检查后再清理旧备份，不能在未验证前删除。

## Q10：没有真实 RK3568 能否发布“已验证”？

不能。没有 RK3568 实机时，只能声明脚本、自检、包架构和 RK3588 共用链路已验证；显示时序、触摸、字体、GPU 和开机启动必须在真实 RK3568 上验收。
