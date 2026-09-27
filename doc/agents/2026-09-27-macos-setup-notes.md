# macOS 开发环境交接（从 WSL 迁移）

日期：2026-09-27
状态：完成（Rust / Flutter 测试全绿，doctor 双端全勾）

## 环境拓扑

- 开发主环境：macOS 27.0（Apple Silicon），项目在 `~/Code/QuinHub/QuinHub`
- Android 调试：本机模拟器 / 真机 adb（无需 WSL 桥接）
- iOS：本机 Xcode 27.0 + iOS 27.0 Simulator，可直接构建（WSL 时期的 P2 缺口已具备补齐条件）

## 已安装组件与位置

| 组件 | 位置 | 备注 |
|---|---|---|
| fvm 4.3.1 | `/opt/homebrew/bin/fvm` | brew 安装 |
| Flutter 3.47.5 stable / Dart 3.13.4 | `~/fvm/versions` | 与 WSL 同版本；`app/.fvmrc` 锁定 stable |
| Rust 1.98.1 | `~/.cargo`（rustup） | targets 已装齐：Android×3 + iOS×2（同 rust-toolchain.toml） |
| frb codegen 2.13.0 | `~/.cargo/bin` | `cargo install --locked`，与 pubspec 一致 |
| Android SDK 36 | `~/Library/Android/sdk` | NDK r27c (27.2.12479018) 已装（`app/android/app/build.gradle.kts` 钉死此版本） |
| JDK 17 (Temurin) | `/Library/Java/JavaVirtualMachines/temurin-17.jdk` | |
| Xcode 27.0 | `/Applications/Xcode.app` | xcode-select 仍指向 CLT；用 DEVELOPER_DIR 覆盖，免 sudo |
| CocoaPods 1.17.0 | `/opt/homebrew` | brew 安装 |

## 环境变量（已写入 `~/.zshrc`）

```zsh
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## 与 WSL 的差异（重要）

- **不再需要 CARGO_TARGET_DIR**（那是 /mnt/d 慢盘的绕法）。Makefile 已按 `uname` 分流：macOS 下 JAVA_HOME 走 `/usr/libexec/java_home`，WSL 行为不变。
- **不需要 adb 桥接**，adb 直接可用；`fvm flutter run` 热重载链路本机直连，无 WSL 的 VM Service 限制。
- **xcode-select 已全局切换到 Xcode**（`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`，2026-09-27）。教训：DEVELOPER_DIR 环境变量能让 flutter doctor / xcodebuild 通过，但 iOS 构建深层子进程（objective_c hook 里 `xcrun --show-sdk-path --sdk iphonesimulator`）会丢失该变量、落回 CLT 报 "SDK cannot be located"——别依赖它，直接切指针。zshrc 里的 DEVELOPER_DIR 保留无害（与指针一致）。
- Xcode license 已接受；iOS 27.0 Simulator runtime 已就位，无需再下载。

## iOS 构建首次打通（2026-09-27，backlog P2 第 8 项）

- 仓库此前**没有 `app/ios/Podfile`**（从未构建过 iOS）：首次 `fvm flutter build ios` 由 flutter 工具自动生成标准 Podfile；`rust_builder` 以 path 插件形式接入，podspec 的 script phase 跑 cargokit `build_pod.sh` 产出 `libquinhub_bridge.a` 静态库 force-load 进 Runner。
- 首次构建的 pod 集成改动了 `app/ios/Flutter/{Debug,Release}.xcconfig`、`project.pbxproj`、`xcworkspace`，并新增 `Podfile` / `Podfile.lock`——均为标准 CocoaPods 集成产物，**应一并提交**（lock 入库原则同 pubspec.lock）。
- `app/ios/Runner/Info.plist` 已补 `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`（backlog 已知项：image_picker 没有它们运行即崩、上架必拒）。当前为英文文案，如需中文要加 InfoPlist.strings 本地化。
- 已知警告：`flutter_secure_storage` 与 `quinhub_bridge` 未支持 Swift Package Manager，未来 Flutter 版本会升级为 error（届时需迁移插件或关闭 SPM）。

## 验证结果（2026-09-27）

- `cargo test --workspace`：40 passed / 0 failed（api 23 + mock 集成 4 + context 5 + crypto 4 + storage 4）
- `fvm flutter analyze`：No issues found；`fvm flutter test`：4/4 通过
- `fvm flutter doctor`：全勾（Flutter / Android toolchain / Xcode / Chrome / 设备 / 网络）
- `make build-android`（2026-09-27）：✓ Built app-debug.apk（192M，首次约 5 分钟）；APK 内 `libquinhub_bridge.so` 三 ABI（arm64-v8a / armeabi-v7a / x86_64）齐全——WSL 的两个静默缺库坑（AGP 9 / crate 连字符名）在 macOS 未复现
- 模拟器 `quinmo-api36`（API 36）实机验证：`adb install -r` + 启动成功，首页空态正常渲染（Rust bridge + SQLite 初始化正常）
- `fvm flutter build ios --simulator --debug`：✓ Built Runner.app；iPhone 17 模拟器（iOS 27.0）install + launch 成功，首页空态正常渲染（**iOS 首次跑通**）

## 尚未验证

- iOS 真机构建 / 签名 / IPA（需 Apple 开发者账号与证书）；CI 的 build-ios 骨架仍未启用。
- mock_sse 全链路联调（见 m4 笔记）在 macOS 未重跑。
