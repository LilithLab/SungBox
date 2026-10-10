# SungBox

基于 [sing-box-for-android](https://github.com/SagerNet/sing-box-for-android)（SFA）的非官方 fork：**代理走蜂窝、直连走 WiFi、蜂窝断开即断网（fail-closed）**——为校园网等会深度检查流量的环境而做。

## 双网分流规则（核心）

SungBox 的全部行为可以概括为：**该走代理的流量只从蜂窝出，该直连的流量只从 WiFi 出；任何一边不可用时宁可失败，也不换路。**

### 规则明细

| 流量 | 匹配方式（sing-box 配置） | 出口 |
| --- | --- | --- |
| 代理流量（默认） | `route.final = "proxy"` | 蜂窝 → 隧道（VLESS + REALITY 等） |
| 国内网站 / IP | `rule_set: geosite-cn`、`geoip-cn` | WiFi 直连 |
| 内网 / 私网地址 | `ip_is_private: true` | WiFi 直连 |
| 国内域名解析 | DNS 命中 `geosite-cn` 或 `.cn` 后缀 | 阿里 DoH（223.5.5.5:443）经 WiFi |
| 其他域名解析 | `dns.final` | 1.1.1.1 经隧道 |

出口的"绑定"靠 sing-box 的 `network_type` 字段：

- 代理出口：`"network_type": ["cellular"]` —— 只从蜂窝网络发起连接；
- 直连出口：`"network_type": ["wifi"]` —— 只从 WiFi 发起连接。

（`network_type` 是 Android / Apple 图形客户端专有能力，需要开启 `route.auto_detect_interface`。）

### 不同网络状态下的行为

| 场景 | 直连（国内网站） | 代理（外网） |
| --- | --- | --- |
| WiFi + 蜂窝 都在线 | ✅ 走校园 WiFi | ✅ 走蜂窝隧道 |
| 只有 WiFi（移动数据关闭） | ✅ 正常 | ❌ 直接失败（**fail-closed**，绝不回落 WiFi） |
| 只有蜂窝（离开校园） | ❌ 失败（直连只绑定 WiFi） | ✅ 走蜂窝隧道 |
| 校园 WiFi 抖动 / 断开 | ❌ 直连失败 | ✅ 不受影响 |
| 蜂窝抖动 / 关闭 | ✅ 不受影响 | ❌ 隧道断，连接失败（恢复后自动重连） |

两个"❌"都是有意设计：

- **代理绝不回落 WiFi**：校园网 DPI 能识别 VLESS 等协议，若蜂窝不可用时隧道悄悄从校园网重建，等于主动把协议特征交给 DPI；
- **直连只绑定 WiFi**：避免国内流量消耗蜂窝流量（移动流量更贵）。如果你希望"没有 WiFi 时直连自动切到蜂窝"，把 `direct` 出口改为 fallback 策略即可（`network_strategy: "fallback"` + `fallback_network_type: ["cellular"]`）。

### 蜂窝保活（让代理能一直走蜂窝）

SFA 只为"默认网络"保活。部分 ROM 在 WiFi 连上后直接断开蜂窝数据，此时 `network_type: ["cellular"]` 会报 `no available network interface`。SungBox 在内核运行期间额外持有一个 `CELLULAR + INTERNET` 的 `requestNetwork`，保证蜂窝随时可用：

```kotlin
// app/src/main/java/io/nekohasekai/sfa/bg/DefaultNetworkListener.kt  [SungBox]
private val cellularKeepAliveRequest = NetworkRequest.Builder().apply {
    addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
    addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}.build()
```

### 配置骨架

```jsonc
{
  "outbounds": [
    { "type": "vless", "tag": "proxy", "server": "…", "network_type": ["cellular"], /* … */ },
    { "type": "direct", "tag": "direct", "network_type": ["wifi"] }
  ],
  "route": {
    "final": "proxy",
    "default_domain_resolver": "dns-cn",   // sing-box >= 1.14 必填
    "auto_detect_interface": true,
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": ["geosite-cn"], "outbound": "direct" },
      { "rule_set": ["geoip-cn"], "outbound": "direct" }
    ]
  }
}
```

完整可用的校园场景示例（含 DNS 拆分、规则集经隧道下载）：[`examples/campus-dual-network.example.json`](examples/campus-dual-network.example.json)。

## 构建

### 常规方式

1. 准备 `libbox.aar`（本仓库不包含）：
   - 本 fork 对应 sing-box **v1.14.2** → 使用配套的 JitPack 预编译版本（`com.github.singbox-android:libbox:1.14.2`）：
     `https://jitpack.io/com/github/singbox-android/libbox/1.14.2/libbox-1.14.2.aar`
   - 放到 `app/libs/libbox.aar`
2. `./gradlew :app:assembleOtherDebug` —— 产物：`app/build/outputs/apk/other/debug/SungBox-1.14.2-*.apk`

### 手机本机构建（Termux / 无 root）

本仓库已内置手机端构建所需的全部适配，详见 [`docs/BUILD-On-Device.md`](docs/BUILD-On-Device.md)。一句话：

```bash
./local-build.sh            # debug 构建（全 ABI）
./local-build.sh release    # release 构建（仅 arm64-v8a，签名与 CI 一致）
```

## 发布与 CI

- 在 GitHub **发布 Release** 会触发 [`release.yml`](.github/workflows/release.yml)：自动构建**签名的 arm64-v8a** APK，附 SHA-256 一并挂到 Release；也可在 Actions 页手动运行（产物在 workflow artifact 里）。
- 签名材料通过**仓库机密**注入（永不入库）：
  - `KEYSTORE_BASE64` —— 密钥文件的 base64（构建时解码为 `app/release.keystore`）；
  - `LOCAL_PROPERTIES` —— 包含 `KEYSTORE_PASS`、`ALIAS_NAME`、`ALIAS_PASS` 的 properties 的 base64（上游 SFA 原生机制）。
- 本地构建使用同一把钥匙：密钥放 `app/release.keystore`、签名项放 `local.properties`，本地产物与 CI 产物**签名一致、可互相覆盖升级**。

## 仓库说明

- 基座：`SagerNet/sing-box-for-android` @ `fc21909`（版本 1.14.2）。
- 内含本机/手机端构建适配：阿里云镜像（仅本机启用）、注释掉 `ndkVersion` + `keepDebugSymbols`（无 NDK 环境跳过 strip）、显式 `buildToolsVersion`、`local-build.sh`。
- 版本号跟随上游 **sing-box** 版本。

## 许可证

SungBox 是自由软件，采用 **GNU General Public License v3.0 或更新版本**（与上游一致）。见 [LICENSE](LICENSE)（全文）与 [NOTICE](NOTICE)（上游版权声明与附加条款）。

- 原项目版权：Copyright (C) 2022 by nekohasekai。
- 本项目是**非官方 fork**，与 SagerNet 无任何关联。使用 *SungBox* 这一名字，正是为了遵守上游附加条款：*"no derivative work may use the name or imply association with this application without prior consent."*
- `libbox.aar`（不随仓库分发）由 [sing-box](https://github.com/SagerNet/sing-box) v1.14.2 构建，GPL-3.0-or-later。
- 第三方组件（如 `third_party/libxposed-api`，Apache-2.0）保留其原始许可证。

## 致谢

- [sing-box](https://github.com/SagerNet/sing-box) 与 [sing-box-for-android](https://github.com/SagerNet/sing-box-for-android)：nekohasekai / SagerNet。
- SFA 部分代码源自 [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)（Max Lv、Mygod Studio）。
