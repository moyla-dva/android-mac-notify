# Android App

Android 端负责把手机侧事件接力到已配对的 Mac。

当前职责：

- 通过通知访问服务读取 Android 通知
- 在 Android 端前置判断是否需要接力
- 将验证码、链接等确定性事件发送到 Mac
- 通过系统分享或应用内选择文件，把单文件、多文件和大文件流式投递到 Mac
- 自动发现附近 Mac，支持手动连接兜底
- 展示接力、文件投递、设备管理和可靠性状态

## 本地构建

```bash
cd /Users/vainve/android-mac-notify/android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

Debug APK 只用于本机开发和真机调试，不建议公开分发。

## 发布构建

公开分发时应使用 release 包，并使用自己的 release keystore 签名。

当前仓库不提交签名证书、keystore 或密码。发布前请在本地生成签名材料，并确保这些文件不进入 git。

参考发布说明：

- [Release Guide](../docs/RELEASE.md)
