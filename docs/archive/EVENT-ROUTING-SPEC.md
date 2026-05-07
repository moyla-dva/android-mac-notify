# Event Routing And Notification Interaction Spec

## 1. Current Stage

当前项目处在 Phase 1 中后段：

```text
Android notification event -> Mac action candidates -> user completes action on Mac
```

通知链路已经跑通，下一步不是继续扩关键词表，而是把通知处理升级为事件路由。

2026-05 收敛：默认通知入口只接力验证码和链接。文本、文件、状态卡片等能力必须来自用户主动分享或后续显式配置，不再把普通通知当作默认输入。

2026-05-06 实现注记：当前默认入口以 Mac 菜单栏弹窗和动作收件箱为主，普通接力事件不再默认发 macOS 系统通知；用户反馈规则、外卖/会议状态卡片和动态评分均暂缓。

本规格使用 `feature-spec + acceptance-criteria` 形态，目标是指导下一轮 `RuleDecision`、Mac 菜单栏动作、主窗口信息架构和状态卡片的重构。

## 2. Product Framing

通知不是产品主角，而是 Android 事件进入 Mac 的第一种来源。

产品真正要判断的是：

```text
这条事件应该变成动作、状态、提醒、历史，还是被忽略？
```

因此后续代码模型不应只围绕 `present / suppress`，而应围绕：

```text
InboundEvent -> ActionCandidate -> RouteDecision -> Mac Surface
```

## 3. Target User

核心用户：

- 主力手机是 Android
- 主力工作设备是 Mac
- 长时间在 Mac 前工作
- 不想频繁拿手机
- 不希望 Mac 变成手机通知的完整镜像

用户的核心任务：

- 复制验证码
- 打开手机侧链接
- 复制或接力手机侧文本
- 查看持续状态
- 处理来电等轻控制事件
- 知道连接是否可靠

## 4. Scope

### 4.1 In Scope

本阶段规格覆盖：

- Android 通知事件的 Mac 端路由
- Mac 菜单栏弹窗动作
- 动作收件箱
- 状态卡片入口（暂缓，后续显式配置）
- 最近历史
- 敏感内容的短期留存
- 低价值事件的前置拦截
- 微信、QQ、短信等聊天/文本类通知的默认策略

### 4.2 Out Of Scope

本阶段不做：

- 快递行业 API
- 快递短信完整解析
- 外部物流项目
- 大型规则编辑器
- 多设备策略
- 云端同步
- 复杂用户画像或模型学习

快递可以作为未来外部事件源接入状态卡片，但不进入当前 Android 通知解析主线。

## 5. Mac Surfaces

事件最终只能进入以下几个表面之一，或同时进入一个主表面和一个辅助记录表面。

| Surface | 作用 | 打扰强度 | 持久化 | 例子 |
| --- | --- | --- | --- | --- |
| `systemNotification` | 需要立刻知道或立刻处理 | 高 | 视隐私策略决定 | 验证码、来电、安全风险、支付异常 |
| `actionInbox` | 有未完成动作，但可以稍后处理 | 中低 | 临时或短期 | 文件助手文本、待打开链接 |
| `statusCard` | 持续状态，过程安静更新 | 低到高 | 当前状态持久化 | 外卖、来电、会议 |
| `history` | 可回看，但不主动打扰 | 无 | 短期 | 低价值营销、普通系统记录 |
| `discard` | 不值得处理或不应保存 | 无 | 不保存 | 空通知、重复事件、被过滤的 ongoing 通知 |

## 6. RouteDecision Model

下一轮应把当前 `RuleDecision` 演进为更明确的路由决策。

建议模型语义：

```text
RouteDecision
  primarySurface: Surface
  secondarySurfaces: [Surface]
  interruptionLevel: InterruptionLevel
  persistencePolicy: PersistencePolicy
  visibleActionIds: [String]
  defaultActionId: String?
  statusCardPolicy: StatusCardPolicy?
  privacyLevel: PrivacyLevel
  reasonCodes: [String]
```

可以先兼容旧字段实现，不要求一次性大迁移。

### 6.1 Surface

```text
systemNotification
actionInbox
statusCard
history
discard
```

### 6.2 InterruptionLevel

```text
none
passive
notify
urgent
```

含义：

- `none`: 不打扰
- `passive`: 只更新 UI 或菜单栏
- `notify`: 发 macOS 通知
- `urgent`: 发通知并把默认动作放到最容易触达的位置

### 6.3 PersistencePolicy

```text
skip
transient
record
stateOnly
```

含义：

- `skip`: 不保存
- `transient`: 只在 Mac 运行期间短时间保留
- `record`: 写入最近历史
- `stateOnly`: 只更新状态卡片，不进入普通历史

实现要求：`NotificationHistoryPolicy` 应以 `persistencePolicy` 作为最终持久化依据。`historyPolicy` 只作为旧字段兼容和早期隐私默认值保留。

## 7. Routing Order

规则判断顺序应稳定，避免后续功能互相抢权。

### 7.1 Reject First

先处理不应进入管线的事件：

- 空标题且空正文
- 重复 `eventId`
- 明确不应转发的 ongoing 通知
- 本应用自己的通知

输出：

```text
primarySurface = discard
interruptionLevel = none
persistencePolicy = skip
```

### 7.2 Privacy Before History

先判断隐私，再判断展示。

默认敏感类型：

- 验证码
- 短信
- IM 文本
- 账号安全

策略：

- 可以主动打开菜单栏弹窗
- 可以进入动作收件箱
- 默认不写入长期历史
- 可保留短期临时动作

### 7.3 Action First

如果事件能产生明确动作，优先把它当成动作事件，而不是普通通知。

动作优先级：

1. 复制验证码
2. 接听 / 拒接 / 静音来电
3. 打开链接
4. 复制文本
5. 保存文件

动作事件默认：

```text
primarySurface = menuBar 或 actionInbox
visibleActionIds = extracted actions
defaultActionId = highest priority action
```

系统通知不作为普通动作事件的默认入口，只保留给失败等异常反馈。

动作完成后不应继续占据 `actionInbox`。成功动作退出待处理并以轻量元数据跨重启保留，失败动作只在运行期内保留用于重试；历史表面仍可以保留可重复执行的复制、打开类动作。

### 7.7 User Feedback Deferred

用户反馈规则暂缓。当前默认策略先由 Android 前置门禁保护跨设备边界。

后续如果加入反馈，优先考虑：

- 不再提醒此类
- 保留此类提醒
- 只入记录
- 清除这条

如果加入规则，优先按 `appPackage + title` 匹配，避免一刀切静默整个 App。反馈规则只改变路由表面，不改变原始事件模型。

隐私约束：

- 标准通知可以被改为只入记录
- 敏感通知被拦截或静默时不写入长期历史
- 清除单条只影响本地展示和本地历史

### 7.4 Status Second

如果事件描述的是持续状态，应进入状态卡片。

状态卡片适合：

- 有开始、中间、结束
- 多次更新
- 过程不应每次打扰
- 终态或异常需要提醒

当前项目内优先：

- 外卖 / 即时配送
- 来电
- 会议

快递只保留为外部事件源方向，不在当前 Android 通知解析里做大规模规则。

### 7.5 Awareness Third

无动作、非持续状态，但错过成本高的事件，进入轻提醒。

保留提醒：

- 安全风险
- 登录异常
- 支付 / 扣款 / 退款
- 空间不足
- 账单到期
- 未接来电

输出：

```text
primarySurface = systemNotification
interruptionLevel = notify
persistencePolicy = record
```

### 7.6 Passive Last

低价值且无动作事件只留历史或折叠。

默认被动处理：

- 内容推荐
- 电商营销
- 金融营销
- 会员权益
- 应用市场推荐
- 助手推荐

输出：

```text
primarySurface = history
interruptionLevel = none
persistencePolicy = record
```

## 8. Chat And Text Notifications

微信、QQ、TIM、短信不能按 App 一刀切静默，也不能默认变成完整聊天镜像。

默认策略：

- 有验证码：菜单栏动作 + 复制验证码
- 有链接：菜单栏动作或动作收件箱 + 打开链接
- 文件助手 / 自发文本：动作收件箱 + 复制文本
- 普通好友消息：默认不抢原生 Mac 客户端位置，只在有动作价值时突出
- 群聊聚合消息：默认弱化，不因 App 名称直接弹高优先级通知

当前阶段可以先用包名和标题启发式识别文件助手、自发文本和聚合消息。后续再进入联系人、群聊和用户反馈层。

## 9. Menu Bar Interaction

Mac 菜单栏弹窗是最高频处理入口。

菜单栏要求：

- 有默认动作时，弹窗必须能直接执行默认动作
- 验证码通知的主动作是复制验证码
- 链接通知的主动作是打开链接
- 普通文本默认不从通知主链接力，后续应走主动分享或显式配置
- 动作成功只给轻反馈，不再额外弹一条通知
- 动作失败才需要错误通知

主窗口不是第一处理路径。它负责：

- 查看待处理动作
- 查看持续状态
- 回看最近历史
- 管理设备和诊断

## 10. User Feedback Layer

不要马上做复杂规则编辑器。

Phase 1.5 只需要几个可理解的反馈：

- 以后少提醒这类
- 保持提醒这类
- 只入历史
- 对这个 App 关闭普通通知
- 清空历史

反馈不直接修改事件模型，只影响后续 `interruptionLevel` 和 `primarySurface`。

## 11. Acceptance Criteria

下一轮实现完成后，应满足：

- 验证码事件进入菜单栏和动作收件箱，提供复制验证码动作，不写入长期历史
- 链接事件提供打开链接动作，用户可从菜单栏弹窗或动作收件箱执行
- 文件助手普通文本默认不再依赖通知接力，后续应走用户主动分享或显式配置
- 普通聊天消息不会默认把项目变成聊天通知镜像
- 外卖状态卡片不从默认通知主链触发，后续只作为显式配置或外部事件源扩展
- 支付成功、扣款、退款等无动作事件默认不跨设备，除非后续加入显式配置
- 电商、金融、内容推荐等低价值事件不主动打扰
- 快递不会因为少量关键词被强行塞进当前 Android 通知主线
- 主窗口可以清楚区分动作、状态、历史和诊断
- 旧的 `shouldPresentSystemNotification` 可以从新路由决策兼容推导

## 12. Implementation Sequence

建议开发顺序：

1. 新增路由模型，先兼容旧 `RuleDecision`
2. 继续收敛 Android 前置门禁，并补充“最近拦截 / 放行原因”诊断
3. 让 Mac 菜单栏动作成为默认处理入口，系统通知只保留异常反馈
4. 调整聊天类通知策略，保持普通聊天默认不跨设备
5. 将状态卡片从普通通知主链彻底拆清楚
6. 主窗口按动作、文件、历史、诊断重排数据
7. 后续再增加最小用户反馈入口

## 13. Anti-Patterns

避免：

- 继续用关键词表无限扩展通知降噪
- 把所有 Android 通知都镜像到 Mac
- 按 App 包名直接静默微信、QQ、短信
- 把快递当作当前 Android 通知解析的核心场景
- 主窗口变成原始通知列表
- 动作成功后再制造新的打扰
- 用复杂规则编辑器替代清晰默认路径
