# RK3568 Qt 交叉编译交付指南

## 交付目标

在 Ubuntu ARM64 编译机当前用户家目录下的 `rk3568-qt` 中，使用 RK3568 板端软件环境构建 ARM64 Qt 应用，并一键部署到同版本 RK3568 系统。

## 目录

```text
<当前用户家目录>/rk3568-qt/
├── sysroot/                         # 从真实 RK3568 / 同步的本地副本
├── debs/                            # 从 RK3568 软件源下载的开发包
├── cmake/rk3568-aarch64.cmake      # CMake toolchain
├── scripts/                         # 同步、解包、校验脚本
├── examples/hello-qt/               # 最小 Qt Widgets 工程
└── qt-stage/                        # 自建 Qt target 安装前缀（可选）
```

## 目标系统选择

一键入口提供两种交付路径：

- `--profile ubuntu24`：目标板为 Ubuntu 24 ARM64，使用板端同版本软件源补齐开发包；
- `--profile sdk --sdk-sysroot <目录>`：目标板为厂商 BSP、Yocto 或 Buildroot，使用客户提供的目标 SDK sysroot。

入口会自动识别 Ubuntu 24；其他系统必须显式提供 SDK sysroot，以保证 Qt、图形和系统库与部署目标一致。

## 推荐执行顺序

1. 在真实 RK3568 板端确认 `aarch64`、系统版本和图形后端。
2. 运行交付包根目录的 `setup-rk3568-qt.sh`；入口会自动同步、检查、编译、部署并生成启动脚本。
3. 使用板端原生 Qt runtime 和平台插件部署验证。

完整命令示例见 `INSTALL.md`。

Qt Creator 图形化配置见 `QtCreator-交叉编译配置.md`。

验证范围和未验证的 RK3568 硬件项目见 `VALIDATION-REPORT.md`。
