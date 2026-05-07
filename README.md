# Android Mac Notify

`android-mac-notify` 是一个面向 `Android + Mac` 的本地协同项目。

License: MIT

第一阶段已经完成的主链路：

- Android 重要通知到 Mac
- 验证码提取与一键复制
- 链接识别与一键打开
- Android 系统分享文件到 Mac，包括单文件、多文件和大文件 raw 直传
- Android 暂停 / 恢复接力后，Mac 同步展示接力状态
- 普通 Wi-Fi 与 Android 热点环境下的稳定连接

当前项目不再只是早期原型，已经进入真实设备日常测试和体验收敛阶段。

## 当前状态

已完成：

- Android 三页结构：接力、文件、设备
- Android 接力页：展示当前 Mac、接力开关、暂停 / 恢复状态和可靠性入口
- Android 文件页：支持应用内选择文件、系统分享、单文件、多文件、大文件流式投递、失败重试和最近结果
- Android 设备页：自动发现附近 Mac、手动连接、切换当前 Mac、修改本机名称、忘记当前 Mac
- Android 通知门禁：验证码和链接优先接力，普通 IM、营销、内容流和系统状态默认不打扰
- Mac 菜单栏：展示连接状态、待处理动作和文件投递结果，动作可直接执行
- Mac 主窗口：收件箱化展示通知动作、文件投递和最近活动
- Mac 设置页：保存目录、连接诊断和高级信息集中管理
- 跨端状态：Android 暂停、Mac 暂停、不可达、恢复后可用等状态已进入联调
- 项目结构：Android ViewModel 已拆分出发现 / 文件投递等边界；Mac LocalServer 已拆出配对、会话、通知、文件接收等处理模块

仍需日常观察：

- 厂商后台策略下，通知监听和发送服务是否会被系统回收
- Android 前置通知门禁是否误伤少数确实需要接力的通知
- Mac 菜单栏弹出、设置入口、主窗口收件箱在真实高频使用下是否顺手
- 不同 Wi-Fi、手机热点和网络切换下，自动发现与手动兜底是否足够稳定

## 当前目录

```text
android-mac-notify/
  docs/
    PRODUCT-DIRECTION.md
    PHASE-1-PLAN.md
    MVP-SPEC.md
    ARCHITECTURE.md
    API-SPEC.md
  android/
    README.md
    app/
  mac/
    README.md
    app/
```

## 文档入口

- [/Users/vainve/android-mac-notify/docs/PRODUCT-DIRECTION.md](/Users/vainve/android-mac-notify/docs/PRODUCT-DIRECTION.md)
- [/Users/vainve/android-mac-notify/docs/PHASE-1-PLAN.md](/Users/vainve/android-mac-notify/docs/PHASE-1-PLAN.md)
- [/Users/vainve/android-mac-notify/docs/MVP-SPEC.md](/Users/vainve/android-mac-notify/docs/MVP-SPEC.md)
- [/Users/vainve/android-mac-notify/docs/ARCHITECTURE.md](/Users/vainve/android-mac-notify/docs/ARCHITECTURE.md)
- [/Users/vainve/android-mac-notify/docs/API-SPEC.md](/Users/vainve/android-mac-notify/docs/API-SPEC.md)
- [/Users/vainve/android-mac-notify/docs/RELEASE.md](/Users/vainve/android-mac-notify/docs/RELEASE.md)

## 发布安装包

公开给别人安装时不要上传 debug 包。

- Android：不要上传 `app-debug.apk`；应使用 release 包并用自己的 release keystore 签名
- Mac：上传打包后的 `.app` 压缩包；当前适合 early test，后续应补 Developer ID 签名和 notarization
- 构建和签名说明见 [Release Guide](/Users/vainve/android-mac-notify/docs/RELEASE.md)

## 后续方向

1. 继续用真实设备跑日常观察，重点看通知门禁误伤、后台保活和网络切换。
2. 继续打磨 Android 与 Mac 的状态文案、菜单栏动作和主窗口收件箱体验。
3. 文件投递后续只做增强项评估：断点续传、目录规则、后台大文件队列和传输测速优化。
4. 通知规则先保持 Android 前置门禁，是否开放用户自定义配置，等真实通知样本积累后再决定。
