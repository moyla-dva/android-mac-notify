# File Delivery MVP

## 1. Goal

文件投递的第一版目标不是做完整网盘或 AirDrop 替代品，而是验证一条轻量动作链路：

```text
Android system share -> Android Mac Notify -> Mac local receiver -> configured Mac folder -> success feedback
```

它属于 Phase 2 的动作扩展，但实现方式必须保持小而稳，不能反过来拖慢通知主链。

## 2. Current Scope

当前版本支持：

- Android 系统分享面板中的单文件和多文件投递
- Android 端文件投递状态页，显示文件、大小、目标 Mac、投递阶段和失败修复入口
- 已配对设备使用 `deviceToken` 鉴权
- Mac 默认保存到 `~/Downloads/Android Mac Notify`，并支持在 Mac 设置页修改保存目录
- 文件名清理和同名自动改名
- raw 二进制直传，避免 Base64 放大和大字符串内存开销
- 大文件投递进度、速度和接收状态反馈
- 多文件投递时，Mac 接收状态会显示当前正在接收第几个文件
- 文件上传使用长传输 HTTP client，不设置固定读写超时；取消投递时通过主动取消请求中断
- Android 读取与 Mac 接收均使用较大的流式缓冲块，减少大文件传输时的读写调用开销
- Mac raw 接收会先在目标保存目录内写入隐藏临时文件，完整接收后再落成最终文件名，避免大文件受系统临时目录空间限制
- Mac 在接收大文件前会检查目标保存目录可用空间；明显不足时直接返回空间不足错误，Android 保持 Mac 可达状态并显示文件投递失败
- Android 会清理过期的未知大小或不可靠大小文件上传缓存；Mac 会清理目标保存目录中过期的隐藏投递临时文件，避免中断传输长期占用空间
- Android 从系统分享入口接收文件时，会在系统授予可持久化读取权限的情况下保存权限；只给临时权限的来源仍可能需要用户重新分享或重新选择
- Mac 主窗口显示文件接收卡片
- 文件卡片提供 `打开文件`、`在 Finder 中显示`、`复制路径`
- 多文件批量接收后提供 `显示全部`、`复制全部路径`
- 菜单栏弹窗和主窗口都可直接执行文件动作；文件投递不再默认发 macOS 系统通知

当前暂不支持：

- 断点续传
- 后台大文件队列
- 按 App、文件类型或设备自动分流的目标目录规则
- Mac 反向拉取 Android 文件

## 3. Data Flow

```text
Android ACTION_SEND / ACTION_SEND_MULTIPLE
-> ContentResolver 读取 Uri
-> Android 状态页显示读取配置 / 准备 / 发送 / 完成
-> 生成 shareId / batchId / fileName / mimeType / size
-> raw binary POST /api/v1/share/file
-> Mac 校验 token 与 deviceId
-> Mac 流式写入临时文件并上报接收进度
-> SharedFileStore 移动到 Mac 配置的保存目录并处理同名
-> SharedFileActionFactory 生成文件动作和批量动作
-> AppState 显示文件卡片并触发菜单栏动作入口
```

协议主路径：

- `X-AMN-Upload-Mode: raw`
- `X-AMN-Device-Id`
- `X-AMN-Share-Id`
- `X-AMN-File-Name-B64`
- `X-AMN-Mime-Type`
- `X-AMN-Shared-At`
- 多文件额外带 `X-AMN-Batch-Id`、`X-AMN-Batch-Index`、`X-AMN-Batch-Total`

Mac 端保留 legacy JSON Base64 / multipart 解析兼容路径，但当前 Android 客户端默认只走 raw 二进制直传。

## 4. Storage Rule

默认保存目录：

```text
~/Downloads/Android Mac Notify
```

用户可以在 Mac 端 `设置 -> 文件投递` 选择新的保存目录。该配置持久化在 Mac 本地，后续单文件、多文件和大文件投递都会使用同一目录；恢复默认后重新落回上述下载目录。

文件名规则：

- 移除路径分隔符和控制字符
- 空文件名回退为 `shared-file`
- 同名时追加序号，例如 `note 2.txt`
- Mac 响应中的 `fileName` 是实际保存名；Android 完成态和最近投递记录需要展示这个名字，避免用户误以为旧文件被覆盖

## 5. Safety Boundaries

- 不设置产品层固定大小上限
- 实际上限由 Android 内容读取、网络稳定性、Mac 磁盘空间和单次 HTTP 连接可用性决定
- 未知长度、声明大小不可靠或文本类的 Uri 会先在 Android 端缓存成临时文件，以获得真实可声明的 `Content-Length`
- 这类缓存路径会检查 Android 本机临时空间；空间不足时明确提示用户清理手机空间后重试
- 文件内容不写入通知历史
- API 只接受已注册设备的 Bearer token
- 保存失败时返回可诊断错误，不静默吞掉
- 文件卡片只记录路径、文件名、大小、接收时间，不复制保存文件内容
- 文件发生自动改名时，Mac 文件卡片显示“已改名”提示；Android 端完成态显示“Mac 已保存为 ...”

## 6. Failure And Retry Rules

文件投递失败时，Android 端按失败类型决定是否给出重试：

- 网络中断、Mac 暂停接收、Mac 返回 `retryable=true`：保留当前文件选择，显示重试。
- 用户主动取消：保留重试入口，方便继续投递同一批文件。
- 多文件投递中断时，重试只从未完成文件继续，不重新发送已经成功保存到 Mac 的文件。
- token 失效、设备不匹配、设备未注册：不显示重试，进入“重新连接 Mac”的修复路径。
- 原文件 Uri 权限失效：不显示重试，提示用户重新从系统分享菜单或文件页选择文件。
- 未连接/未配对：不显示重试，先完成连接和配对。
- 失败或取消记录重试成功后，Android 最近投递会自动移除同源文件的旧失败/取消记录，只保留新的成功闭环。

文件投递失败也会同步更新 Android 端 Mac 可达状态：

- `AuthFailed`：旧配对已失效，需要重新连接。
- `MacPaused`：Mac 可达，但暂停接收通知和文件。
- `Unreachable`：网络、端口或 Mac 接收器不可达。

在 `MacPaused` 或 `Unreachable` 这类恢复态下，Android 心跳会临时使用更短探测间隔，避免 Mac 恢复后仍等待完整常规心跳周期。

## 7. Test Material

建议先用这些文件验证：

- 纯文本：`note.txt`，几 KB
- 图片：`photo.jpg`，1-3MB
- PDF：`receipt.pdf`，1-5MB
- APK 或视频：100MB 以上，用于验证 raw 直传和进度
- 大文件：1GB / 2GB，用于验证无固定产品层大小上限时的稳定性
- 多文件：相册一次选择 3-6 张图片分享
- 同名文件：连续分享两次 `note.txt`
- 冷启动分享：先退出 Android app，再从系统相册分享图片到 Android Mac Notify
- 中断场景：传输中断开 Wi-Fi 或关闭 Mac 接收器，应失败并在 Android 端显示可重试反馈

## 8. Android UI Rules

- 从系统分享进入时，默认展示文件投递页，而不是普通配对页。
- 投递页只围绕当前任务组织：文件、目标 Mac、阶段、结果。
- 多文件传输很快时，UI 不应一闪而过；需要保留完成态，让用户能确认已发送到哪台 Mac。
- 已配对时不要求用户再次输入 token。
- 未配对或 Mac 不可达时，文件页只提示去设备页处理连接。
- 文件名必须允许长文本截断，不能挤压主操作。
- 所有主要按钮保持至少 48dp 触控高度。
- 用户打开系统文件选择器后直接返回/取消时，不生成失败任务，也不改变当前页面状态。
- 失败或取消态以恢复说明为主，不展示未知文件卡或技术流程步骤条；只有真实选中文件后才展示文件信息。
- 文件页不承载设备发现、手动地址或配对表单；这些连接管理能力统一放到设备页。
- 未配对时，文件页只显示轻量引导卡和“去设备页连接”按钮，避免把文件投递页变成第二个设备页。
- 已配对状态下，文件投递失败或取消不自动展开连接设置，避免把文件失败误导成重新配对流程。

## 9. Next Decisions

如果真实使用顺滑，再考虑：

1. 断点续传或分片续传。
2. 按来源 App、文件类型、设备或场景分流的目标目录规则。
3. 后台大文件队列。
4. 文件卡片保留策略从短期记录升级为可配置策略。
5. 与外部状态卡片共用“进行中 / 完成 / 批量操作”的显示模型。
