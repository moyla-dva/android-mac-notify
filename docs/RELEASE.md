# Release Guide

这个项目当前适合发布为 early test build。安装包可以放到 GitHub Releases，但不要上传 debug 包。

## Android

不要公开分发：

- `app-debug.apk`
- 使用 debug keystore 签名的包
- 包含本地调试配置、测试证书或本机路径的包

公开分发建议：

- 使用 `release` build type
- 使用自己的 release keystore 签名
- release keystore、密码、`keystore.properties` 不提交到仓库
- 上传前在真实 Android 设备上安装验证通知访问、文件投递、暂停 / 恢复接力

当前仓库支持从本地 `android/keystore.properties` 读取 release 签名配置。这个文件和 keystore 不提交到仓库。

推荐本地流程：

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleRelease
```

如果存在本地签名配置，输出的 release APK 可直接安装；如果没有签名配置，release APK 不能作为公开安装包使用。

## Mac

当前 Mac 端可打包为 `.app`：

```bash
./mac/scripts/build-app-bundle.sh
```

输出：

```text
mac/dist/Android Mac Notify.app
```

生成 DMG：

```bash
./mac/scripts/package-dmg.sh
```

输出：

```text
mac/dist/Android-Mac-Notify-macOS-arm64-v0.1.0.dmg
```

公开分发建议：

- 优先上传 DMG，用户打开后把 App 拖到 Applications
- zip 可保留作为备用下载
- 后续补 Developer ID 签名和 notarization，减少 Gatekeeper 拦截
- 未签名包只适合早期测试用户，Release 页面需要明确说明

## 开源前检查

开源仓库不要提交：

- Android keystore / `.jks` / `.keystore` / `.p12`
- `local.properties`
- APK、AAB、DMG、ZIP 等构建产物
- 真实 token、密码、API key
- 用户本地运行状态、设备配对数据或日志

当前仓库已将上述常见产物加入 `.gitignore`。
