# M1 脚手架环境搭建交接（WSL2）

日期：2026-09-23
状态：完成（APK debug 构建通过）

## 环境拓扑

- 开发主环境：WSL2（Debian 12），项目在 `/mnt/d/WorkSpaces/QuinHub`
- Android 调试：Windows 侧 Android Studio 模拟器（adb 桥接待配，见下）
- iOS：无本地 Mac，构建走 CI（M5 前打通）

## 已安装组件与位置

| 组件 | 位置 | 备注 |
|---|---|---|
| Rust stable | `~/.cargo`（rustup 管理） | targets: aarch64/armv7/x86_64-linux-android + iOS 两个 |
| fvm 4.3.1 | `~/.local/bin/fvm` | 独立二进制 |
| Flutter 3.47.5 stable / Dart 3.13.4 | `~/fvm/versions/stable` | `fvm global stable` 已设 |
| Android SDK 36 | `~/Android/Sdk` | platform-tools / build-tools 36.0.0 / cmake 3.22.1 |
| NDK r27c (27.2.12479018) | `~/Android/Sdk/ndk/27.2.12479018` | 官网直装（sdkmanager 下不动） |
| JDK 17 (Temurin) | `~/.jdk/temurin-17` | 系统 java 是 JRE，Gradle 必须用它 |
| frb codegen 2.13.0 | `~/.cargo/bin` | cargo install |
| busybox | `~/.local/bin`（含 unzip 软链） | 系统无 unzip 且无 sudo |

## 环境变量（每个新 shell 需要）

```bash
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export JAVA_HOME=$HOME/.jdk/temurin-17
export CARGO_TARGET_DIR=$HOME/cargo-targets/quinhub   # /mnt/d 上编译慢，target 放 Linux 盘
```

Makefile 里已内置 JAVA_HOME / CARGO_TARGET_DIR 默认值。

## 踩坑记录（重要）

1. **sdkmanager 下载 zip 损坏**（"Error on ZipFile unknown archive"）：加 `-Djava.net.preferIPv4Stack=true` 后主体恢复；NDK 始终失败，改官网直链 + busybox unzip 解压（保留执行权限，python zipfile 会丢）。
2. **AGP 必须 < 9**：模板默认 AGP 9.1.0，cargokit 用已移除的 `libraryVariants` API，导致 Rust 库编译了但不打进 APK（APK 只有 libflutter.so）。已降 8.13.0（`app/android/settings.gradle.kts`）。
3. **Rust crate 名必须下划线**：`quinhub-bridge` → cargokit 找 `libquinhub-bridge.so`，实际产物 `libquinhub_bridge.so`，APK 静默缺库。已改名 `quinhub_bridge`。
4. **cargokit 状态不自愈**：产物在 `app/build/quinhub_bridge/`，排查时整体删掉重来。
5. 无 sudo：unzip 用 busybox 提供；JDK 用 Temurin 解压版；都在用户目录，不动系统。

## adb 桥接（Windows 模拟器，待做）

WSL2 里 Flutter 要看到 Windows 模拟器，两条路线任选：
- 路线 A（推荐）：Windows 侧 `adb.exe -a nodaemon server`（监听所有接口），WSL 侧 `export ADB_SERVER_SOCKET=tcp:<Windows主机IP>:5037`
- 路线 B：把 `~/Android/Sdk/platform-tools/adb` 换成 shim，转发调用 Windows 的 `adb.exe`（通过 /mnt/c 路径或 `adb.exe` interop），WSL 与 Windows 的 adb 版本需一致（35.x 对 35.x）

配好后 `fvm flutter devices` 应能看到模拟器，然后 `fvm flutter run` 验证 echo 流式界面。
