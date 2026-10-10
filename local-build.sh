#!/data/data/com.termux/files/usr/bin/bash
# SungBox 本机构建脚本（Termux / 无 root）
# 用法：
#   ./local-build.sh            → debug 构建（默认，4 ABI + universal）
#   ./local-build.sh release    → release 构建（仅 arm64-v8a，签名与 GitHub Actions 一致）
# 依赖：
#   - ~/opt/gradle-9.7.0                 （wrapper 要求的版本，腾讯镜像可下）
#   - app/libs/libbox.aar                （与源码版本配对；本 fork 对应 sing-box 1.14.2）
#   - app/release.keystore + local.properties 中的签名项（release 构建需要；脚本会尝试自动补齐密钥文件）
#   - SDK 平台 / build-tools / aidl 垫片 → 见 docs/BUILD-On-Device.md
set -e
cd "$(dirname "$0")"

# 本机（校园网环境）使用阿里云镜像加速；CI 上不设置该变量，走 google()/mavenCentral()
export SUNG_BOX_CN_MIRRORS=1

if [ ! -f app/libs/libbox.aar ]; then
  echo "[!] 缺少 app/libs/libbox.aar（不入库，需手动下载）"
  echo "    本 fork 配对版本为 1.14.2："
  echo "    https://jitpack.io/com/github/singbox-android/libbox/1.14.2/libbox-1.14.2.aar"
  exit 1
fi

# 自动补齐签名密钥（与 CI 一致：~/.jinmanji/jinmanji-release.jks）
if [ ! -f app/release.keystore ] && [ -f "$HOME/.jinmanji/jinmanji-release.jks" ]; then
  cp "$HOME/.jinmanji/jinmanji-release.jks" app/release.keystore
  echo "[i] 已复制签名密钥到 app/release.keystore"
fi

export JAVA_HOME="${PREFIX:-/data/data/com.termux/files/usr}/lib/jvm/java-21-openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
unset ANDROID_NDK_HOME

GRADLE_BIN="$HOME/opt/gradle-9.7.0/bin/gradle"
if [ ! -x "$GRADLE_BIN" ]; then
  echo "[!] 未找到 gradle 9.7.0: $GRADLE_BIN"
  exit 1
fi

MODE="${1:-debug}"
case "$MODE" in
  debug)
    "$GRADLE_BIN" :app:assembleOtherDebug --console=plain --stacktrace
    ;;
  release)
    if [ ! -f app/release.keystore ]; then
      echo "[!] release 构建需要 app/release.keystore（或先放置 ~/.jinmanji/jinmanji-release.jks）"
      exit 1
    fi
    "$GRADLE_BIN" :app:assembleOtherRelease -PsungboxAbiOnly=arm64-v8a --console=plain --stacktrace
    ;;
  *)
    echo "用法: ./local-build.sh [debug|release]"
    exit 1
    ;;
esac
