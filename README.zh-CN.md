<p align="center">
  <img src="https://user-images.githubusercontent.com/14722250/93017676-1a009c00-f5fd-11ea-9b8e-c69c2cd4fa89.png" height=64 />
</p>

# eul

[English](README.md) | 简体中文

eul 是一款使用 SwiftUI 开发的 macOS 菜单栏系统监控工具。本项目基于 [gao-sun/eul](https://github.com/gao-sun/eul)，由 [20suiWXJB](https://github.com/20suiWXJB) 独立维护，保留原项目的 MIT 许可证和贡献者致谢。

![界面预览](https://user-images.githubusercontent.com/14722250/105626766-f718ab00-5e6c-11eb-9761-661ff85c8faf.jpg)

## 功能特点

- 支持深色模式。
- 提供 macOS 系统小组件。
- 显示蓝牙设备电量。
- 尽可能使用 SwiftUI 构建界面。
- 改善 Apple Silicon 传感器读取与 GPU 识别，已在 Apple M4 Pro 上测试。
- 打开 CPU、内存菜单时立即预填充进程列表。
- 支持显示或隐藏状态栏读数的单位。

## 系统要求

本分支要求 macOS 12.0 或更高版本。

安装包包含 arm64 和 x86_64 两种架构。硬件功能已在 Apple M4 Pro 上测试，其他 Mac 尚未完成实机验证。Release 版本的小组件共享功能尚未验收，本地 Debug 版本禁用小组件数据共享。

## 安装

1. 前往[本分支的最新发布页面](https://github.com/20suiWXJB/eul/releases/latest)，下载 DMG 安装包。
2. 如果 eul 正在运行，先退出应用。
3. 打开 DMG，将 `eul.app` 拖入 `Applications`（应用程序）文件夹。
4. 从应用程序文件夹启动 eul。

当前安装包使用 ad-hoc 签名，尚未经过 Apple 公证。应用沿用原版标识，安装时会替换已有的 eul，不能与原版同时安装。

原版 eul 的 Homebrew Cask 和 App Store 页面不是本分支的分发渠道，请使用本仓库的 Release 安装包。

## 更新

应用从 `20suiWXJB/eul` 检查新版本，并可在状态栏显示更新提示。发现新版本后，手动下载并安装新的 DMG。

本分支已关闭自动替换应用的更新方式；原有的“自动更新”设置会迁移为“在状态栏展示”更新提示。

## 本地构建与维护

开发环境、构建步骤和硬件验证范围见 [DEVELOPMENT.md](DEVELOPMENT.md)。运行不依赖实体硬件的回归检查，并构建通用 DMG：

```sh
/usr/bin/python3 Tests/run-regressions.py
bash Scripts/build-dmg.sh
```

安装包和 SHA256 校验文件输出到 `dist/` 目录。

在功能分支上开发，验证通过后合并到本仓库的 `master`。CI 会执行回归检查、构建 DMG，并上传构建产物。

发布时使用带 `v` 前缀、与应用版本一致的 Git 标签，同时提供 DMG 和 SHA256 校验文件。主程序与各个 Widget 的版本号应保持一致。

`origin` 指向自己的分支仓库；可保留指向 `gao-sun/eul` 的 `upstream`，按需查看并引入原项目的更新。

## 更新记录

查看[本分支的发布记录](https://github.com/20suiWXJB/eul/releases)和 [CHANGELOG.md](CHANGELOG.md)。

## 贡献者与许可证

感谢原作者及所有贡献者，完整名单见[英文 README 的贡献者部分](README.md#contributors)。

本项目沿用 [MIT 许可证](LICENSE)，保留原项目的版权声明和许可文本。

## 语言支持

```swift
let languages = [
  "简体中文", "English", "Arabic",
  "Deutsch", "Русский", "Español",
  "Português", "Монгол", "한국어",
  "日本語", "Français", "Українська",
  "Svenska", "Čeština", "Italiano",
  "繁體中文", "မြန်မာဘာသာ", "Magyar",
  "ไทย", "Türkçe"
];
```
