# QA Playbook

## 1. Purpose

这份文档用于验证当前 Phase 1 是否已经适合日常实测。

Phase 1 的验证目标不是覆盖完整 Android-Mac 协同平台，而是确认这条主链路稳定：

```text
Android 通知事件 -> Android 前置门禁 -> Mac 本地接收器 -> 动作识别 -> 菜单栏 / 动作收件箱 / 最近记录
```

## 2. Current Test Build

Mac app:

```bash
mac/dist/Android Mac Notify.app
```

Android debug package:

```bash
android/app/build/outputs/apk/debug/app-debug.apk
```

Mac 端重新构建：

```bash
./mac/scripts/build-app-bundle.sh
```

Mac 单元测试：

```bash
cd mac/app
swift test
```

Android 构建与单元测试：

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

## 3. Smoke Test

| Area | Test | Expected |
| --- | --- | --- |
| Mac app launch | 打开 Mac app | 主窗口出现，菜单栏入口可见或可通过隐藏工具展开 |
| Local receiver | 查看顶部状态 | 显示 `已连接` 或等待配对状态，Host/Port 不为空 |
| Android permission | 打开 Android 通知监听权限 | App 能读取并转发通知 |
| Pairing | Android 自动发现或手动连接 Mac | Mac 显示配对请求，允许后 Android 保存注册信息 |
| Heartbeat | 保持 Android app 后台运行 | Mac 连接状态保持已连接 |
| Stale session | 关闭 Android 接力或让 Android 离线超过 45 秒 | Android 不再显示盲目“可用”，Mac 进入暂停或断开重连状态 |
| Reconnect | 切换 Wi-Fi / 手机热点 | 能恢复连接，失败时状态可见 |
| Menu bar | 打开菜单栏入口 | 能看到连接状态、最近记录、主窗口和设置入口 |
| Mac settings | 打开 Mac 设置页 | 能看到接力概览、文件投递、状态卡片暂缓说明和高级诊断 |
| Android reliability | 打开 Android 接力页右上角可靠性入口 | 能看到通知访问、系统通知和后台限制状态 |
| File share target | Android 系统分享面板选择 Android Mac Notify | App 接收文件并显示发送状态 |
| Mac receiver pause | Mac 菜单栏点击暂停接力 | Android 下一次心跳后显示 Mac 已暂停接收，而不是不可达 |

## 4. Notification Test Matrix

| Type | Test Material | Expected Mac Behavior |
| --- | --- | --- |
| 验证码 | `验证码 864219，5 分钟内有效` | 菜单栏主动打开，提供复制验证码动作，不进入长期历史 |
| 链接 | `打开 https://example.com/docs` | 提供打开链接动作，链接可在 Mac 打开 |
| 普通文本 | 微信文件传输助手发送 `这是一段需要复制的文字` | Android 端不发送到 Mac，文本接力后续应走主动分享 |
| 普通微信 | 好友发送普通文字 | Android 端不发送到 Mac |
| 登录安全 | `你的账号刚在新设备登录` | 没有验证码或链接时不发送到 Mac |
| 支付交易 | `银行卡尾号 1234 消费 19.37 元` | 没有验证码或链接时不发送到 Mac |
| 工具资源 | `剩余空间不足，请及时处理备份空间` | 没有验证码或链接时不发送到 Mac |
| 淘宝营销 | `你心仪的宝贝终于降价了，快来看看吧` | Android 端不发送到 Mac |
| 小红书内容流 | `你关注的人有新动态` | Android 端不发送到 Mac |
| B 站关注更新 | `你特别关注的 UP 主刚发了视频` | Android 端不发送到 Mac |
| Telegram 资源频道 | `资源分享 / 下载地址 / 辅助 / 标签：#` | Android 端不发送到 Mac，即使正文包含“登录”也不升级为安全提醒 |
| 外卖终态 | `订单已送达`，标题包含真实订单语义 | Android 端不发送到 Mac |
| 营销伪状态 | 营销标题里包含 `订单已送达` | Android 端不发送到 Mac |

## 5. Action Verification

| Action | How To Test | Expected |
| --- | --- | --- |
| 复制验证码 | 在菜单栏弹窗或主窗口点击复制验证码 | 剪贴板变为验证码，动作从待处理区退出，菜单栏弹窗自动收起 |
| 打开链接 | 触发含 URL 的通知后点击打开链接 | 默认浏览器打开 URL |
| 文件投递 | Android 分享单个或多个文件到 Mac | 文件保存到 Mac 配置的文件投递目录，默认 `~/Downloads/Android Mac Notify`，Mac 显示文件卡片 |
| 大文件投递 | Android 分享 APK / 视频 / 1GB 以上测试文件到 Mac | 走 raw 直传路径，Android 和 Mac 都显示进度，完成后可打开或定位文件 |
| 暂停接力 | Android 点击暂停接力 | Android 停止通知和文件发送，Mac 状态显示接力已暂停而不是已连接运行中 |
| 恢复接力 | Android 点击恢复接力 | Android 恢复发送，Mac 状态回到已连接 |
| Mac 暂停接收 | Mac 菜单栏点击暂停接力后触发通知或文件 | Android 保留待发/失败可重试状态，连接卡显示 Mac 已暂停接收 |
| 文件动作 | 在 Mac 文件卡片点击动作 | 可打开文件、在 Finder 中显示、复制路径 |
| 执行反馈 | 动作成功后查看主窗口 | 顶部反馈出现，待处理数量下降 |
| 重启保持 | 执行动作后重启 Mac app | 已完成动作不重新进入待处理 |

## 6. Relay Gate QA

| Flow | Expected |
| --- | --- |
| 验证码通知 | Android 发送到 Mac，菜单栏出现复制动作 |
| 链接通知 | Android 发送到 Mac，菜单栏或主窗口出现打开链接动作 |
| 普通 IM 文本 | Android 不发送到 Mac |
| 营销或内容推荐 | Android 不发送到 Mac |
| 系统状态噪音 | Android 不发送到 Mac |
| 用户主动分享文件 | 不受通知门禁影响，进入文件投递链路 |

## 7. Privacy Checks

这些路径是 Phase 1 的隐私底线：

- 验证码通知不写入长期历史。
- 微信、QQ、短信等普通敏感文本默认不跨设备。
- 动作结果持久化只保存 actionId、状态和时间，不保存正文。
- 被 Android 门禁拦截的通知不写入 Mac 历史。
- `pairingToken` 和 `deviceToken` 不出现在最近记录和菜单栏里。
- 文件投递不写入通知历史，文件内容只落到 Mac 端配置的文件投递目录，默认在用户下载目录下。

## 8. Known Boundaries

当前刻意不做：

- 不做联系人、群聊、频道级规则。
- 文件投递当前支持单文件、多文件和 raw 二进制直传；不设置产品层固定大小上限，但不支持断点续传。
- 文件接收后提供打开、Finder 显示、复制路径，但不做文件管理器。
- 不做断点续传、后台大文件队列和按来源/类型自动分流的目标目录规则。
- 不做查找手机 / 响铃。
- 不做 Mac 接听 Android 来电。
- 不做完整双向剪贴板。
- 不做多设备管理。
- 不接快递行业 API，快递/物流事件未来应作为外部标准事件输入。

当前已知风险：

- Telegram、微信、QQ 这类 App 内部粒度不足，当前只默认接力验证码和链接。
- Android 厂商后台策略可能影响通知监听和后台发送稳定性。
- 手机热点和公司网络环境下，自动发现可能不稳定，手动连接仍是兜底路径。
- 外卖状态卡片已退出默认通知接力路径；后续如恢复，应作为显式可配置扩展。

## 9. Pass Criteria

Phase 1 日常实测版通过条件：

- Mac 单元测试通过。
- Android debug 包可构建。
- 已配对设备能在普通 Wi-Fi 和手机热点下发送通知。
- 验证码、链接、文件投递三条动作链路可用。
- 低价值内容流不会主动打扰。
- Android 前置门禁能默认拦截普通 IM、营销、内容流和系统状态噪音。
- 重启 Mac app 后连接、规则、动作结果和历史解释保持一致。
- 单文件、多文件和大文件可从 Android 系统分享面板投递到 Mac 配置的文件投递目录。
- Android 暂停 / 恢复接力后，Mac 端状态能同步显示暂停 / 已连接。

## 10. Next Decision Gate

日常实测期间，再决定下一步优先级：

1. 继续收 UI 和诊断体验。
2. 查找手机 / 响铃。
3. 外部状态事件规范。
4. 文件投递是否需要断点续传、按来源/类型分流的目录规则或后台大文件队列。
