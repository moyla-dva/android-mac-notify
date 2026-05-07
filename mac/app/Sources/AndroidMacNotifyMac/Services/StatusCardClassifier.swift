import Foundation

enum StatusCardClassifier {
    static func cardState(from summary: LocalNotificationSummary) -> StatusCardState? {
        DeliveryStatusProvider.cardState(from: summary)
    }

    static func cardState(
        from payload: NotificationPayload,
        sourceEventId: String,
        updatedAt: Int64
    ) -> StatusCardState? {
        DeliveryStatusProvider.cardState(
            from: payload,
            sourceEventId: sourceEventId,
            updatedAt: updatedAt
        )
    }
}

private enum DeliveryStatusProvider {
    private static let deliveryAppIdentifiers: Set<String> = [
        "com.sankuai.meituan",
        "com.sankuai.meituan.takeoutnew",
        "me.ele",
        "com.taobao.taobao",
        "com.jingdong.app.mall",
        "美团",
        "美团外卖",
        "饿了么",
        "淘宝",
        "淘宝闪购",
        "京东",
        "京东到家",
    ]

    private static let deliveryKeywords: [String] = [
        "外卖",
        "骑手",
        "配送员",
        "配送中",
        "正在配送",
        "送达",
        "已送达",
        "预计送达",
        "取餐",
        "备餐",
        "商家已接单",
        "餐品",
        "淘宝闪购",
        "京东到家",
    ]

    private static let issueKeywords: [String] = [
        "异常",
        "取消",
        "超时",
        "配送失败",
        "联系不上",
        "退款",
    ]

    private static let marketingTitleKeywords: [String] = [
        "金币",
        "奖励",
        "红包",
        "优惠",
        "秒杀",
        "福利",
        "促销",
        "会员",
        "抽奖",
    ]

    static func cardState(from summary: LocalNotificationSummary) -> StatusCardState? {
        let payload = NotificationPayload(
            appPackage: summary.appPackage.orEmpty,
            appName: summary.appName,
            title: summary.title,
            text: summary.text,
            notificationKey: ""
        )
        return cardState(
            from: payload,
            sourceEventId: summary.eventId,
            updatedAt: summary.receivedAt
        )
    }

    static func cardState(
        from payload: NotificationPayload,
        sourceEventId: String,
        updatedAt: Int64
    ) -> StatusCardState? {
        guard isDeliveryRelated(payload), !isMarketingDeliveryNoise(payload) else {
            return nil
        }

        let deliveryStage = classifyStage(payload)
        let detail = [payload.title, payload.text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            ?? "外卖状态已更新"

        return StatusCardState(
            id: statusCardId(for: payload),
            category: .delivery,
            sourceEventId: sourceEventId,
            appName: payload.appName,
            title: deliveryStage.title,
            detail: String(detail.prefix(120)),
            stage: deliveryStage.statusStage,
            etaText: etaText(from: payload),
            updatedAt: updatedAt
        )
    }

    static func isDeliveryRelated(_ payload: NotificationPayload) -> Bool {
        matchesIdentifier(payload, identifiers: deliveryAppIdentifiers)
            && containsAnyKeyword(payload, keywords: deliveryKeywords + issueKeywords)
    }

    private static func isMarketingDeliveryNoise(_ payload: NotificationPayload) -> Bool {
        let title = normalized(payload.title)
        let hasOrderTitle = ["订单通知", "外卖", "闪购", "京东到家"].contains { keyword in
            title.contains(normalized(keyword))
        }
        guard !hasOrderTitle else {
            return false
        }

        return marketingTitleKeywords.contains { keyword in
            title.contains(normalized(keyword))
        }
    }

    private static func classifyStage(_ payload: NotificationPayload) -> DeliveryStatusSnapshot {
        if containsAnyKeyword(payload, keywords: issueKeywords) {
            return DeliveryStatusSnapshot(statusStage: .issue, title: "需要关注")
        }
        if containsAnyKeyword(payload, keywords: ["已送达", "送达成功", "订单已送达", "已完成"]) {
            return DeliveryStatusSnapshot(statusStage: .completed, title: "已送达")
        }
        if containsAnyKeyword(
            payload,
            keywords: [
                "配送中",
                "正在配送",
                "骑手正在",
                "骑手已取餐",
                "已取餐",
                "即将送达",
                "正在送",
                "已经送出",
                "已送出",
                "订单已经送出",
                "订单已送出",
                "已出餐",
                "正在送往",
            ]
        ) {
            return DeliveryStatusSnapshot(statusStage: .inProgress, title: "配送中")
        }
        if containsAnyKeyword(payload, keywords: ["骑手已接单", "骑手接单", "正在取餐", "取餐中", "待取餐"]) {
            return DeliveryStatusSnapshot(statusStage: .handoff, title: "骑手取餐")
        }
        if containsAnyKeyword(payload, keywords: ["备餐", "商家已接单", "制作中", "正在出餐", "准备中"]) {
            return DeliveryStatusSnapshot(statusStage: .preparing, title: "备餐中")
        }
        return DeliveryStatusSnapshot(statusStage: .queued, title: "已下单")
    }

    private static func etaText(from payload: NotificationPayload) -> String? {
        let text = [payload.title, payload.text].joined(separator: "\n")

        if let minutes = firstMatch(
            in: text,
            pattern: #"(?:预计|约|还需|大约).{0,8}?(\d{1,3})\s*(?:分钟|min)"#
        ) {
            return "预计 \(minutes) 分钟"
        }

        if let time = firstMatch(
            in: text,
            pattern: #"(\d{1,2}:\d{2}).{0,8}(?:送达|到达)"#
        ) {
            return "预计 \(time)"
        }

        return nil
    }

    private static func statusCardId(for payload: NotificationPayload) -> String {
        let app = normalized(payload.appPackage).isEmpty ? normalized(payload.appName) : normalized(payload.appPackage)
        return "delivery-\(app)"
    }

    private static func matchesIdentifier(
        _ payload: NotificationPayload,
        identifiers: Set<String>
    ) -> Bool {
        let packageName = normalized(payload.appPackage)
        let appName = normalized(payload.appName)
        return identifiers.contains(packageName) || identifiers.contains(appName)
    }

    private static func containsAnyKeyword(
        _ payload: NotificationPayload,
        keywords: [String]
    ) -> Bool {
        let haystack = normalized([payload.appName, payload.title, payload.text].joined(separator: "\n"))
        return keywords.contains { keyword in
            haystack.contains(normalized(keyword))
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return nil
        }

        return nsText.substring(with: match.range(at: 1))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct DeliveryStatusSnapshot {
    let statusStage: StatusCardStage
    let title: String
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
