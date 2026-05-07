# Phase 1 Closeout

## Current Scope

当前收口范围只覆盖 Phase 1 主链路：

```text
Android notification event -> Android relay gate -> Mac receiver -> action candidates -> menu bar / action inbox / history
```

手动 QA 细则见 [QA Playbook](../QA-PLAYBOOK.md)。

已记录但不进入本轮收口：

- 多状态卡片池
- 快递 / 会议状态卡片 provider
- 外卖等状态卡片 provider 默认暂缓，后续只作为显式可配置扩展
- 查找手机 / 响铃
- 来电轻控制
- 联系人 / 群聊 / 频道级规则

Phase 1 之后已经启动的动作扩展：

- 文件投递：Android 系统分享单个或多个文件到 Mac，Mac 保存到配置的文件投递目录，默认在下载目录下
- 接力开关跨端同步：Android 暂停 / 恢复接力后，Mac 同步显示对应会话状态

## Current Completed Work

当前已经完成：

- Android 与 Mac 一对一配对、设备注册和本地持久化
- Mac 本地接收器、自动发现、心跳和连接状态展示
- Mac 主窗口、菜单栏入口、设置入口
- 验证码复制、链接打开、文件投递
- 动作结果持久化，成功动作跨重启退出待处理
- 普通文本通知不再默认接力；文本接力后续应走用户主动分享路径
- 通知分发表面：菜单栏动作、动作收件箱、最近记录、丢弃
- 噪音治理：Android 端前置门禁默认拦截普通 IM、电商营销、内容推荐、频道流和系统状态噪音
- Mac 端不再维护第二套通知反馈规则，默认信任 Android 门禁结果
- 最近记录只保留可回看事件，验证码等敏感动作使用临时动作窗口
- 文件投递：单文件 / 多文件、raw 二进制直传，保存到 Mac 配置的文件投递目录，默认 `~/Downloads/Android Mac Notify`
- 文件接收卡片：打开文件、在 Finder 中显示、复制路径；多文件提供显示全部、复制全部路径
- 会话状态：Android 暂停接力后，Mac 显示接力已暂停；恢复后回到已连接

## Automated Verification

最近运行时间：2026-05-07

Mac:

```bash
cd mac/app
swift test
cd ../..
./mac/scripts/build-app-bundle.sh
```

结果：通过。当前 Mac 测试数：159。

Android:

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

结果：通过。

## Local API Verification

基于已配对设备 token，用本地 API 模拟通知事件。

| Case | Result |
| --- | --- |
| discovery | `GET /api/v1/discovery` 返回 Mac 设备信息 |
| heartbeat | `POST /api/v1/session/heartbeat` 返回 `ok: true` |
| relay state | `POST /api/v1/session/relay-state` 可在 `active` / `paused` 间同步 |
| session status | `GET /api/v1/session/status` 返回当前配对设备状态 |
| invalid token | `POST /api/v1/events/notification` 返回 `401 INVALID_DEVICE_TOKEN` |
| normal notification | Android 门禁默认不发送 |
| duplicate eventId | 第二次上报返回 `deduplicated: true` |
| OTP notification | 不写长期历史，进入临时动作，提供 `copy_verification_code` |
| IM ordinary text | Android 门禁默认不发送 |
| link notification | 入历史，提供 `open_link` |
| low-value commerce | Android 门禁默认不发送 |
| delivery status card | 默认暂缓，不从通知主链触发 |
| share file | `POST /api/v1/share/file` 保存文件并返回保存路径 |
| file actions | 文件接收后生成文件卡片和可执行动作 |

## Daily Validation Focus

Phase 1 主链路已经进入真实设备日常测试。以下不是阻塞项，而是继续观察和收敛的重点：

- Android 通知访问权限被系统杀掉或关闭后的 UI 提示
- Android 断网后 pending 队列是否稳定保留并恢复发送
- Mac 菜单栏动作点击后的长期体验：复制验证码、打开链接、执行后自动收起
- 微信 / QQ / 文件助手等真实通知在含验证码或链接时接力，其余默认不打扰
- Android 系统分享真实文件、多文件和大文件到 Mac 的端到端体验
- 无文件名、同名文件和失败重试时的用户可理解反馈
- Android / Mac 暂停与恢复后，另一端状态更新是否足够及时
- 手机热点、同 Wi-Fi、Mac 切换网络后的自动发现体验
- 外卖/闪购状态卡片默认暂缓，后续如恢复需重新定义可配置入口
- Android 前置门禁是否会误伤确实需要接力的少数通知

## Release Readiness

Phase 1 当前已经适合继续做日常实测，但还不建议称为稳定版。

当前版本可以称为：

```text
Phase 1 daily-test build
```

建议后续优先做：

1. 用真实 Android 通知持续观察门禁误伤、漏发和后台保活。
2. 继续修 UI 文案、菜单栏动作和诊断里最容易误导用户的状态。
3. 暂不进入联系人 / 群聊 / 频道粒度规则。
4. 文件投递先保持当前流式直传和失败重试；断点续传、按来源/类型分流目录、后台队列和传输测速优化作为增强项评估。
