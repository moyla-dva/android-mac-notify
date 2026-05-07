import Foundation

extension SharedFileDeliveryGroup {
    var receivedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(receivedAt) / 1000)
    }
}

extension LocalNotificationSummary {
    var receivedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(receivedAt) / 1000)
    }

    var receivedRelativeText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(receivedDate)))
        if seconds < 60 {
            return "刚刚"
        }
        if seconds < 3_600 {
            return "\(seconds / 60) 分钟前"
        }
        if seconds < 86_400 {
            return "\(seconds / 3_600) 小时前"
        }
        return "\(seconds / 86_400) 天前"
    }

    var isTransientActionSummary: Bool {
        NotificationHistoryPolicy.shouldKeepTransientActionSummary(
            self,
            now: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }

    var routeBadgeText: String? {
        if ruleDecision.reasonCodes.contains("shared_file_received") {
            return "文件"
        }
        if ruleDecision.primarySurface == .statusCard {
            return "状态"
        }
        if isTransientActionSummary {
            return "临时"
        }
        if routesToActionInbox {
            return "动作"
        }
        if ruleDecision.shouldPresentSystemNotification {
            return "提醒"
        }
        if isLowValueHistoryOnly {
            return "静默"
        }
        if ruleDecision.primarySurface == .history {
            return "历史"
        }
        return nil
    }

    var isUserRuleApplied: Bool {
        ruleDecision.reasonCodes.contains("user_rule_applied")
    }

    var isLowValueHistoryOnly: Bool {
        ruleDecision.reasonCodes.contains("low_value_history_only")
            || ruleDecision.interruptionLevel == .none && ruleDecision.primarySurface == .history
    }

    var displayAppName: String {
        let raw = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let package = appPackage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (package?.isEmpty == false ? package : raw).orEmpty.lowercased()

        switch key {
        case "com.tencent.mm":
            return "微信"
        case "com.tencent.mobileqq":
            return "QQ"
        case "com.tencent.tim":
            return "TIM"
        case "com.android.mms", "com.google.android.apps.messaging", "com.huawei.message":
            return "短信"
        case "com.taobao.taobao":
            return "淘宝"
        case "com.taobao.idlefish", "idlefish":
            return "闲鱼"
        case "com.eg.android.alipaygphone", "alipaygphone":
            return "支付宝"
        case "com.xingin.xhs", "xhs":
            return "小红书"
        case "tv.danmaku.bili", "bilibili":
            return "哔哩哔哩"
        case "com.netease.cloudmusic", "cloudmusic":
            return "网易云音乐"
        case "org.telegram.messenger", "org.telegram.messenger.web", "org.thunderdog.challegram", "telegram":
            return "Telegram"
        case "com.greenpoint.android.mc10086.activity", "activity":
            return "中国移动"
        case "com.sankuai.meituan", "com.sankuai.meituan.takeoutnew":
            return "美团外卖"
        case "me.ele":
            return "饿了么"
        default:
            if raw.hasPrefix("com.") {
                return packageDisplayFallback(raw)
            }
            return raw.isEmpty ? "Android" : raw
        }
    }

    var displaySourceTitle: String {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, cleanedTitle != displayAppName else {
            return displayAppName
        }
        return "\(displayAppName) · \(cleanedTitle)"
    }

    var primaryPreview: String {
        if let senderLabel = verificationSenderLabel, !senderLabel.isBlankLike {
            return "发送方 \(senderLabel)"
        }

        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedText.isEmpty {
            return cleanedText
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? "无标题内容" : cleanedTitle
    }

    var sharedFilePath: String? {
        actionCandidates.first { $0.kind == .openFile }?.fileValue?.path
            ?? actionCandidates.first { $0.kind == .revealFile }?.fileValue?.path
            ?? actionCandidates.first { $0.kind == .copyFilePath }?.fileValue?.path
    }

    var sharedFileSizeText: String? {
        let parts = text.components(separatedBy: " · ")
        let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first, !first.isEmpty, first != text else {
            return nil
        }
        return first
    }

    private func packageDisplayFallback(_ raw: String) -> String {
        guard let lastComponent = raw.split(separator: ".").last else {
            return raw
        }
        let value = String(lastComponent)
        return value.isEmpty ? raw : value
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}

private extension String {
    var isBlankLike: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
