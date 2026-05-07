# Android Mac Notify Product Direction

## 1. Direction Decision

`android-mac-notify` 的长期方向定为：

**一个把 Android 关键事件转成 Mac 可执行动作的本地协同工具。**

它不是通用同步平台，也不是远程控制工具。项目的核心不是“把手机上的所有东西搬到 Mac”，而是让用户在 Mac 前工作时，用更少步骤完成 Android 上触发的关键任务。

## 2. Target User

核心用户：

- 主力手机是 Android
- 主力工作设备是 Mac
- 长时间在 Mac 前工作
- 不想频繁拿起手机，但最常见、最确定的跨端需求是验证码、链接和文件

用户真正要完成的任务不是“同步”，而是：

- 在 Mac 上快速处理手机侧事件
- 减少从 Mac 到手机再回 Mac 的切换
- 在网络或权限异常时知道问题在哪里

## 3. Product Model

项目采用三层演进模型。

### 3.1 Sync As The Starting Point

第一阶段借用同步型能力打基础：

- 通知事件传递
- 链接传递
- 文本传递
- 后续文件传递
- 连接状态传递

同步能力只作为底层输入，不作为最终产品定义。

### 3.2 Phone Events, Not Notification Sync

主路线不是通知同步，而是手机事件接力。

第一道问题不是“这条通知应该怎么展示”，而是：

```text
这件事值得穿过设备边界来到 Mac 吗？
```

当前默认只把这些事件视为跨设备候选：

- 通知自动接力：验证码、动态码、登录码、通知里的可打开链接
- 用户主动接力：从 Android 系统分享入口投递到 Mac 的文件

默认不把普通聊天、文件传输助手普通文本、外卖/快递过程、门禁/取件码、营销推荐、内容流、普通支付成功、安全普通提示、系统常驻、播放、下载、电量变化发送到 Mac。

外卖、快递、会议、联系人/群聊/频道、关键词等能力只作为后续可配置扩展，不进入当前默认规则。

### 3.3 Actions As The Product Core

通过 Android 前置门禁后的事件，到 Mac 端后不只展示，而是判断能做什么：

- 事件到达后，不只展示，而是判断能做什么
- 验证码到达后，直接给出复制动作
- 链接到达后，直接给出打开动作
- 文件到达后，保存到 Mac 指定位置

核心协同单位是：

```text
Android Event -> Mac Action
```

而不是：

```text
Android Data -> Mac Data
```

### 3.4 Scenes As The Long-Term Layer

场景型能力作为远期方向：

- 桌前办公模式
- 会议模式
- 夜间模式
- 外出模式
- Mac 活跃时优先桌面处理

这层不进入当前主战场。只有当动作模型稳定、规则系统有真实需求后，再引入场景分发。

### 3.5 Status Cards As A Reusable Surface

状态卡片是动作型平台里的轻量场景增强。

它适合这类事件：

- 有持续状态
- 会多次更新
- 有明确阶段或终点
- 中途不适合每次弹窗打扰
- 终态或异常需要主动提醒

外卖卡片是第一个实现，但产品抽象应保持为：

```text
Android notification -> StatusCardProvider -> StatusCardState -> Mac card surface
```

后续打车、会议、来电、文件接收、安全登录都应该复用同一套状态卡片模型，而不是各做一套浮窗。

快递可以复用状态卡片表面，但不应绑定 Android App 通知解析。更合适的形态是由短信解析、行业 API、邮箱解析、手动单号或其他项目产生标准物流事件，再接入本项目的卡片表面。

## 4. Current Product Definition

当前阶段产品定义：

**桌前办公时，Android 上值得跨设备的手机事件，在 Mac 上变成可直接处理的动作或可安静跟进的状态。**

当前阶段最重要的体验：

1. 配对清楚
2. 连接状态诚实
3. 值得接力的手机事件可靠到达
4. 验证码识别准确
5. 复制验证码一步完成
6. 链接可以在 Mac 一键打开
7. 持续状态型通知可以沉淀成桌面卡片
8. 重复通知不会轰炸
9. 出错时用户知道是网络、权限、配对还是认证问题

## 5. Development Principles

### 5.1 Main Path First

默认主路径必须保持简单：

1. Mac 启动本地接收器
2. Android 自动发现同网段或热点下的可用 Mac
3. Android 展示设备列表，用户选择已知 Mac 或确认新配对
4. Android 使用配对 token 注册到 Mac
5. Android 开启通知访问权限
6. Android 收到通知
7. Mac 接收事件并产生动作
8. 用户在 Mac 上完成处理

任何新功能都不能让这条路径更难理解。

自动发现不能替代首次信任确认。它只负责“找到设备并展示”，已配对设备才允许自动连接。

### 5.2 Android Is The Event Gate

Android 端不是“尽量多发”，而是先判断事件是否值得跨设备：

- 空通知、常驻状态、播放下载、电量变化直接跳过
- 普通 IM 默认不跨设备，含验证码、链接、地址、自我接力信号时才发送
- 外卖、会议、订单异常等状态事件允许发送
- 高置信营销和内容推荐默认不发送
- 未知但不明显低价值的来源暂时保守发送，交给 Mac 端规则继续判断

这样可以减少网络、耗电、Mac 通知授权占用和用户打扰，也让产品心智从“通知同步器”回到“手机事件接力”。

### 5.3 Mac Is The Action Surface

Android 端职责应该轻：

- 配对配置
- 权限引导
- 通知采集
- 事件接力门禁
- 发送队列与重试

Mac 端承担动作处理：

- 设备信任
- 会话状态
- 通知历史
- 动作识别
- 规则分发
- 动作执行

### 5.4 State Must Be Honest

这些状态不能混在一起：

- 本地接收器是否运行
- 是否已配对
- Android 最近是否在线
- 最近一次事件是否成功
- token 是否有效
- 通知权限是否可用

如果 UI 说“已连接”，用户就应该能相信事件链路真的可用。

### 5.5 Rules Must Stay Small At First

第一阶段只做必要规则：

- 应用白名单 / 黑名单
- 验证码类高亮
- 链接类给打开动作
- 低价值通知只入历史不弹窗
- 重复事件去重
- 通知历史默认短期保留，敏感通知只给临时动作不落长期历史
- 临时动作短时间可见、可确认、可执行，但不写入长期状态文件
- 用户可以随时清空本地通知历史

暂不做复杂自动化规则平台。

当前通知路由策略见 [Notification Routing](./NOTIFICATION-ROUTING.md)。当前原则是：硬规则保护底线，动态评分决定打扰强度，用户反馈负责个性化。

## 6. Phase Plan

### 6.1 Phase 1: Reliable Notification Action MVP

目标：

把现有“通知转发原型”升级成可靠的“手机事件接力 MVP”。

必须包含：

- Mac 端配对设备、device token、通知历史持久化
- Android 端自动查找同网络内可用 Mac 并展示设备列表
- 已配对 Mac 可以自动重连，未配对 Mac 需要用户确认
- pairing token 有效期或注册后轮换机制
- Android 通知发送失败后的重试策略
- 稳定 eventId，支持同一事件重试去重
- Mac 端动作候选模型
- 验证码识别与一键复制
- 链接识别与一键打开
- 最近通知历史
- 基础应用过滤
- 连接诊断状态

明确不做：

- 文件传输
- 查找手机 / 响铃
- 复杂双向剪贴板
- 多设备
- 云端中转
- 深层远程控制

### 6.2 Phase 2: Action Expansion

目标：

扩展动作类型，但仍保持轻量。

候选能力：

- Android 主动分享链接到 Mac
- Android 主动分享文本到 Mac
- 文件快速保存到 Mac 指定目录（MVP 已启动，见 [File Delivery MVP](./FILE-DELIVERY-MVP.md)）
- Mac 请求 Android 重新同步最近事件
- 查找手机 / 响铃
- 外卖、会议等持续状态卡片
- 来电事件在 Mac 显示来电卡片，并提供接听、拒接、静音、稍后回拨等轻控制动作
- 更完整的动作历史

Phase 2 的前提：

- Phase 1 的通知、验证码、链接链路已经稳定
- 用户已经能理解“事件到动作”的产品模型
- 基础规则没有造成配置负担

已记录但延后：

- 状态卡片池：内部保留多张状态卡片，桌面只突出最高优先级卡片
- 会议状态卡片 provider：用于验证 `StatusCard` 抽象能复用到更多持续状态场景
- 快递外部事件接入：保留为其他项目或后续独立模块，不在当前 Android 通知解析主线内推进

来电能力的边界：

- 近期只做 Mac 控制手机接听或拒接，不承诺 Mac 直接承载 Android 通话音频
- 推荐用户使用支持 Bluetooth Multipoint 的耳机，让耳机同时连接 Mac 和 Android 手机
- 手机来电时，Mac 来电卡片触发接听动作，通话音频仍由手机或多点耳机处理
- 这条路线保持在“事件到动作”模型内，避免过早进入远程音频转发或默认拨号器替代

### 6.3 Phase 3: Scene-Aware Dispatch

目标：

让动作分发根据用户场景变化。

候选场景：

- 桌前办公
- 会议中
- 夜间
- 离开电脑
- 手机热点环境

这一阶段的关键不是增加更多功能，而是减少不合时宜的打扰。

## 7. Architecture Implications

Mac 端需要从“本地接收器”升级为“动作引擎”。

建议逐步形成这些边界：

```text
LocalServer
  -> EventIngest
  -> ActionClassifier
  -> RuleEngine
  -> ActionExecutor
  -> NotificationHistory
```

核心对象建议：

- `RawEvent`: Android 发来的原始事件
- `NormalizedEvent`: Mac 标准化后的事件
- `ActionCandidate`: 从事件中识别出的可执行动作
- `RuleDecision`: 是否弹窗、入历史、静默、置顶或执行默认动作
- `ActionExecution`: 复制、打开、保存、归档等动作结果

当前代码中的 `VerificationCodeExtractor` 应该逐步成为 `ActionClassifier` 的一部分，而不是散落在 UI 或通知展示逻辑中。

## 8. First Implementation Priorities

下一轮开发优先级：

1. Mac 端持久化配对设备和 token
2. Mac 端持久化最近通知历史
3. Android 端稳定 eventId
4. Android 端发送失败记录与重试
5. Mac 端 `ActionCandidate` 模型
6. 链接识别和打开动作
7. Android 前置事件门禁和 Mac 基础分发规则
8. 连接状态诊断视图

不建议现在优先做：

- 品牌化大视觉或营销式首页
- 多设备管理
- 文件传输
- 复杂规则编辑器
- 双向剪贴板
- 远程控制

## 9. Success Criteria

Phase 1 成功标准：

- 普通 Wi-Fi 下能完成配对和通知接收
- Android 热点环境下能完成配对和通知接收
- Mac 重启后仍保留已配对设备
- Android 重试同一通知不会造成重复轰炸
- 验证码通知在 Mac 上能一键复制
- 链接通知在 Mac 上能一键打开
- 用户能看到清晰的连接与失败原因
- 日常通知噪音可控

## 10. Product Anti-Goals

当前阶段明确不追求：

- 成为全功能 KDE Connect 替代品
- 同步所有通知
- 双向同步所有剪贴板内容
- 做复杂设备状态面板
- 做远程控制平台
- 做云端账号体系
- 用大量设置项掩盖不清晰的产品判断

## 11. Document Relationship

- `MVP-SPEC.md`: 定义第一阶段问题、目标用户和 MVP 范围
- `ARCHITECTURE.md`: 定义系统边界、模块和数据流
- `API-SPEC.md`: 定义 Android 与 Mac 的本地 API 契约
- `PRODUCT-DIRECTION.md`: 定义产品主线、阶段路线和开发优先级
- `NOTIFICATION-ROUTING.md`: 定义 Android 前置门禁、Mac 表面和通知动作路由
- `FILE-DELIVERY-MVP.md`: 定义 Android 到 Mac 文件投递的当前范围和边界
- `UI-INTERACTION-DIRECTION.md`: 定义 Mac 主窗口/菜单栏、Android 接力/文件/设备页以及可靠性入口的交互边界
- `archive/`: 保留早期 Phase 1 计划、收口和旧通知路由文档
