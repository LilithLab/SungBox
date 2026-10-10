#!/data/data/com.termux/files/usr/bin/bash
# SungBox 本机构建脚本（Termux / 无 root）
# 用法：  ./local-build.sh          （构建 otherDebug；产物在 app/build/outputs/apk/other/debug/）
# 依赖：
#   - ~/opt/gradle-9.7.0      （wrapper 要求的版本，腾讯镜像可下）
#   - app/libs/libbox.aar     （与源码版本配对；本 fork 对应 sing-box 1.14.2）
#   - SDK 平台 / build-tools / aidl 垫片 → 见 docs/BUILD-On-Device.md
set -e
cd "$(dirname "$0")"

if [ ! -f app/libs/libbox.aar ]; then
  echo "[!] 缺少 app/libs/libbox.aar（不入库，需手动下载）"
  echo "    本 fork 配对版本为 1.14.2："
  echo "    https://jitpack.io/com/github/singbox-android/libbox/1.14.2/libbox-1.14.2.aar"
  exit 1
fi

export JAVA_HOME="${PREFIX:-/data/data/com.termux/files/usr}/lib/jvm/java-21-openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
unset ANDROID_NDK_HOME

GRADLE_BIN="$HOME/opt/gradle-9.7.0/bin/gradle"
if [ ! -x "$GRADLE_BIN" ]; then
  echo "[!] 未找到 gradle 9.7.0: $GRADLE_BIN"
  exit 1
fi

"$GRADLE_BIN" :app:assembleOtherDebug --console=plain --stacktrace "$@"
