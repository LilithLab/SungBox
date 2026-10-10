# 在手机上构建 SungBox（Termux / 无 root）

> 本 fork 可以在 Android 手机本机（Termux）上完成整套构建，不需要电脑。
> 已在：Android 16 / Termux / aarch64 上验证通过（Gradle 9.7.0 + AGP 9.3.1）。

## 0. 版本配对（必须一致）

- 源码：本仓库（基于 sing-box-for-android v1.14.2，commit fc21909）
- `libbox.aar`：JitPack 预编译 `com.github.singbox-android:libbox:1.14.2`
  - `https://jitpack.io/com/github/singbox-android/libbox/1.14.2/libbox-1.14.2.aar`（约 118 MB）
  - 放到 `app/libs/libbox.aar`（该目录已被 `.gitignore` 忽略，不入库）

## 1. 依赖工具

- Termux 包：`pkg install openjdk-21 aidl aapt2 curl unzip`
- Gradle 9.7.0（wrapper 要求的版本）：
  `https://mirrors.cloud.tencent.com/gradle/gradle-9.7.0-bin.zip` → 解压到 `~/opt/gradle-9.7.0`
- Android SDK（用 cmdline-tools 的 sdkmanager 正式安装，**不要手动解压 zip**——缺 `package.xml` 会导致 AGP 找不到平台）：
  - `platforms;android-37.1`（`:app` 的 compileSdk = 37 / minor 1）
  - `platforms;android-36`（`:libxposed-api` 的 compileSdk）
  - `build-tools;36.0.0`（AGP 对库模块的默认引用）与 `build-tools;37.0.0`（`:app` 使用）
- 全局 `~/.gradle/gradle.properties` 增加一行（用 Termux 原生 aapt2 覆盖）：
  `android.aapt2FromMavenOverride=$PREFIX/bin/aapt2`

## 2. aidl 垫片

Build-Tools 自带的 `aidl` 是 x86_64 二进制，手机 CPU 无法执行。安装 Termux 的 `aidl` 包后：

```bash
cd ~/opt/android-sdk/build-tools/37.0.0
mv aidl aidl.orig.x86_64
printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash' \
  'exec /data/data/com.termux/files/usr/bin/aidl "$@"' > aidl
chmod +x aidl
```

## 3. 构建

```bash
./local-build.sh
```

（脚本会检查 `~/opt/gradle-9.7.0` 与 `app/libs/libbox.aar`。）

产物：`app/build/outputs/apk/other/debug/`，包含 4 个 ABI 分片 + universal。

## 4. 已内置的本机适配（无需再做）

- `settings.gradle.kts`：阿里云镜像（google / gradle-plugin / public）；
- `gradle.properties`：JVM 4g、HTTP 超时 60s、Kotlin 编译 in-process；
- `app/build.gradle.kts`：注释 `ndkVersion`（设备无 NDK）并加 `keepDebugSymbols`
  跳过 strip；显式 `buildToolsVersion 37.0.0`。
