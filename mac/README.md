# Mac App

这里放 Mac 端工程。

第一阶段职责：

- 提供本地 HTTP 接收服务
- 作为菜单栏应用常驻
- 保存通知历史
- 提取验证码和链接动作
- 接收 Android 流式文件投递并生成文件动作
- 接收 Android 接力开关状态，区分已连接、接力暂停和离线
- 展示连接状态与基础诊断

计划技术栈：

- `Swift`
- `SwiftUI`
- `UserNotifications`
- 应用内嵌轻量 HTTP 服务

## 当前状态

现在 `app/` 已经是可运行的 Swift Package，并且支持打成真正可见的 `.app`：

- 菜单栏入口
- 本地 HTTP 接收器
- 连接状态展示
- 主窗口动作收件箱、最近记录和文件接收卡片
- 接力暂停 / 恢复状态展示
- 文件投递保存目录可在设置页修改，默认 `~/Downloads/Android Mac Notify`
- 可见 app bundle 打包脚本

## 本地运行

```bash
cd mac/app
swift run
```

## 构建可见 `.app`

```bash
./mac/scripts/build-app-bundle.sh
```

输出位置：

- `mac/dist/Android Mac Notify.app`

## 打开可见 `.app`

```bash
./mac/scripts/open-app-bundle.sh
```
