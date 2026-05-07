# Android Mac Notify Architecture

## 1. 架构目标

`android-mac-notify` 的第一阶段目标不是做通用设备协同平台，而是做一条稳定、清晰、可扩展的主链：

- Android 采集重要通知事件
- 通过本地网络把事件发送到 Mac
- Mac 将事件转成用户可直接处理的动作

架构设计优先服务这 4 件事：

- 在普通 Wi-Fi 和 Android 热点下都能工作
- 首次配对和后续重连都足够简单
- 通知过滤、验证码、链接这条主路径尽量少依赖重框架
- 为后续主动分享、文件投递、多设备保留扩展口，但不提前做重
- 文件投递使用 Mac 端本地保存目录配置，默认落到下载目录；按来源分流、后台队列和断点续传后续再扩展

## 2. 技术选型

### 2.1 Android 端

- 语言：`Kotlin`
- UI：`Jetpack Compose`
- 通知监听：`NotificationListenerService`
- 网络：`OkHttp`
- 序列化：`kotlinx.serialization`
- 本地配置：`DataStore`
- 后台执行：先用应用内轻后台能力，必要时再补 `WorkManager`

### 2.2 Mac 端

- 语言：`Swift`
- UI：`SwiftUI`
- 常驻形态：菜单栏应用，必要时混用少量 `AppKit`
- 系统通知：`UserNotifications`
- 本地接收：应用内嵌轻量 HTTP 服务
- 本地存储：MVP 先用轻量文件存储，后续需要检索和规则扩展时再演进到 `SQLite`

### 2.3 传输与会话

- 传输协议：`HTTP + JSON`
- 鉴权方式：`Bearer token`
- 连接模型：稳定会话，不强依赖单一长连接
- 状态维持：心跳或状态刷新 + 自动重连
- 发现方式：`mDNS / Bonjour` 为增强能力，手动地址和二维码为兜底能力

## 3. 核心领域与核心对象

### 3.1 核心领域

第一阶段核心领域只有一个：

**Android 事件到 Mac 动作**

这里的“事件”主要是：

- Android 端判定值得接力的通知
- 验证码候选文本
- 链接
- 轻量主动分享的文本或链接

这里的“动作”主要是：

- 弹出 Mac 通知
- 复制验证码
- 打开链接
- 写入通知历史

### 3.2 核心对象

#### Device

表示一个已知设备。

字段建议：

- `deviceId`
- `platform`
- `displayName`
- `lastKnownAddress`
- `lastSeenAt`
- `trustState`
- `authTokenId`

#### Session

表示当前设备之间的连接状态。

字段建议：

- `deviceId`
- `connectionState`
- `transport`
- `currentAddress`
- `lastHeartbeatAt`
- `lastError`

#### NotificationEvent

表示 Android 发来的标准化通知事件。

字段建议：

- `eventId`
- `deviceId`
- `appPackage`
- `appName`
- `title`
- `text`
- `postedAt`
- `notificationKey`
- `receivedAt`

#### ActionCandidate

表示从通知中提取出的可执行动作。

类型建议：

- `otp`
- `open_link`
- `view_history_only`

#### NotificationRecord

表示 Mac 端保存的通知历史记录。

字段建议：

- `recordId`
- `sourceEventId`
- `normalizedTitle`
- `normalizedText`
- `derivedActions`
- `isMuted`
- `createdAt`

## 4. 状态与真值边界

### 4.1 Android 端拥有的真值

- 原始通知内容
- 通知过滤输入
- 是否把通知事件发送到 Mac 的端侧判定
- 本机设备标识
- 当前目标 Mac 设备配置
- 本机发送队列状态

Android 端不拥有：

- Mac 端通知历史真值
- Mac 端动作执行结果真值
- 跨设备统一业务状态

### 4.2 Mac 端拥有的真值

- 已配对 Android 设备记录
- 当前连接状态
- 通知历史
- 已提取动作结果
- 文件保存位置与本地动作执行结果

Mac 端不拥有：

- Android 系统通知源真值
- Android 侧完整消息历史

### 4.3 单一事实来源原则

- 原始通知真值只来自 Android
- 通知历史真值只来自 Mac
- 连接状态真值只来自当前会话状态机
- 配对和信任真值只来自设备注册表

## 5. 模块划分

## 5.1 Android 端模块

### `android-app`

应用入口和设置 UI。

负责：

- 引导授予通知权限
- 展示连接状态
- 管理自动发现、已配对目标和手动连接兜底
- 展示后台可靠性入口

### `notification-capture`

负责从系统获取通知并标准化。

负责：

- 监听通知
- 提取最小字段
- 丢弃明显无效通知

### `notification-filter`

负责端侧通知接力闸门。

负责：

- 空通知过滤
- 常驻通知过滤
- 验证码、明确链接等确定性事件放行
- IM、营销、系统噪音等默认不发送到 Mac

### `transport-client`

负责把事件发送给 Mac。

负责：

- HTTP 请求构建
- token 鉴权
- 失败重试
- 会话状态刷新

### `device-config`

负责本地设备和配对配置持久化。

负责：

- 保存 `deviceId`
- 保存配对目标信息
- 保存最近成功地址

## 5.2 Mac 端模块

### `mac-app-shell`

菜单栏应用入口。

负责：

- 菜单栏状态展示
- 配对入口
- 历史页入口
- 诊断页入口

### `local-server`

负责接收 Android 请求。

负责：

- 暴露本地 API
- 认证 token
- 标准化请求
- 更新会话状态

### `session-manager`

负责连接与会话状态。

负责：

- 已知设备管理
- 当前会话状态机
- 心跳和超时判断
- 网络变化后的恢复

### `notification-pipeline`

负责把事件变成可展示内容。

负责：

- 基础去重
- 文本标准化
- 动作提取
- 历史写入

### `action-engine`

负责具体动作执行。

负责：

- 提取验证码
- 复制验证码
- 提取链接
- 打开链接

### `persistence`

负责本地存储。

负责：

- 设备注册表
- token 元数据
- 通知历史
- 最近错误和诊断信息

## 6. 关键接口与调用关系

### 6.1 Android 主链

1. `NotificationListenerService` 收到系统通知
2. `notification-capture` 提取标准字段
3. `notification-filter` 在 Android 端判断是否发送
4. `transport-client` 发送到 Mac API
5. 成功则更新本地状态，失败则记录并重试

### 6.2 Mac 主链

1. `local-server` 接收请求并认证
2. `session-manager` 更新设备在线状态
3. `notification-pipeline` 做去重和标准化
4. `action-engine` 从已接收事件中提取验证码、链接和复制动作
5. `mac-app-shell` 触发系统通知或 UI 更新
6. `persistence` 保存通知历史和诊断信息

## 7. 网络与配对模型

### 7.1 默认策略

采用：

**本地网络优先，自动发现增强，手动直连兜底**

### 7.2 首次配对

MVP 首次配对主路径：

1. Android 通过 mDNS / Bonjour 自动发现附近 Mac 接收器
2. 用户选择目标 Mac
3. Android 发起配对请求
4. Mac 展示审批提示
5. Mac 建立设备记录并签发长期设备 token

手动地址、端口和一次性 token 仍保留为诊断和自动发现失败时的兜底能力：

1. Mac 端生成：
   - 本机地址
   - 端口
   - 一次性 token
2. Android 端手动输入或通过未来二维码导入
3. Android 发起配对请求

### 7.3 日常会话

日常使用不要求恒定单 socket 长连接，而是要求：

- 设备彼此可达
- 事件可快速送达
- 状态可刷新
- 暂停 / 恢复接力能跨端同步
- 网络变化后可恢复

MVP 会话策略：

- 通知事件通过 HTTP 请求发送
- Android 定期上报轻量状态或在关键时机刷新在线状态
- Android 端本地持久化 Mac 可达性：`Unknown` / `Reachable` / `Unreachable` / `AuthFailed` / `Paused`
- Android 点击「暂停接力 / 恢复接力」时通过会话状态接口同步给 Mac
- Mac 点击「暂停接力」时不关闭本地服务，而是进入接收暂停态：心跳仍可达，通知和文件返回可重试的暂停错误
- Mac 基于最近请求时间和状态刷新判断在线/离线
- Mac 监听网络变化，地址变化时自动重启本地接收器并刷新 Bonjour 暴露信息
- Mac 状态文件损坏时隔离旧文件并生成空状态，避免把存储损坏误报成网络不可达

会话状态不是配对状态。已配对设备可能处于：

- `connected`：最近在线且 Android 接力运行中
- `paused`：最近在线，但 Android 主动暂停接力
- `mac_paused`：Mac 服务在线，但 Mac 端主动暂停接收
- `disconnected_retrying`：已配对，但最近没有心跳或事件
- `unpaired`：Mac 没有该设备注册记录

### 7.4 不同网络环境处理

#### 普通同 Wi-Fi

- 优先尝试自动发现
- 失败时可手动直连

#### Android 热点

- 默认认为自动发现可能不稳
- 优先保留上次成功地址
- 允许用户手动确认目标地址

#### 复杂局域网

- 允许发现失败但手动直连成功
- 必须给出清晰诊断

## 8. API 设计原则

具体接口放到 `API-SPEC.md`，这里先定原则：

- 以设备为单位鉴权
- 输入输出尽量窄
- 请求幂等或接近幂等
- 通知事件保留 `eventId`
- 认证失败与网络失败必须可区分

MVP 预期最小接口：

- `POST /api/v1/pair/register`
- `POST /api/v1/events/notification`
- `POST /api/v1/session/heartbeat`
- `POST /api/v1/session/relay-state`
- `GET /api/v1/session/status`
- `POST /api/v1/share/file`

## 9. 目录建议

MVP 先按清晰边界组织，不先做多模块工程过度拆分。

```text
android-mac-notify/
  docs/
    MVP-SPEC.md
    ARCHITECTURE.md
    API-SPEC.md
    NOTIFICATION-ROUTING.md
    FILE-DELIVERY-MVP.md
    UI-INTERACTION-DIRECTION.md
    RELEASE.md
    archive/
  android/
    app/
  mac/
    app/
```

如果需要更细模块化，再在各端内部细分。

## 10. 迭代顺序

### Phase 1

- 完成架构和 API 定义
- 确定配对模型
- 搭最小项目骨架

### Phase 2

- Mac 本地服务先跑起来
- Android 端最小通知监听打通
- 完成一条通知从 Android 到 Mac 的闭环

### Phase 3

- 做验证码提取和复制
- 做链接识别与打开
- 做连接状态展示

### Phase 4

- 补自动重连
- 补热点和复杂网络环境验证
- 补基础历史和诊断

## 11. 架构不变量

- 原始通知只允许 Android 端采集
- 通知历史只允许 Mac 端持久化为主真值
- 配对与信任关系只能通过注册流程创建
- 自动发现失败不能阻断手动连接
- UI 层不能直接操作底层传输细节
- 动作提取逻辑不能散落在多个 UI 层

## 12. 当前可接受的技术债

- MVP 阶段先不做双向实时流
- 先不做复杂规则引擎
- 先不用数据库承载全部数据
- 自动发现可以先做浅一些
- Android 主动分享能力可晚于通知主链

## 13. 当前最大风险点

最大风险不是本地网络协议，而是：

**Android 厂商后台策略对通知采集和发送稳定性的影响**

这意味着第一阶段除了功能打通，还必须尽早验证：

- 锁屏状态
- 长时间后台
- Android 热点模式
- 网络切换后的恢复
