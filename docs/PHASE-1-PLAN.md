# Phase 1 Plan: Reliable Notification Action MVP

> Historical note: this plan records the earlier Phase 1 design path. The current implementation has shifted to Android relay gating, Mac menu bar actions, independent file delivery cards, and deferred status cards/user feedback rules by default. 当前事实以 `NOTIFICATION-DISPATCH-STRATEGY.md`、`FILE-DELIVERY-MVP.md`、`UI-INTERACTION-DIRECTION.md` 和 `PHASE-1-CLOSEOUT.md` 为准。

## 1. Purpose

Phase 1 的目标是把当前原型升级为一条可靠的日常主链：

```text
Android notification event -> Mac action candidates -> user completes action on Mac
```

这一阶段不是要做完整协同平台，而是要把第一条垂直链路做稳，同时让架构能自然扩展到后续事件类型。

下一步事件路由规格见 [Event Routing And Notification Interaction Spec](./EVENT-ROUTING-SPEC.md)。

核心判断：

- 通知只是第一种事件
- 验证码和链接只是第一批动作
- 本阶段应该建立事件到动作的基础模型
- 本阶段不做复杂插件系统、规则编辑器或多设备平台

## 2. Phase 1 Product Goal

当前阶段要达成：

- Android 端可靠采集并发送通知事件
- Mac 端可靠接收、认证、去重和持久化事件
- Mac 端从事件中识别可执行动作
- 用户可以在 Mac 上完成验证码复制和链接打开
- 连接、配对、认证、发送失败等状态对用户可诊断

用户看到的产品仍然要简单：

1. 配对 Android 和 Mac
2. Android 自动查找并展示附近可用 Mac
3. 用户在 Mac 上允许配对请求
4. 打开 Android 通知访问权限
5. Android 收到关键通知
6. Mac 显示通知和动作
7. 用户在 Mac 上复制验证码或打开链接

## 3. Scope

### 3.1 Must Have

- Mac 端持久化已配对设备
- Mac 端持久化 device token 或 token 引用
- Mac 端持久化最近通知历史
- Mac 端通知历史默认只保留最近 100 条或 24 小时
- 验证码、短信、IM 这类敏感通知默认只保留临时动作，不写入长期历史
- 敏感通知的临时动作在 Mac 运行期间保留 10 分钟，用于确认和执行，不写入状态文件
- Mac 端支持清空通知历史
- Mac 端提供公开 discovery 信息，不包含 token、历史或通知内容
- Android 端自动发现同网段或热点下的 Mac 接收器
- Android 端展示可用设备列表，并标识已配对 / 未配对状态
- 默认配对走 Mac 端审批确认，不要求用户手动输入 pairing token
- pairing token 作为开发和兜底入口，支持过期或注册后轮换
- Android 端生成稳定 eventId
- Android 端记录发送失败并重试
- Mac 端按 eventId 去重
- Mac 端引入 `InboundEvent`
- Mac 端引入 `ActionCandidate`
- Mac 端识别验证码动作
- Mac 端识别链接动作
- Mac 端支持复制验证码
- Mac 端支持默认浏览器打开链接
- Mac 端按 actionId 记录动作执行结果
- Mac 端动作执行成功后从待处理区移除，失败动作保留以便重试
- Mac 端动作执行成功后只更新 App / 菜单栏状态，失败时再弹系统通知
- Mac 端展示基础诊断状态

### 3.2 Should Have

- Android 端直连最近成功 Host 失败后，尝试自动发现已配对 Mac
- Mac 端使用 mDNS / DNS-SD 发布 `_amnotify._tcp.local`
- Android 端使用 NSD 查找 `_amnotify._tcp.local`
- 基础应用过滤
- 只入历史不弹窗的低价值通知策略
- 不做微信 / QQ / TIM 这种 App 级一刀切降噪，避免误伤文件助手和文本接力
- 内置默认规则先遵守“有动作优先弹，低价值无动作只入历史”
- 最近一次事件成功 / 失败记录
- Android 端注册后主动发送一次 heartbeat
- Mac 端显示 Android 最近在线时间

### 3.3 Explicitly Out Of Scope

- 文件传输
- 查找手机 / 响铃
- 来电接听、拒接或通话控制
- 多设备管理
- 云端账号体系
- 复杂规则编辑器
- 双向剪贴板合并
- 深层远程控制
- 自动执行高风险账号动作

## 4. Extensibility Principles

Phase 1 的实现必须遵守这些约束：

- `LocalServer` 只负责 HTTP 接入、认证和路由，不承担业务分类逻辑
- UI 不直接判断“这是验证码”或“这是链接”
- 验证码提取不能成为唯一动作入口
- 通知历史不能被建模成只能存通知展示文本
- Android API 可以先保留 `/events/notification`，但 Mac 内部必须归一到通用事件模型
- 规则系统先内置默认规则，不提前做用户可编辑的复杂规则平台
- 每个新增事件类型都应该走同一条事件到动作管线

目标是：

```text
Feature scope stays small.
Core model stays expandable.
```

## 5. Target Pipeline

Phase 1 目标管线：

```text
Android NotificationListenerService
  -> RelayApi
  -> LocalServer
  -> EventIngest
  -> EventNormalizer
  -> ActionClassifier
  -> RuleEngine
  -> ActionExecutor
  -> NotificationHistory
  -> Diagnostics
```

各层职责：

- `LocalServer`: 接收 HTTP、解析请求、鉴权、返回协议响应
- `EventIngest`: 把外部 API payload 转成内部事件
- `EventNormalizer`: 标准化字段、裁剪空内容、记录 receivedAt
- `ActionClassifier`: 从事件中提取动作候选
- `RuleEngine`: 决定弹窗、入历史、静默、展示哪些动作
- `ActionExecutor`: 执行复制、打开链接等具体动作
- `NotificationHistory`: 保存事件摘要、动作候选和执行结果
- `Diagnostics`: 保存连接、认证、发送失败、最近在线等状态

## 6. Core Models

下面是模型语义，不要求第一轮完全按这个名字实现，但代码边界应向这里靠拢。

### 6.1 InboundEvent

表示 Mac 内部统一接收的事件。

```text
InboundEvent
  eventId: String
  kind: EventKind
  sourceDeviceId: String
  occurredAt: Int64
  receivedAt: Int64
  payload: EventPayload
  metadata: EventMetadata
```

`EventKind` 第一阶段至少包含：

- `notification`

预留但不实现：

- `shared_link`
- `shared_text`
- `file_transfer`
- `device_status`
- `control_response`

### 6.2 EventPayload

第一阶段只需要通知 payload：

```text
NotificationPayload
  appPackage: String
  appName: String
  title: String
  text: String
  notificationKey: String
```

后续事件 payload 可以扩展为：

- `SharedLinkPayload`
- `SharedTextPayload`
- `FileTransferPayload`
- `DeviceStatusPayload`

### 6.3 ActionCandidate

表示从事件中识别出的可执行动作。

```text
ActionCandidate
  actionId: String
  sourceEventId: String
  kind: ActionKind
  title: String
  value: String?
  priority: ActionPriority
  payload: ActionPayload
```

`ActionKind` 第一阶段至少包含：

- `show_notification`
- `copy_verification_code`
- `open_link`
- `copy_text`
- `record_history`

预留但不实现：

- `save_file`
- `request_phone_ring`
- `request_recent_sync`
- `switch_mode`

### 6.4 RuleDecision

表示规则层对事件和动作的分发决定。

```text
RuleDecision
  shouldPresentSystemNotification: Bool
  historyPolicy: HistoryPolicy
  visibleActionIds: [String]
  defaultActionId: String?
  reasonCodes: [String]
  primarySurface: RouteSurface
  secondarySurfaces: [RouteSurface]
  interruptionLevel: InterruptionLevel
  persistencePolicy: PersistencePolicy
  statusCardPolicy: StatusCardPolicy?
  privacyLevel: PrivacyLevel
```

旧字段保留给当前 UI 和状态文件兼容；新字段用于逐步迁移到事件路由模型。历史持久化以 `persistencePolicy` 为准，`stateOnly` 只更新状态卡片，不进入普通最近历史。

第一阶段内置规则：

- 空通知不入动作链
- 本应用自己的通知不转发
- ongoing 通知默认忽略
- 验证码动作优先级高
- 链接动作优先级中
- 短信和 IM 文本通知提供复制文本动作
- 普通购物、营销、系统提醒不默认提供复制文本动作，避免动作噪音
- 复制文本动作需要清理明确的 IM 聚合前缀，例如 `[2条]联系人: 正文`
- IM 普通通知默认弹系统通知并提供动作，但不写入长期历史，文件助手/自发文本接力不能被误伤
- 后续降噪应进入联系人、群聊、场景或用户规则层，而不是按 App 包名全局静默
- 无可见动作且明显低价值的通知只入历史，不弹系统通知
- 支付、订单、来电、安全等无动作但重要通知仍然弹系统通知
- 内容推荐、金融营销、电商营销、助手推荐默认只入历史
- “营销标题 + 状态词正文”不能误穿透为外卖或订单状态卡片
- 普通通知可以弹窗并入历史

### 6.5 ActionResult

表示用户在 Mac 上执行动作后的结果。

```text
ActionResult
  actionId: String
  sourceEventId: String
  status: success | failed
  executedAt: Int64
  message: String?
```

当前 Phase 1 把执行结果中的成功状态作为轻量元数据持久化，用于更新待处理区和诊断状态：

- `success`: 该动作不再出现在待处理区
- `failed`: 该动作仍留在待处理区，允许用户重试

持久化文件只记录：

- `actionId`
- `sourceEventId`
- `status`
- `executedAt`

不持久化 `message`，避免验证码、文本内容等通过执行反馈落盘。当前只保存最近 24 小时、最多 200 条成功结果；失败结果只保留在运行期内。
- 敏感通知可以弹窗并保留临时动作，但不进入持久化历史
- 临时动作需要在主面板、设置和菜单栏都能看到来源、时间、预览和动作按钮
- 重复 eventId 只更新诊断，不重复弹窗

### 6.5 ActionResult

表示动作执行后的结果。

```text
ActionResult
  actionId: String
  sourceEventId: String
  status: success | failed
  executedAt: Int64
  message: String?
```

第一阶段需要记录：

- 验证码是否复制成功
- 链接是否成功交给系统打开
- 失败时的用户可读原因

## 7. Workstreams

### 7.0 Auto Discovery And Device Picker

目标：

用户不需要手填 Mac IP 和端口。Android 可以自动查找同 Wi-Fi 或手机热点下的可用 Mac，并在端侧显示设备列表。

建议最小实现：

- Mac 端提供 `GET /api/v1/discovery`
- discovery 响应只包含公开字段：

```json
{
  "protocolVersion": 1,
  "macDeviceId": "mac-...",
  "macDisplayName": "VaInve 的 MacBook Air",
  "port": 38471
}
```

- Mac 端发布 Bonjour / DNS-SD 服务：

```text
_amnotify._tcp.local
```

- Android 端使用 `NsdManager` 查找该服务类型
- Android 端设备列表显示：
  - 设备名
  - host
  - port
  - 是否与本地保存的 `macDeviceId` 匹配
  - 连接状态

信任规则：

- 自动发现只负责显示设备
- 已配对且 `macDeviceId` 匹配时，可以自动连接
- 未配对设备点击后向 Mac 发起配对请求
- Mac 端必须由用户允许后才签发长期 `deviceToken`
- token 手动输入只作为开发和兜底方式
- discovery 不返回 pairing token、device token、通知历史或敏感内容

审批接口：

- Android 发起：

```text
POST /api/v1/pair/request
```

- Android 轮询：

```text
GET /api/v1/pair/request/status?requestId=...&deviceId=...
```

兜底策略：

- 先尝试最近成功的 host + port
- 失败后启动 NSD 发现
- NSD 不可用时尝试当前网络网关地址
- 仍失败时显示手动输入或扫码入口

验收：

- 同一 Wi-Fi 下 Android 能看到 Mac 设备
- 手机开热点且 Mac 连接热点时，Android 能看到 Mac 设备或通过兜底策略找到
- 已配对 Mac 显示“已配对，可自动连接”
- 未配对 Mac 显示“未配对，需要确认”
- 发现到错误 Mac 时不会自动信任
- 关闭 Mac 接收器后设备列表能及时变成不可用或消失

### 7.1 Mac Persistence

目标：

Mac 重启后仍能识别已配对设备、token 和最近通知历史。

建议最小实现：

- 使用 `Application Support/Android Mac Notify/` 作为本地数据目录
- 设备注册表保存为 JSON
- 最近通知历史保存为 JSON
- 只保留最近 N 条历史，默认 100 条以内
- 写入使用 atomic write

token 处理建议：

- Phase 1 可以先用本地文件保存 token
- 如果打包形态稳定，优先把 device token 存到 Keychain
- 文档和代码里明确 token 是本地信任凭据，不进入云端

需要持久化的数据：

- `macDeviceId`
- `registeredDevices`
- `deviceId`
- `deviceDisplayName`
- `deviceToken` 或 token 引用
- `lastSeenAt`
- `recentEvents`
- `recentActionResults`

### 7.2 Pairing Lifecycle

目标：

配对过程可解释、可重置，默认不要求用户手动输入 pairing token。

规则：

- Android 默认发起配对审批请求
- Mac 端允许后才签发长期 `deviceToken`
- 本地接收器启动时生成 pairing token
- 注册成功后轮换 pairing token
- pairing token 可以设置有效期，建议 10 分钟
- 重置配对时清除设备注册和 token
- pairing token 只作为开发和兜底注册方式

用户可见状态：

- 接收器未启动
- 等待配对
- 已配对
- token 已过期，需要刷新
- 认证失败

### 7.3 Android Delivery Reliability

目标：

Android 通知发送不再是一次性 best effort。

稳定 eventId 规则：

```text
eventId = hash(deviceId + notificationKey + postedAt + appPackage + title + text)
```

要求：

- 同一条通知重试必须复用同一个 eventId
- 不能在 eventId 中加入随机 UUID
- Android 端发送失败时记录 pending event
- 网络恢复、服务重连或下次通知到来时尝试重发
- 认证失败不自动无限重试

Phase 1 最小队列：

- 可以先用 DataStore 保存一个小型 pending JSON 列表
- 队列有最大长度，避免无限增长
- 成功后移除
- 失败次数和最近失败原因需要记录

后续如果后台可靠性不足，再引入 WorkManager。

### 7.4 Action Classification

目标：

把验证码、链接和普通通知统一建模成动作候选。

第一阶段分类器：

- `VerificationCodeClassifier`
- `LinkClassifier`
- `NotificationDisplayClassifier`

分类规则：

- 同一事件可以产生多个动作
- 验证码动作优先级高于普通展示
- 链接动作不自动打开，只展示可点击动作
- 没有验证码和链接时，仍可产生普通通知展示动作

现有 `VerificationCodeExtractor` 可以保留，但调用入口应从 UI / presenter 移到 action classification 层。

### 7.5 Link Action

目标：

通知中的链接可以在 Mac 上一键打开。

识别范围：

- `https://...`
- `http://...`
- 后续再考虑无协议域名

行为：

- 从 title 和 text 中提取第一个或多个 URL
- UI 显示打开链接动作
- 点击后用系统默认浏览器打开
- 打开失败时给出可见反馈

安全边界：

- 不自动打开链接
- 不执行深链或脚本型 URL
- 第一阶段只处理 `http` 和 `https`

### 7.6 Basic Rules

目标：

减少噪音，但不提前做复杂规则系统。

默认规则：

- 忽略本应用通知
- 忽略 ongoing 通知
- 忽略空 title + 空 text
- 验证码通知高亮
- 链接通知提供打开动作
- 有可见动作的通知优先弹系统通知
- 无可见动作的应用市场、促销、游戏、福利类通知只入历史
- 支付、订单、来电、安全等重要通知不因无动作而静默
- 外卖配送类通知进入桌面状态卡片，非终态更新不额外打扰
- 重复 eventId 不再弹系统通知

可选配置：

- Android 端应用白名单 / 黑名单
- Mac 端只读展示当前过滤结果

### 7.7 Status Card MVP: Delivery Provider

目标：

把“持续状态型通知”从一次性弹窗升级成可复用桌面卡片。外卖只是第一个 provider。

通用抽象：

```text
NotificationPayload
  -> StatusCardClassifier
  -> StatusCardProvider
  -> StatusCardState
  -> floating card / inline card / menu summary
```

`StatusCardState` 至少包含：

- `category`: delivery / package / ride / meeting / call 等
- `sourceEventId`: 触发当前状态的事件
- `appName`: 来源应用
- `title`: 当前阶段的人类可读标题
- `detail`: 状态详情
- `stage`: 通用阶段，决定进度、终态和提醒策略
- `etaText`: 可选预计时间
- `updatedAt`: 更新时间

默认规则：

- 只基于 Android 通知事件识别，不接入外卖平台私有接口
- 识别美团外卖、饿了么、淘宝闪购、京东到家等配送相关通知
- 将通知粗分为已下单、备餐中、骑手取餐、配送中、已送达、需要关注
- 配送过程中的状态更新只刷新卡片，不重复弹系统通知
- 已送达、异常、取消、超时等终态仍保留系统通知
- 第一版只保留一张当前活跃卡片，避免桌面堆叠
- 已送达卡片保留短时间后自动收起

边界：

- 进度条是基于通知文本的阶段估计，不承诺分钟级精确
- 卡片是动作型平台的场景增强，不改变 Phase 1 的主链路
- 后续新增来电、会议等卡片时，新增 provider，不新增一套并行 UI
- 快递不在当前 Android 通知 provider 内展开，未来通过外部物流事件接入状态卡片表面

### 7.8 Diagnostics

目标：

用户知道链路卡在哪里。

至少展示：

- 接收器是否运行
- 当前 Host / Port
- 是否有待确认配对请求
- 是否已配对设备
- Android 最近在线时间
- 最近一次通知接收时间
- 最近一次失败原因
- 通知总数和去重数量

诊断不追求复杂，但必须诚实。

## 8. Suggested Implementation Order

### Milestone 1: Mac State Foundation

交付：

- 本地存储目录
- 设备注册表持久化
- 通知历史持久化
- App 启动时加载已有状态
- 重置配对会清理持久化状态

验收：

- Mac 重启后仍显示已配对设备
- 最近通知历史仍存在
- 重置配对后旧 token 不再可用

### Milestone 2: Pairing Approval And Token Hardening

交付：

- Android 发起配对审批请求
- Mac 端允许 / 拒绝配对请求
- Android 轮询审批状态并保存 `deviceToken`
- pairing token 注册后轮换
- pairing token 过期状态
- 认证失败诊断
- token 注册作为兜底路径保留

验收：

- Android 不输入 pairing token 也能请求 Mac 确认配对
- Mac 允许后 Android 能拿到 `deviceToken`
- Mac 拒绝或请求过期时 Android 给出明确状态
- 旧 pairing token 注册失败
- 新 pairing token 可以成功注册
- 无效 device token 调用事件接口返回 401

### Milestone 3: Android Reliable Delivery

交付：

- 稳定 eventId
- pending event 小队列
- 失败次数和失败原因记录
- 成功后移除 pending event

验收：

- 同一通知重试 eventId 不变
- Mac 对重复 eventId 去重
- 网络短暂失败后事件可恢复发送

### Milestone 4: Action Candidate Pipeline

交付：

- `InboundEvent`
- `ActionCandidate`
- 通知 payload 到 action candidates 的转换
- 验证码动作迁移到 classifier 层
- 普通通知展示动作

验收：

- 验证码通知产生 copy action
- 普通通知产生 show / history action
- UI 不再直接调用验证码提取逻辑

### Milestone 5: Link Action And Basic Rules

交付：

- URL 提取
- open link action
- 默认浏览器打开
- 基础规则决策
- 最近动作结果展示

验收：

- 包含 `https://` 的通知显示打开动作
- 点击后系统默认浏览器打开链接
- 非 http/https 链接不执行
- 重复事件不重复弹窗

### Milestone 6: Diagnostics Polish

交付：

- 主面板或设置页展示诊断状态
- 最近成功 / 失败事件
- 最近 Android 在线时间
- 去重数量

验收：

- 用户可以判断问题属于接收器、配对、认证、网络或通知权限

## 9. Acceptance Criteria

### 9.1 Main Path

- Mac 启动后本地接收器运行
- Android 可以发现 Mac 并发起配对请求
- Mac 允许后 Android 保存 device token
- Android 收到通知后发送到 Mac
- Mac 接收事件后写入历史
- 验证码通知显示复制动作
- 链接通知显示打开动作
- 普通文本通知显示复制文本动作
- 可见动作同时出现在 App 内和 macOS 系统通知动作中
- 用户可以在 Mac 上完成复制或打开
- 用户执行通知动作后，成功不新增打扰，失败有明确提醒

### 9.2 Persistence

- Mac App 重启后设备注册仍存在
- Mac App 重启后最近通知历史仍存在
- 重置配对后旧 device token 无法继续上报
- 配对审批不会从 discovery 暴露任何 token
- pairing token 兜底注册后不会长期复用同一个值

### 9.3 Reliability

- Android 发送失败不会直接丢失事件
- 同一事件重试不会造成 Mac 重复弹窗
- 认证失败不会无限重试
- pending 队列不会无限增长

### 9.4 Action Model

- 同一个事件可以产生多个动作候选
- 验证码提取逻辑不被 UI 直接调用
- 链接打开逻辑不被 HTTP 层直接调用
- 普通通知仍能正常展示和入历史

### 9.5 Diagnostics

- 接收器停止时 UI 显示停止状态
- token 无效时 UI 显示认证失败或最近失败原因
- 网络不可达时 Android 端能保留失败记录
- Mac 端能显示最近一次接收时间

## 10. Verification Plan

Mac 端：

```bash
cd /Users/vainve/android-mac-notify/mac/app
swift build
```

Android 端：

```bash
cd /Users/vainve/android-mac-notify/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

手动链路验证：

1. 启动 Mac App
2. Android 自动发现 Mac
3. Android 发起配对请求
4. Mac 端允许配对请求
5. Android 保存 device token
6. 发送普通通知
7. 发送验证码通知
8. 发送链接通知
9. 断网后触发通知，再恢复网络
10. 确认重复事件不会重复弹窗
11. 重启 Mac App，确认设备和历史仍存在

## 11. Future Extension Hooks

Phase 1 完成后，以下能力应该能自然接入同一管线：

- Android share link -> `InboundEvent(kind: shared_link)` -> `open_link`
- Android share text -> `InboundEvent(kind: shared_text)` -> `copy_text` / `record_history`
- Android file transfer -> `InboundEvent(kind: file_transfer)` -> `save_file`
- Device status -> `InboundEvent(kind: device_status)` -> `update_diagnostics`
- Android delivery notification -> `InboundEvent(kind: notification)` -> `status_card(delivery)`
- Status card pool -> keep multiple active `StatusCardState` values, while the desktop highlights one primary card
- Meeting / incoming call providers -> reuse `StatusCardProvider` without adding new floating-card UI
- Mac request phone ring -> `ActionCandidate(kind: request_phone_ring)` -> Android control API
- Android incoming call -> `InboundEvent(kind: incoming_call)` -> `answer_call` / `reject_call` / `mute_call` / `remind_later`

已记录但不进入当前 Phase 1 收口：

- 多状态卡片池：支持外卖多单、多平台并行，主桌面卡片按异常、终态、即将到达、最近更新排序
- 外部物流事件接入：保留为后续独立模块或其他项目输出，不在当前 Android 通知解析主线内实现
- 会议 provider：作为 `StatusCard` 抽象复用验证项，而不是独立功能系统

来电控制的产品边界：

- Mac 端展示来电卡片和轻控制动作
- Android 端负责调用系统来电控制能力
- 通话音频默认仍在手机或已连接的 Bluetooth Multipoint 耳机上
- 不把“Mac 直接作为 Android 电话听筒”作为近期承诺

如果新增能力必须绕开 `InboundEvent -> ActionCandidate -> RuleDecision`，说明 Phase 1 的抽象还不够稳。

## 12. Open Decisions

这些问题进入实现前需要确认或在实现中做最小选择：

- Mac token 第一阶段是否直接上 Keychain，还是先文件存储再迁移
- Android pending 队列使用 DataStore JSON，还是直接引入 Room
- 应用白名单优先放 Android 端，还是 Mac 端先只做展示与诊断
- 通知历史上限默认取 50、100 还是用户可配置
- pairing token 兜底入口保留多久

建议默认选择：

- Mac token 如果成本可控，优先 Keychain；否则本地 JSON 先跑通但保留迁移边界
- Android pending 队列先用 DataStore JSON，队列小而明确
- 应用过滤第一阶段优先 Android 端
- 通知历史默认保留 100 条
- 默认使用 Mac 端配对审批，pairing token 注册后立即轮换，并保留 10 分钟有效期
