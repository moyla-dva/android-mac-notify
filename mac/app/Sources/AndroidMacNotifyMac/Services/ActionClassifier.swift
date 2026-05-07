import Foundation

enum ActionClassifier {
    private static let textHandoffPackages: Set<String> = [
        "com.android.mms",
        "com.google.android.apps.messaging",
        "com.huawei.message",
        "com.tencent.mm",
        "com.tencent.mobileqq",
        "com.tencent.tim",
        "org.telegram.messenger",
        "org.thunderdog.challegram",
    ]

    private static let textHandoffAppNames: Set<String> = [
        "messages",
        "message",
        "短信",
        "信息",
        "微信",
        "wechat",
        "weixin",
        "qq",
        "tim",
        "telegram",
    ]

    static func candidates(for event: InboundEvent) -> [ActionCandidate] {
        switch event.payload {
        case let .notification(payload):
            return notificationCandidates(for: event, payload: payload)
        }
    }

    private static func notificationCandidates(for event: InboundEvent, payload: NotificationPayload) -> [ActionCandidate] {
        var candidates: [ActionCandidate] = [
            ActionCandidate(
                actionId: actionId(event.eventId, "show-notification"),
                sourceEventId: event.eventId,
                kind: .showNotification,
                title: "显示通知",
                value: nil,
                priority: .low,
                payload: .notificationPreview(title: payload.title, text: payload.text)
            ),
            ActionCandidate(
                actionId: actionId(event.eventId, "record-history"),
                sourceEventId: event.eventId,
                kind: .recordHistory,
                title: "记录历史",
                value: nil,
                priority: .low,
                payload: .historyRecord
            ),
        ]

        let verificationContext = VerificationCodeExtractor.extract(
            from: payload.title,
            text: payload.text,
            appName: payload.appName
        )

        if let verificationContext {
            candidates.append(
                ActionCandidate(
                    actionId: actionId(event.eventId, "copy-verification-code"),
                    sourceEventId: event.eventId,
                    kind: .copyVerificationCode,
                    title: "复制验证码",
                    value: verificationContext.code,
                    priority: .high,
                    payload: .verificationCode(
                        code: verificationContext.code,
                        senderLabel: verificationContext.senderLabel
                    )
                )
            )
        }

        for (index, url) in links(in: [payload.title, payload.text].joined(separator: "\n")).prefix(3).enumerated() {
            candidates.append(
                ActionCandidate(
                    actionId: actionId(event.eventId, "open-link-\(index + 1)"),
                    sourceEventId: event.eventId,
                    kind: .openLink,
                    title: index == 0 ? "打开链接" : "打开链接 \(index + 1)",
                    value: url,
                    priority: .medium,
                    payload: .link(url: url)
                )
            )
        }

        if verificationContext == nil,
           shouldOfferCopyText(for: payload),
           let copyText = copyableText(from: payload) {
            candidates.append(
                ActionCandidate(
                    actionId: actionId(event.eventId, "copy-text"),
                    sourceEventId: event.eventId,
                    kind: .copyText,
                    title: "复制文本",
                    value: copyText,
                    priority: .low,
                    payload: .text(value: copyText)
                )
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.actionId < rhs.actionId
            }
            return lhs.priority > rhs.priority
        }
    }

    private static func actionId(_ eventId: String, _ suffix: String) -> String {
        "act_\(eventId)_\(suffix)"
    }

    private static func shouldOfferCopyText(for payload: NotificationPayload) -> Bool {
        let packageName = payload.appPackage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let appName = payload.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return textHandoffPackages.contains(packageName)
            || textHandoffAppNames.contains(appName)
    }

    private static func copyableText(from payload: NotificationPayload) -> String? {
        for candidate in [payload.text, payload.title] {
            if let normalized = normalizedCopyableText(candidate, title: payload.title) {
                return String(normalized.prefix(1_000))
            }
        }

        return nil
    }

    private static func normalizedCopyableText(_ rawText: String, title: String) -> String? {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        let hadCountPrefix = text.range(
            of: #"^\[\d+\s*条\]\s*"#,
            options: .regularExpression
        ) != nil
        text = text.replacingOccurrences(
            of: #"^\[\d+\s*条\]\s*"#,
            with: "",
            options: .regularExpression
        )

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedTitle.isEmpty {
            let escapedTitle = NSRegularExpression.escapedPattern(for: normalizedTitle)
            text = text.replacingOccurrences(
                of: #"^\#(escapedTitle)\s*[:：]\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        if hadCountPrefix {
            text = text.replacingOccurrences(
                of: #"^[^\n:：]{1,32}\s*[:：]\s*"#,
                with: "",
                options: .regularExpression
            )
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func links(in text: String) -> [String] {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return []
        }

        let detectorLinks = detectedLinks(in: normalizedText)
        if !detectorLinks.isEmpty {
            return detectorLinks
        }

        return fallbackHTTPLinks(in: normalizedText)
    }

    private static func detectedLinks(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var seen: Set<String> = []
        var links: [String] = []

        for match in detector.matches(in: text, options: [], range: range) {
            guard let urlString = match.url?.absoluteString, !seen.contains(urlString) else {
                continue
            }
            seen.insert(urlString)
            links.append(urlString)
        }

        return links
    }

    private static func fallbackHTTPLinks(in text: String) -> [String] {
        let pattern = #"https?://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        var seen: Set<String> = []
        var links: [String] = []

        for match in regex.matches(in: text, options: [], range: range) {
            let urlString = nsText.substring(with: match.range)
            guard !seen.contains(urlString) else {
                continue
            }
            seen.insert(urlString)
            links.append(urlString)
        }

        return links
    }
}
