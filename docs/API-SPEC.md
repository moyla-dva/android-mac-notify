# Android Mac Notify API Spec

## 1. 文档目标

这份文档定义 `android-mac-notify` MVP 阶段的最小本地 API 契约。

设计目标：

- 让 Android 和 Mac 先稳定打通通知主链
- 支持普通 Wi-Fi 与 Android 热点环境
- 支持手动配对与二维码导入
- 区分网络失败、认证失败、设备未注册等状态
- 为后续主动分享和多设备扩展保留空间

## 2. 基本约束

### 2.1 传输

- 协议：`HTTP/1.1`
- 数据格式：`application/json`
- 字符编码：`UTF-8`
- 默认只考虑本地网络，不经过公网中转

### 2.2 版本

所有 MVP 接口统一挂在：

- `/api/v1/...`

### 2.3 鉴权

MVP 分两类鉴权：

#### 配对注册阶段

- 默认使用 Mac 端审批确认
- 一次性 `pairingToken` 保留为开发和兜底注册方式

#### 已配对阶段

- 使用长期 `deviceToken`
- Header：

```text
Authorization: Bearer <deviceToken>
```

### 2.4 时间字段

所有时间字段统一使用：

- `Unix epoch milliseconds`

### 2.5 幂等与重试

- 事件上报接口需要携带 `eventId`
- Mac 端应尽量按 `eventId` 去重
- Android 端允许在超时或网络失败后重试同一个事件

## 3. 核心对象

## 3.1 DeviceIdentity

```json
{
  "deviceId": "android-4f3c2a1b",
  "platform": "android",
  "displayName": "Mate40"
}
```

字段说明：

- `deviceId`：Android 端稳定设备标识
- `platform`：当前固定为 `android`
- `displayName`：用户可读设备名

## 3.2 MacEndpoint

```json
{
  "host": "192.168.43.120",
  "port": 38471
}
```

字段说明：

- `host`：Android 要访问的 Mac 地址
- `port`：Mac 本地服务端口

## 3.3 NotificationEvent

```json
{
  "eventId": "evt_01jts4z7q6z4e8m8w2a1",
  "deviceId": "android-4f3c2a1b",
  "appPackage": "com.tencent.mm",
  "appName": "微信",
  "title": "登录提醒",
  "text": "你的验证码是 123456",
  "postedAt": 1777824000000,
  "notificationKey": "0|com.tencent.mm|123|null|1000"
}
```

字段说明：

- `eventId`：客户端生成的唯一事件 ID
- `deviceId`：发送该通知的 Android 设备 ID
- `appPackage`：通知来源包名
- `appName`：用户可读应用名
- `title`：通知标题
- `text`：通知正文
- `postedAt`：通知发布时间
- `notificationKey`：Android 通知唯一键，用于辅助去重

## 4. 配对模型

## 4.1 配对前提

默认配对流程：

1. Android 自动发现 Mac 或手动填写 `host` / `port`
2. Android 向 Mac 发起配对请求
3. Mac 端弹出或展示确认入口
4. 用户在 Mac 上允许后，Android 轮询拿到长期 `deviceToken`

兜底配对流程：

- 手动输入
- 扫码导入

拿到一次性 `pairingToken` 后，Android 也可以直接向 Mac 发起注册。

## 4.2 二维码载荷

MVP 建议二维码内容为 JSON：

```json
{
  "version": 1,
  "host": "192.168.43.120",
  "port": 38471,
  "pairingToken": "pair_abc123xyz",
  "displayName": "Vainve MacBook Pro"
}
```

说明：

- 先不做复杂签名
- 二维码只承担导入连接信息

## 5. 接口定义

## 5.0 发现 Mac 接收器

### `GET /api/v1/discovery`

用途：

- Android 在同 Wi-Fi 或手机热点网络下自动识别 Mac 接收器
- Android 选择设备前确认 Mac 身份和端口
- 该接口不需要鉴权，但只返回公开字段

成功响应 `200`：

```json
{
  "protocolVersion": 1,
  "serviceType": "_amnotify._tcp",
  "macDeviceId": "mac-8df34b91",
  "macDisplayName": "Vainve MacBook Pro",
  "port": 38471,
  "serverTime": 1777824001000
}
```

DNS-SD 服务类型：

```text
_amnotify._tcp.local
```

安全约束：

- 不返回 `pairingToken`
- 不返回 `deviceToken`
- 不返回通知历史或临时动作内容
- 未配对设备仍必须通过用户确认和配对注册建立信任

## 5.1 发起配对审批

### `POST /api/v1/pair/request`

用途：

- Android 请求与当前 Mac 建立信任
- Mac 端显示待确认请求
- 不需要用户手动输入 `pairingToken`

请求体：

```json
{
  "device": {
    "deviceId": "android-4f3c2a1b",
    "platform": "android",
    "displayName": "Mate40"
  }
}
```

成功响应 `202`：

```json
{
  "requestId": "pair_req_xxx",
  "status": "pending",
  "macDeviceId": "mac-8df34b91",
  "macDisplayName": "Vainve MacBook Pro",
  "expiresAt": 1777824301000,
  "serverTime": 1777824001000,
  "pollAfterMillis": 2000
}
```

## 5.2 查询配对审批状态

### `GET /api/v1/pair/request/status`

查询参数：

- `requestId`
- `deviceId`

成功响应 `200`：

```json
{
  "requestId": "pair_req_xxx",
  "status": "approved",
  "macDeviceId": "mac-8df34b91",
  "macDisplayName": "Vainve MacBook Pro",
  "serverTime": 1777824003000,
  "message": "Pairing request was approved.",
  "registration": {
    "deviceToken": "dev_tok_xxx",
    "macDeviceId": "mac-8df34b91",
    "macDisplayName": "Vainve MacBook Pro",
    "serverTime": 1777824003000
  }
}
```

`status` 取值：

- `pending`
- `approved`
- `rejected`
- `expired`

安全约束：

- `deviceToken` 只在 `requestId` 与 `deviceId` 匹配，且 Mac 端已允许后返回
- 未审批、拒绝或过期时不返回 `registration`

## 5.3 兜底 Token 注册

### `POST /api/v1/pair/register`

用途：

- Android 使用一次性 token 向 Mac 注册自己
- 用一次性 `pairingToken` 换取长期 `deviceToken`

请求体：

```json
{
  "pairingToken": "pair_abc123xyz",
  "device": {
    "deviceId": "android-4f3c2a1b",
    "platform": "android",
    "displayName": "Mate40"
  }
}
```

成功响应 `200`：

```json
{
  "deviceToken": "dev_tok_xxx",
  "macDeviceId": "mac-8df34b91",
  "macDisplayName": "Vainve MacBook Pro",
  "serverTime": 1777824001000
}
```

失败状态：

- `400 Bad Request`
  - 请求字段缺失或格式错误
- `401 Unauthorized`
  - `pairingToken` 无效
- `409 Conflict`
  - 同一 `deviceId` 已注册但信任状态冲突

错误响应示例：

```json
{
  "error": {
    "code": "INVALID_PAIRING_TOKEN",
    "message": "Pairing token is invalid or expired."
  }
}
```

## 5.4 上报通知事件

### `POST /api/v1/events/notification`

用途：

- Android 将标准化通知事件发送到 Mac

请求头：

```text
Authorization: Bearer <deviceToken>
Content-Type: application/json
```

请求体：

```json
{
  "eventId": "evt_01jts4z7q6z4e8m8w2a1",
  "deviceId": "android-4f3c2a1b",
  "appPackage": "com.tencent.mm",
  "appName": "微信",
  "title": "登录提醒",
  "text": "你的验证码是 123456",
  "postedAt": 1777824000000,
  "notificationKey": "0|com.tencent.mm|123|null|1000"
}
```

成功响应 `202 Accepted`：

```json
{
  "accepted": true,
  "eventId": "evt_01jts4z7q6z4e8m8w2a1",
  "deduplicated": false,
  "receivedAt": 1777824001200
}
```

重复事件响应也返回 `202`：

```json
{
  "accepted": true,
  "eventId": "evt_01jts4z7q6z4e8m8w2a1",
  "deduplicated": true,
  "receivedAt": 1777824001200
}
```

失败状态：

- `400 Bad Request`
  - 字段缺失
- `401 Unauthorized`
  - `deviceToken` 无效
- `403 Forbidden`
  - `deviceId` 与 token 不匹配
- `409 Conflict`
  - 设备未处于允许状态

## 5.5 心跳 / 在线状态刷新

### `POST /api/v1/session/heartbeat`

用途：

- 让 Mac 知道该 Android 设备仍然在线
- 在没有新通知的情况下维持会话新鲜度
- 心跳代表 Android 端接力正在运行；Mac 收到心跳后会把该设备的 `relayState` 视为 `active`
- Android 接力开启且已配对时，应周期性发送心跳；当前实现约每 30 秒确认一次
- Android 必须读取响应中的 `sessionState`，当 Mac 返回 `unpaired` 或认证失败时停止把该状态当作普通网络重试
- Mac 用户点击「暂停接力」时，本地 HTTP 服务仍保持可达，心跳返回 `mac_paused`，通知和文件接口返回 `MAC_RECEIVER_PAUSED`

请求头：

```text
Authorization: Bearer <deviceToken>
Content-Type: application/json
```

请求体：

```json
{
  "deviceId": "android-4f3c2a1b",
  "sentAt": 1777824010000,
  "networkType": "wifi"
}
```

字段说明：

- `networkType`：可选，MVP 建议值：
  - `wifi`
  - `hotspot`
  - `unknown`

成功响应 `200`：

```json
{
  "ok": true,
  "serverTime": 1777824010100,
  "sessionState": "connected"
}
```

`sessionState` 可能值见 [8. 状态模型](#8-状态模型)。

失败状态：

- `401 Unauthorized`：`INVALID_DEVICE_TOKEN`，不可重试，需要重新配对
- `403 Forbidden`：`DEVICE_TOKEN_DEVICE_MISMATCH`，不可重试，需要重新配对或修复本机配置
- `409 Conflict`：`MAC_RECEIVER_PAUSED`，Mac 接收器暂停；可保留待发队列，等待心跳恢复为 `connected`

## 5.6 上报接力开关状态

### `POST /api/v1/session/relay-state`

用途：

- Android 用户点击「暂停接力 / 恢复接力」时，把本地接力开关同步给 Mac
- 避免 Android 已暂停，但 Mac 仍显示「已连接」的误导状态
- 不解除配对，不清除 token，只改变这台设备当前是否主动投递事件

请求头：

```text
Authorization: Bearer <deviceToken>
Content-Type: application/json
```

请求体：

```json
{
  "deviceId": "android-4f3c2a1b",
  "relayState": "paused",
  "sentAt": 1777824015000
}
```

字段说明：

- `relayState`
  - `active`：Android 端接力运行中，验证码通知、链接通知和文件可以继续发送
  - `paused`：Android 端主动暂停接力，配对保留，但不会继续发送通知和文件

成功响应 `200`：

```json
{
  "ok": true,
  "serverTime": 1777824015100,
  "sessionState": "paused"
}
```

失败状态：

- `400 Bad Request`
  - `relayState` 不是支持值
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
  - 该设备未注册

## 5.7 查询会话状态

### `GET /api/v1/session/status`

用途：

- Android 查询当前 Mac 端对本设备的连接视图
- 用于调试、可靠性/诊断状态展示、网络切换后恢复判断

请求头：

```text
Authorization: Bearer <deviceToken>
```

查询参数：

- `deviceId`

示例：

```text
GET /api/v1/session/status?deviceId=android-4f3c2a1b
```

成功响应 `200`：

```json
{
  "deviceId": "android-4f3c2a1b",
  "sessionState": "connected",
  "lastSeenAt": 1777824010100,
  "macDeviceId": "mac-8df34b91",
  "macDisplayName": "Vainve MacBook Pro"
}
```

失败状态：

- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
  - 该设备未注册

## 5.8 主动分享文本

### `POST /api/v1/share/text`

用途：

- Android 主动发送文本到 Mac
- 这是 MVP 的补充接口，不阻塞通知主链

请求头：

```text
Authorization: Bearer <deviceToken>
Content-Type: application/json
```

请求体：

```json
{
  "deviceId": "android-4f3c2a1b",
  "shareId": "share_001",
  "text": "https://example.com/article",
  "sharedAt": 1777824020000
}
```

成功响应 `202`：

```json
{
  "accepted": true,
  "shareId": "share_001"
}
```

## 5.9 主动分享文件

### `POST /api/v1/share/file`

用途：

- Android 通过系统分享面板把一个或多个文件投递到 Mac
- Mac 默认保存到 `~/Downloads/Android Mac Notify`，也可以在 Mac 设置页修改文件投递保存目录
- 当前主路径使用 raw 二进制直传，避免 Base64 内存开销，并支持大文件和批量投递

请求头：

```text
Authorization: Bearer <deviceToken>
X-AMN-Upload-Mode: raw
X-AMN-Device-Id: android-4f3c2a1b
X-AMN-Share-Id: share_file_001
X-AMN-File-Name-B64: cmVjZWlwdC5wZGY=
X-AMN-Mime-Type: application/pdf
X-AMN-Shared-At: 1777824020000
Content-Type: application/octet-stream
Content-Length: 24576
```

请求体为原始文件字节流。

字段说明：

- `X-AMN-Device-Id`：Android 设备 ID，必须与 token 匹配
- `X-AMN-Share-Id`：Android 端生成的单次文件投递 ID
- `X-AMN-File-Name-B64`：原始文件名的 UTF-8 Base64，避免 header 编码问题
- `X-AMN-Mime-Type`：Android 能识别到的 MIME 类型，可以为空
- `X-AMN-Shared-At`：Android 发起分享的时间戳
- `Content-Length`：原始文件字节数

多文件批量投递时，每个文件仍是一次 `POST /api/v1/share/file`，并额外带上批次头：

```text
X-AMN-Batch-Id: batch_01jts4z7q6z4e8m8w2a1
X-AMN-Batch-Index: 0
X-AMN-Batch-Total: 6
```

批次字段说明：

- `X-AMN-Batch-Id`：同一批文件共用的批次 ID
- `X-AMN-Batch-Index`：当前文件在批次中的索引，从 `0` 开始
- `X-AMN-Batch-Total`：该批文件总数

成功响应 `202`：

```json
{
  "accepted": true,
  "shareId": "share_file_001",
  "fileName": "receipt.pdf",
  "savedPath": "/Users/vainve/Downloads/Android Mac Notify/receipt.pdf",
  "size": 24576
}
```

响应字段说明：

- `fileName`：Mac 端实际保存的文件名。如果目标目录已有同名文件，Mac 会自动追加序号，例如 `receipt 2.pdf`。
- `savedPath`：Mac 端实际保存路径，跟随 Mac 设置页里的文件投递保存目录。
- `size`：Mac 端确认保存的字节数。

兼容路径：

- Mac 端仍保留 legacy JSON Base64 / multipart 解析能力，便于旧客户端或调试工具兼容
- 当前 Android 客户端默认只走 raw 二进制直传路径

当前限制：

- 同名文件自动追加序号，例如 `receipt 2.pdf`
- 保存目录由 Mac 端配置决定；未配置时使用 `~/Downloads/Android Mac Notify`
- 不支持断点续传或后台大文件队列
- 不设置产品层固定大小上限；实际可传大小受 Android 内容读取、网络稳定性、Mac 磁盘空间和单次 HTTP 连接可用性影响
- 未知长度的 Android Uri 会先在 Android 端缓存为临时文件以获得 `Content-Length`

失败状态：

- `400 Bad Request`
  - 文件载荷无法解码，或 `size` 与实际内容不一致
- `401 Unauthorized`
  - `deviceToken` 无效
- `403 Forbidden`
  - `deviceId` 与 token 不匹配
- `413 Payload Too Large`
  - 请求头或请求体超过接收器可处理边界
- `500 Internal Server Error`
  - Mac 保存文件失败

## 6. 错误模型

统一错误结构：

```json
{
  "error": {
    "code": "INVALID_DEVICE_TOKEN",
    "message": "Device token is invalid.",
    "retryable": false
  }
}
```

字段说明：

- `code`：稳定错误码
- `message`：给日志和诊断页展示的短说明
- `retryable`：是否建议客户端自动重试

MVP 推荐错误码：

- `INVALID_REQUEST`
- `INVALID_PAIRING_TOKEN`
- `INVALID_DEVICE_TOKEN`
- `DEVICE_TOKEN_DEVICE_MISMATCH`
- `DEVICE_NOT_REGISTERED`
- `DEVICE_TRUST_CONFLICT`
- `SESSION_NOT_AVAILABLE`
- `PAYLOAD_TOO_LARGE`
- `FILE_TOO_LARGE`
- `INVALID_FILE_PAYLOAD`
- `FILE_SAVE_FAILED`
- `INTERNAL_ERROR`

## 7. Android 客户端重试建议

### 7.1 应重试

- 请求超时
- 连接失败
- `5xx`
- `retryable=true`

### 7.2 不应自动重试

- `400`
- `401`
- `403`
- `409`
- `retryable=false`

### 7.3 MVP 去重规则

Android 重试同一事件时，必须复用原 `eventId`。  
Mac 端对相同 `eventId` 的重复请求按幂等接收处理。

## 8. 状态模型

MVP 面向用户至少区分：

- `unpaired`
- `connecting`
- `connected`
- `paused`
- `mac_paused`
- `network_unreachable`
- `auth_failed`
- `disconnected_retrying`

服务端内部可有更细状态，但对用户展示先收敛到这些。

状态语义：

- `connected`：已配对且最近在线，Android 端接力运行中
- `paused`：已配对且最近在线，但 Android 端主动暂停接力
- `mac_paused`：已配对且 Mac 服务可达，但 Mac 端主动暂停接收通知和文件
- `disconnected_retrying`：已配对，但 Mac 最近没有看到该设备心跳或事件
- `unpaired`：Mac 没有该设备注册记录

## 9. 安全边界

MVP 安全策略：

- 仅本地网络使用
- 默认初次配对需要 Mac 端用户允许
- 一次性 `pairingToken` 仅作为开发和兜底注册方式
- 后续请求使用长期 `deviceToken`
- Mac 只接受已注册设备的事件

MVP 暂不做：

- 复杂证书体系
- 公钥交换
- 云端身份同步

## 10. 后续扩展口

这套 API 需要能平滑扩展到：

- 文件投递的断点续传、后台队列和目录规则扩展
- 多设备支持
- 更丰富的主动分享
- 更复杂的通知动作

因此预留：

- `/api/v1/events/...`
- `/api/v1/share/...`
- `/api/v1/session/...`

但 MVP 先只实现本文列出的最小接口集。
