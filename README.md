# Android Mac Notify

`android-mac-notify` 是一个面向 `Android + Mac` 的本地协同项目。

第一阶段聚焦：

- Android 重要通知到 Mac
- 验证码提取与一键复制
- 链接识别与一键打开
- Android 系统分享文件到 Mac，包括单文件、多文件和大文件 raw 直传
- Android 暂停 / 恢复接力后，Mac 同步展示接力状态
- 普通 Wi-Fi 与 Android 热点环境下的稳定连接

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

## 下一步

1. 继续真实设备 QA：通知动作、文件投递、暂停 / 恢复接力状态同步
2. 收敛 Android 与 Mac 的状态文案和诊断入口
3. 评估文件投递后续：断点续传、目录规则、后台大文件队列
