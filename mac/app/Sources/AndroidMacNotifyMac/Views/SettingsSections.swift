import SwiftUI

struct SettingsPairingRequestsSection: View {
    @ObservedObject var appState: AppState

    @ViewBuilder
    var body: some View {
        if !appState.pendingPairingRequests.isEmpty {
            Section("配对请求") {
                ForEach(appState.pendingPairingRequests, id: \.requestId) { request in
                    PairingApprovalRow(request: request, appState: appState)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

struct SettingsRelayOverviewSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Section("到达后处理") {
            LabeledContent("连接", value: appState.connectionState.title)
            LabeledContent("已接力事件", value: "\(appState.notificationsReceived)")
            LabeledContent("通知入口", value: "由 Android 决定")
            LabeledContent("Mac 处理", value: "复制验证码 / 打开链接")
            LabeledContent("历史保留", value: "只保留可回看事件")
            LabeledContent("验证码", value: "临时动作，不落长期历史")
        }
    }
}

struct SettingsPrivacyHistorySection: View {
    let onClearHistory: () -> Void

    var body: some View {
        Section("隐私与历史") {
            LabeledContent("历史保留", value: "100 条 / 24 小时")
            LabeledContent("临时动作", value: "10 分钟")
            Button("清空通知历史", role: .destructive) {
                onClearHistory()
            }
        }
    }
}

struct SettingsFileDeliverySection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Section("文件投递") {
            LabeledContent("保存位置") {
                Text(appState.sharedFileSaveDirectoryDisplayText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack {
                Button("选择目录") {
                    appState.chooseSharedFileSaveDirectory()
                }
                Button("打开目录") {
                    appState.revealSharedFileSaveDirectory()
                }
                Button("恢复默认") {
                    appState.resetSharedFileSaveDirectory()
                }
            }
        }
    }
}

struct SettingsAdvancedSection: View {
    @ObservedObject var appState: AppState
    let onResetPairing: () -> Void

    private static let portFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1024
        formatter.maximum = 65535
        return formatter
    }()

    var body: some View {
        Section("连接与诊断") {
            LabeledContent("接力服务", value: receiverSummary)
            LabeledContent("Mac", value: appState.macDisplayName)
            if let pairedDeviceName = appState.pairedDeviceName {
                LabeledContent("Android", value: pairedDeviceName)
            }

            LabeledContent("Host") {
                TextField("Host", text: $appState.currentHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }

            LabeledContent("Port") {
                TextField("Port", value: $appState.currentPort, formatter: Self.portFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 128)
                    .onSubmit {
                        appState.currentPort = min(max(appState.currentPort, 1024), 65535)
                    }
            }

            HStack {
                Button(appState.isReceiverPaused ? "恢复接力" : "暂停接力") {
                    appState.toggleReceiverPause()
                }
                .disabled({
                    if case .running = appState.serverStatus {
                        return false
                    }
                    return true
                }())
                Button("启动") {
                    appState.startLocalServer()
                }
                Button("停止") {
                    appState.stopLocalServer()
                }
            }

            if let macDeviceId = appState.macDeviceId {
                LabeledContent("Mac ID", value: macDeviceId)
            }

            if let pairingToken = appState.pairingToken {
                LabeledContent("Pairing Token") {
                    Text(pairingToken)
                        .textSelection(.enabled)
                        .font(.system(.caption, design: .monospaced))
                }
                if let expiresDate = appState.pairingTokenExpiresDate {
                    LabeledContent("Token 过期时间") {
                        Text(expiresDate, style: .time)
                    }
                }
            }

            LabeledContent("二维码载荷") {
                Text(appState.qrPayloadPreview)
                    .textSelection(.enabled)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(4)
            }

            if let lastError = appState.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Button("重置配对状态", role: .destructive) {
                onResetPairing()
            }
        }
    }

    private var receiverSummary: String {
        switch appState.serverStatus {
        case let .running(host, port):
            return "\(host):\(port)"
        case .stopped:
            return "未启动"
        case .failed:
            return "异常"
        }
    }
}
