# SungBox

*A sing-box-for-android fork for dual-network split tunneling — the tunnel rides **cellular**, direct traffic stays on **Wi-Fi**.*

**中文**：SungBox 是基于 sing-box-for-android 的非官方 fork：**代理走蜂窝、直连走 Wi-Fi、蜂窝断了代理就断（fail-closed）**——为校园网等会深入检查流量的环境而做。名字 = **sing → sung**。

> The name: one vowel away from where it comes from — close enough to see the family, far enough to stand on its own.

SungBox is an unofficial fork of [sing-box-for-android](https://github.com/SagerNet/sing-box-for-android) (SFA). It is made for networks that inspect traffic aggressively (e.g. campus networks): reach the outside through a proxy over the **mobile network**, while ordinary domestic traffic goes directly over the **campus Wi-Fi** — and the proxy must never fall back to the inspected network.

## What this fork adds

- **Cellular keep-alive.** SFA only holds a request for the *default* network. On many ROMs the cellular network is dropped as soon as Wi-Fi connects, and `network_type: ["cellular"]` then fails with `no available network interface`. SungBox registers an extra `requestNetwork(CELLULAR + INTERNET)` for the lifetime of the core, so cellular stays available while Wi-Fi is up:

  ```kotlin
  // app/src/main/java/io/nekohasekai/sfa/bg/DefaultNetworkListener.kt  [SungBox]
  private val cellularKeepAliveRequest = NetworkRequest.Builder().apply {
      addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
      addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
  }.build()
  ```

- **Fail-closed split.** Put `"network_type": ["cellular"]` on the proxy outbound and `"network_type": ["wifi"]` on the `direct` outbound. If cellular disappears, proxied traffic simply fails; it never leaks into the Wi-Fi network the tunnel exists to avoid.

Everything else is upstream SFA (base version **1.14.2**).

## Configuration

```jsonc
{
  "outbounds": [
    { "type": "vless", "tag": "proxy", "server": "…", "network_type": ["cellular"], /* … */ },
    { "type": "direct", "tag": "direct", "network_type": ["wifi"] }
  ],
  "route": {
    "final": "proxy",
    "default_domain_resolver": "dns-cn",   // required on sing-box >= 1.14
    "auto_detect_interface": true,
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": ["geosite-cn"], "outbound": "direct" }
    ]
  }
}
```

A full worked example (campus Wi-Fi direct + cellular tunnel, DoH for CN DNS, remote rule-sets downloaded through the tunnel) is in [`examples/campus-dual-network.example.json`](examples/campus-dual-network.example.json).

## Building

### Standard

1. Provide `libbox.aar` (not included in this repository):
   - this fork tracks sing-box **v1.14.2** → use the matching prebuilt from JitPack (`com.github.singbox-android:libbox:1.14.2`):
     `https://jitpack.io/com/github/singbox-android/libbox/1.14.2/libbox-1.14.2.aar`
   - put it at `app/libs/libbox.aar`
2. `./gradlew :app:assembleOtherDebug` — output: `app/build/outputs/apk/other/debug/SungBox-1.14.2-*.apk`

### On-device (Termux, no root)

This tree carries everything needed to build itself on the phone — see [`docs/BUILD-On-Device.md`](docs/BUILD-On-Device.md). Short version:

```bash
./local-build.sh
```

## Repository notes

- Base: `SagerNet/sing-box-for-android` @ `fc21909` (version 1.14.2).
- Local/on-device build adaptations are included: Aliyun maven mirrors, `ndkVersion` commented out + `keepDebugSymbols` (no NDK on device → skip strip), explicit `buildToolsVersion`, `local-build.sh`.
- The app version number tracks the upstream **sing-box** version.

## Releases & CI

- Publishing a GitHub **Release** triggers [`release.yml`](.github/workflows/release.yml): it builds a **signed `arm64-v8a`** APK and attaches it (plus SHA-256) to the release. Manual runs via *workflow_dispatch* upload the APK as a workflow artifact.
- Signing material is provided through repository secrets (never committed):
  - `KEYSTORE_BASE64` — base64 of the keystore (decoded to `app/release.keystore` during the build),
  - `LOCAL_PROPERTIES` — base64 of a Java `.properties` blob containing `KEYSTORE_PASS`, `ALIAS_NAME`, `ALIAS_PASS` (the same mechanism upstream SFA uses).
- Local builds use the identical key: put the keystore at `app/release.keystore` and the same three properties into `local.properties`; then `./local-build.sh` (debug) and `./local-build.sh release` produce APKs signed with the same key as CI — mutually updatable.

## License

SungBox is free software licensed under the **GNU General Public License v3.0 or later** — the same license as its upstream. See [LICENSE](LICENSE) (full text) and [NOTICE](NOTICE) (upstream copyright & additional terms).

- Original work: Copyright (C) 2022 by nekohasekai.
- This is an **unofficial fork**, not affiliated with SagerNet. The fork uses the name *SungBox* precisely to comply with the upstream additional term: *"no derivative work may use the name or imply association with this application without prior consent."*
- `libbox.aar` (not bundled here) is built from [sing-box](https://github.com/SagerNet/sing-box) v1.14.2, GPL-3.0-or-later.
- Third-party components (e.g. `third_party/libxposed-api`, Apache-2.0) keep their original licenses.

## Credits

- [sing-box](https://github.com/SagerNet/sing-box) and [sing-box-for-android](https://github.com/SagerNet/sing-box-for-android) by nekohasekai / SagerNet.
- Parts of SFA derive from [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android) (Max Lv, Mygod Studio).
