# 本地开发环境

本项目使用 Xcode、Swift / SwiftUI 和 Swift Package Manager（SPM），入口是 `eul.xcodeproj`，共享 Scheme 为 `eul`。

## 环境检查（2026-11-05）

| 项目 | 本机状态 | 后续操作 |
| --- | --- | --- |
| Mac | Apple Silicon（arm64），macOS 27.0.1 | 使用原生 arm64 工具链 |
| 完整 Xcode | 已安装 Xcode 27.2（27B52），已选为活动开发目录 | 首次初始化检查通过，macOS SDK 为 27.2 |
| Swift / Clang | Xcode 配套 Swift 6.4.2 工具链可用 | 工程目前配置 Swift 5 语言模式 |
| Git | 已有；当前 PATH 中自装 Git 在 SPM 检出时出现动态库错误 | 下方命令临时优先使用 `/usr/bin/git`，不修改全局配置 |
| Homebrew | 已安装 | 可用于安装命令行工具 |
| GitHub CLI | 已安装 gh 2.103.3，未登录 | 需要命令行推送、PR 等操作时运行 `gh auth login` |
| VS Code | 已安装 | 可编辑代码；构建和调试使用 Xcode |
| 签名证书 | Debug 已配置本地临时签名，不依赖 Apple 开发证书 | 正式发布时再配置自己的开发团队及发布证书 |

不需要另装独立 Swift、CocoaPods、Carthage、Node.js、Java 或 Docker。现有 CI 的 `xcpretty` 只用于美化日志，本地构建可省略。

Xcode 官方入口：<https://developer.apple.com/xcode/>。下载时只需准备 macOS 开发组件；本项目不需要 iOS、watchOS、tvOS 或 visionOS 模拟器运行时。

## 初始化与构建命令

本机已完成 Xcode 安装、开发目录选择及首次初始化，以下初始化步骤供以后重建环境使用。应用依赖已解析成功，工程已适配最低 macOS 12。默认 Debug 构建采用本地临时签名，已在 Xcode 中点击 Run 并确认应用运行。

1. 首次打开 Xcode，按提示由本人阅读并接受许可、安装所需组件。
2. 在终端选择开发工具目录并确认版本：

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   xcode-select -p
   xcodebuild -version
   ```

3. 在仓库目录解析锁定的应用依赖：

   ```sh
   cd /Users/Apple/Code/eul
   PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild \
     -resolvePackageDependencies \
     -project eul.xcodeproj \
     -scheme eul \
     -derivedDataPath DerivedData \
     -onlyUsePackageVersionsFromResolvedFile
   ```

4. 执行默认 Debug 构建（使用本地临时签名）：

   ```sh
   PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild \
     -project eul.xcodeproj \
     -scheme eul \
     -configuration Debug \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath DerivedData \
     -disableAutomaticPackageResolution \
     build
   ```

   该步骤验证编译和本地签名，不证明各项功能可用。工程中的 SwiftFormat 构建阶段会自动格式化源文件，编译后请检查 `git diff`。

5. 执行 `open eul.xcodeproj`，选择 `eul` Scheme 和 My Mac，点击 Run 运行调试。Debug 不需要登录 Apple 开发账号；程序默认不自动打开设置窗口，启动后先检查顶部菜单栏。

## 项目依赖

应用依赖由 Xcode/SPM 下载，版本记录在 `eul.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`：

| 依赖 | 当前锁定版本 |
| --- | --- |
| LaunchAtLogin | 4.2.0（精确锁定） |
| Localize-Swift | 3.1.0 |
| SwiftyJSON | 5.0.0 |
| SystemKit | 0.0.12 |

SwiftFormat 由 `BuildTools/Package.resolved` 锁定为 0.48.4，不需要通过 Homebrew 再安装一个版本。准备构建工具及只检查格式的命令：

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin swift build \
  --package-path BuildTools -c release --product swiftformat
BuildTools/.build/release/swiftformat --version
BuildTools/.build/release/swiftformat . --lint
```

## 首次适配时需处理的事项

- 七个 Target 的 Debug 配置已改为 `CODE_SIGN_IDENTITY = "-"`、`CODE_SIGN_STYLE = Manual`、`DEVELOPMENT_TEAM = ""`，即 Xcode 的 Sign to Run Locally。Release 仍保留原作者的签名配置，正式发布前需改用自己的 Team、Bundle ID 和 App Group；主程序及四个 Widget 的共享组需保持一致。本地临时签名不能替代正式分发所需的签名配置。
- 已将工程及全部 Target 的 Debug/Release 最低系统版本统一设为 macOS 12.0，适配当前 Xcode；该 fork 构建的应用不再支持 macOS 10.15/11。CI 已改用 `xcode-27` runner，执行无硬件依赖的回归检查及通用 DMG 构建；云端结果以 Actions 实际运行记录为准。
- 已将 SwiftFormat 构建脚本中的 `SDKROOT=macosx` 改为通过 `xcrun --sdk macosx --show-sdk-path` 获取 SDK 绝对路径，解决当前工具链报错 `invalid absolute path 'macosx'` 的问题。
- 已修复启动时 SMC 结构大小断言崩溃：协议长度字段固定为 `UInt32`；旧代码使用的 `IOByteCount` 在本机为 64 位，导致结构从要求的 80 字节变为 88 字节。已验证修复后的结构为 80 字节，keyInfo/result/data32/bytes 偏移分别为 28/40/44/48，保留原有断言。
- Scheme 没有 XCTest Target；本轮新增直接编译实际源码的独立回归检查，命令及硬件验证范围见下节。
- 更新检查及下载页面已改为 `20suiWXJB/eul`。当前采用手动 DMG 更新，旧自动更新设置回退为状态栏提示；旧 ZIP 下载器已移除，不会自动替换应用。

## 当前验证范围

已安装 GitHub CLI 2.103.3；使用 macOS 自带 Git 成功下载并编译 SwiftFormat 0.48.4，`--version` 验证通过。格式检查通过：128 个文件中 0 个需要格式化，未改动源文件。构建缓存位于已被忽略的 `BuildTools/.build/`。

Xcode 27.2 已安装并启用，`xcodebuild -checkFirstLaunchStatus` 检查通过。四个应用依赖均已按锁定版本下载、解析成功。

修复工程配置后，本机 Xcode 27.2 的 arm64 Debug 无签名构建已通过（`BUILD SUCCEEDED`），SwiftFormat 构建阶段也正常完成。已核对产物为 arm64，应用 `LSMinimumSystemVersion` 为 12.0。

随后复现 Xcode 默认构建的证书错误，修复七个 Target 的 Debug 本地签名后，默认命令行构建通过，不再传入关闭签名的覆盖参数。日志确认签名身份为 Sign to Run Locally。

在用户已打开的 Xcode 工程中实际点击 Run，定位并修复 SMC 结构长度断言后再次运行，Xcode 显示 Running eul；原来的 11 条构建错误已消除。核心监控数据、设置持久化、Widget 共享数据及正式发布尚未验证。

命令行构建产物位于 `DerivedData/Build/Products/Debug/eul.app`；Xcode 默认使用用户目录下的 DerivedData。Release 签名和应用标识未改变；LaunchAtLogin 后续升级至 4.2.0，见下节。构建仍有旧 API 弃用及 LaunchAtLogin 脚本输出声明警告，这些不阻塞本次编译。

构建通过日志：`/private/tmp/eul-build-fixed.log`（此前的无签名构建）、`/private/tmp/eul-xcode-default-fixed.log`（默认本地签名构建）。此前诊断日志：`/private/tmp/eul-resolve.log`、`/private/tmp/eul-build.log`、`/private/tmp/eul-build-macos12.log`、`/private/tmp/eul-xcode-default-before.log`。SMC 布局回归检查：`/private/tmp/eul-smc-layout-fixed.swift`。


## M4 Pro 原生 ARM 适配（2026-11-05）

本轮验收机器为 Apple M4 Pro / Mac16,8，macOS 27.0.1、Xcode 27.2。只确认本机结果；其他 Apple Silicon 和 Intel 均不视为已完成实机验收。

### 实现

- LaunchAtLogin 从 4.0.0 精确升级到 4.2.0（revision `e8171b3e38a2816f579f58f3dac1522aa39efe41`），其余依赖版本不变。旧 helper 仅含 x86_64，新 helper 含 x86_64、arm64。旧系统弹窗原文未取得，不能断定该 helper 是弹窗的唯一原因。
- 4.2.0 的 SPM 复制脚本在 `CODE_SIGN_ENTITLEMENTS` 为空时会误签 ZIP，修改 helper 的 Info.plist 后留下无效签名。工程复制阶段仅在 Debug 且允许签名时，使用 Xcode 当前本地签名身份重新签名嵌入的 helper；不修改依赖检出文件或 Release 签名流程。
- SMC 保留 80 字节结构断言；按驱动实际报告的类型和长度读取，解码 `flt `、`sp78`、`fpe2`，保留小数和有符号读数。无有效温度时为 nil / N/A；风扇的有效 0 RPM 保留。单个键失败不影响其他键，错误日志只在状态变化时输出。
- 根据芯片名称选择候选温度键，只读探测存在的键，不做需要额外权限的完整枚举。M4 CPU、GPU 和内存分组参考 Stats 的 `Modules/Sensors/values.swift`；M4 Pro/Max GPU 使用 `Tg1U`、`Tg1k` 和共同核心键，普通 M4 使用其对应候选。CPU/GPU 各取所属有效传感器平均值。Intel 原有候选键保留。
- ARM GPU 从 IOAccelerator 获取设备并通过 IORegistryEntry ID 关联统计，不再要求 PCI ID。使用 `Device Utilization %`，缺失的频率不估算；温度使用可用的驱动温度或 GPU 组 SMC 实测平均值。Intel 保留 PCI 匹配路径。
- CPU 显示按可选温度回退，不再以大于 0 判断有效；电池缺少设计容量时健康度显示 N/A，避免除零显示无穷大。
- 所有 Debug Target 的共享 Container 均禁用，不创建共享 suite、不跨进程写入、不请求时间线刷新；Widget 自身返回过期条目和 `.never` 策略，预览继续允许示例数据。设置页显示“本地调试未启用 Widget 数据共享。”。

### 回归命令

```sh
# 无需访问硬件；直接编译生产源码，测试解码、布局和匹配逻辑
/usr/bin/python3 Tests/run-regressions.py

# 只读验证当前机器的 SMC / GPU
/usr/bin/python3 Tests/run-regressions.py --hardware

# 额外运行四秒有界 Metal 负载，观察 GPU 使用率变化
/usr/bin/python3 Tests/run-regressions.py --hardware --gpu-load
```

脚本使用 Xcode 当前 SDK，在临时目录生成组合源码并运行。只有 GPU 所依赖的 UI 单例使用最小替身；SMC、温度模型、GPU 解析与匹配、Debug Container 均使用仓库实际源码。无 XCTest Target，不需要新增签名配置。

已通过的回归包括：结构 stride 80、字段偏移 28/40/44/48、浮点温度、正负 sp78、小数 fpe2、错误类型/长度、NaN/Infinity、零转速数值、读取失败清空旧值及恢复、M4 分组、无 PCI Apple GPU 匹配/不匹配、Intel PCI 样例匹配、缺失使用率和 Debug 存储禁用。

### 实机证据与边界

- 默认本地签名的 ARM Debug `clean build` 通过；日志 `/private/tmp/eul-arm-build.log`。`codesign --verify --deep --strict` 通过。
- 最终版本在 Xcode 点击 Run：2026-11-05 23:03:23 启动，23:09:23 同一 PID 98006 已连续运行 6 分钟，未暂停或退出；Xcode 显示 Running eul，观察期间未见架构弹窗或崩溃。最终控制台没有 SMC 解码错误、`com.gaosun.eul.shared` 或 CFPrefs 权限刷屏，仍存在前述 macOS linkd 服务连接错误。日志 `/private/tmp/eul-arm-xcode-final-console.log`，截图 `/private/tmp/eul-arm-xcode-running.png`；设置页截图 `/private/tmp/eul-arm-settings.png`。原架构弹窗没有原文对照，因此不将候选原因认定为唯一根因。
- 递归检查应用包中的 24 个 Mach-O 文件，均含 arm64；开机自启 helper 同时含 x86_64、arm64，无 Intel 独占组件。Xcode Run 使用的另一个 DerivedData 中 helper 也已核对为双架构。
- 实际读取到 9 个 CPU、8 个 GPU 核心传感器，类型为 `flt `。一次采样 CPU 约 66–79°C、GPU 约 60–67°C；读数随负载变化，不是固定基准。内存候选键在本机未读到，内存温度显示不可用。
- 两个风扇均读到有效数据：空闲时 0 RPM，后续约 2314 / 2498 RPM；最小/最大规格为 2317 / 7826 RPM。不写风扇控制值。
- Apple M4 Pro GPU 注册表关联成功。空闲样本为 0%，四秒 Metal 负载采样约 75–88%。驱动未提供 GPU 频率和温度字段；应用温度由 SMC GPU 分组提供，频率保持不可用。硬件日志 `/private/tmp/eul-arm-hardware.log`、`/private/tmp/eul-arm-hardware-final.log`。
- 在实际应用的 SMC 刷新断点现场读取存储：CPU 使用率约 27.8%，内存使用约 17.16 GiB，Wi-Fi `en0` 接收/发送约 12 / 518 KB/s，电池电量 80%，GPU 使用率 72%、温度约 66.4°C，风扇约 2307 / 2506 RPM。临时启用磁盘菜单后读取总量 989 GB、可用 367 GB，随后恢复原菜单配置。蓝牙 fetch 返回 0 台可用设备，未验证蓝牙外设电量；不视为真实外设功能验收。电池设计容量未提供，健康度显示不可用。
- 设置页已实测显示本地 Widget 提示；开机自启开关可关闭、重新开启，原启用状态已恢复。配置成功，登录验收待完成；需用户实际注销并重新登录，当前会话不执行注销。
- 正式签名、App Group 权限、真实 Widget 数据共享及发布包分发留待有开发者账号后验证；本地临时签名不能证明这些项目。Intel 仅验证 PCI/解码样例逻辑，未做实机验证。
- 控制台仍有 macOS `com.apple.linkd.autoShortcut` 连接错误和旧 API 弃用警告；本次不修改自动更新来源或扩展其他系统适配范围。

所有修改保留在本地工作区，没有提交或推送 GitHub。

## 本机 Widget 数据共享修复（2026-11-06）

本节替代上文 2026-11-05 的 Debug 共享禁用说明。Debug 和 Release 均改用普通偏好域 `com.gaosun.eul.widget-data`：主程序写入，四个 Widget 保留沙盒，只申请该域的 `com.apple.security.temporary-exception.shared-preference.read-only` 权限，不再声明旧 App Group。此配置用于当前 Mac 的临时签名构建，未验证正式签名或 App Store 分发。

数据有效期统一为采集后 60 秒，时间线失效节点使用同一截止时间，保留 10 秒的时间线刷新请求间隔。无有效数据时中英文提示改为数据不可用或已过期。四个 Widget 同时保留 macOS 14 容器背景适配、原有 16 点内边距和 macOS 12 兼容路径。

`/usr/bin/python3 Tests/run-regressions.py` 现编译为独立可执行文件，使用随机隔离偏好域并在完成后清理，验证 Codable、跨进程读取、缺失及损坏数据、60 秒有效期边界和时间线截止时间；测试不写入实际应用偏好域。该检查及原有 SMC/GPU 回归均通过，日志 `/private/tmp/eul-widget-sharing-regressions.log`。

arm64 Debug 和 arm64/x86_64 Release 构建均通过，日志分别为 `/private/tmp/eul-widget-sharing-debug.log`、`/private/tmp/eul-widget-sharing-release.log`。Release 按现有打包流程重签 helper 和主程序后，`codesign --verify --deep --strict` 通过，已原位安装并启动 `/Applications/eul.app`；此前应用备份为 `/private/tmp/eul-widget-sharing-backup-1p5sifxs/eul.app`。

实机已确认新偏好域持续写入 CPU、内存、网络和电池实时数据，日志未见新的共享写入权限错误。桌面原组件曾保留系统占位图；用户重新添加后确认正常。没有单独完成四类组件逐一截图或退出主程序后的 60 秒过期及重启恢复实机验收；过期逻辑由上述回归检查覆盖。
