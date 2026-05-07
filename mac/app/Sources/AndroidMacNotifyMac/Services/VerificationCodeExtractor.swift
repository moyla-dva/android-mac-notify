import Foundation

enum VerificationCodeExtractor {
    private static let keywordPattern = #"(验证码|校验码|动态码|动态密码|短信码|安全码|提取码|登录码|\bverification\s+code\b|\bsecurity\s+code\b|\bone[- ]time\s+code\b|\botp\b|\bcode\b)"#
    private static let digitPattern = #"\b\d{4,8}\b"#
    private static let alphaNumericPattern = #"\b[A-Z0-9]{4,8}\b"#
    private static let bracketedSenderPattern = #"[【\[]\s*([^\]】]{1,20})\s*[\]】]"#
    private static let serviceBeforeKeywordPattern = #"([A-Za-z0-9\p{Han}][A-Za-z0-9\p{Han}\s\-\._]{1,18}?)(?:的)?(?:验证码|校验码|动态码|动态密码|短信码|安全码|提取码|登录码)"#
    private static let loginToPattern = #"(?:登录|sign in to|for)\s+([A-Za-z0-9\p{Han}\-\._]{2,20})"#

    static func extract(from title: String, text: String, appName: String) -> VerificationCodeContext? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeSearchTitle = normalizedTitle.removingDetectedURLs
        let codeSearchText = normalizedText.removingDetectedURLs
        let combined = [codeSearchTitle, codeSearchText].filter { !$0.isEmpty }.joined(separator: " ")

        guard !combined.isEmpty else {
            return nil
        }

        let hasKeyword = combined.matches(keywordPattern, options: [.caseInsensitive])
        let prioritizedText = hasKeyword ? combined : [appName, codeSearchTitle, codeSearchText].joined(separator: " ")
        let senderLabel = extractSenderLabel(from: normalizedTitle, text: normalizedText, appName: appName)

        if let exactKeywordNeighbor = extractNearestDigits(aroundKeywordsIn: prioritizedText) {
            return VerificationCodeContext(code: exactKeywordNeighbor, senderLabel: senderLabel)
        }

        if hasKeyword {
            let keywordFields = [codeSearchText, codeSearchTitle].filter {
                $0.matches(keywordPattern, options: [.caseInsensitive])
            }

            for field in keywordFields {
                if let firstDigits = field.firstMatch(digitPattern) {
                    return VerificationCodeContext(code: firstDigits, senderLabel: senderLabel)
                }
            }

            for field in keywordFields {
                if let firstAlphaNumeric = field.firstMatch(alphaNumericPattern), firstAlphaNumeric.containsNumber {
                    return VerificationCodeContext(code: firstAlphaNumeric, senderLabel: senderLabel)
                }
            }
        }

        return nil
    }

    private static func extractNearestDigits(aroundKeywordsIn text: String) -> String? {
        let keywordRegex = try? NSRegularExpression(pattern: keywordPattern, options: [.caseInsensitive])
        let digitRegex = try? NSRegularExpression(pattern: digitPattern)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        guard let keywordRegex, let digitRegex else {
            return nil
        }

        let keywordMatches = keywordRegex.matches(in: text, options: [], range: fullRange)
        let digitMatches = digitRegex.matches(in: text, options: [], range: fullRange)

        for keyword in keywordMatches {
            let afterStart = keyword.range.location + keyword.range.length
            let afterEnd = min(nsText.length, afterStart + 24)
            let afterRange = NSRange(location: afterStart, length: afterEnd - afterStart)

            if let afterDigits = digitMatches.first(where: { NSIntersectionRange($0.range, afterRange).length > 0 }) {
                return nsText.substring(with: afterDigits.range)
            }
        }

        return nil
    }

    private static func extractSenderLabel(from title: String, text: String, appName: String) -> String? {
        let candidates = [title, text, "\(title) \(text)"]

        if title.isUsefulSenderLabel(comparedWith: appName),
           !title.matches(keywordPattern, options: [.caseInsensitive]) {
            return title.normalizedSenderLabel
        }

        for candidate in candidates {
            if let bracketed = candidate.firstCapture(bracketedSenderPattern), bracketed.isUsefulSenderLabel(comparedWith: appName) {
                return bracketed
            }
        }

        for candidate in candidates {
            if let serviceName = candidate.firstCapture(serviceBeforeKeywordPattern)?.normalizedSenderLabel,
               serviceName.isUsefulSenderLabel(comparedWith: appName) {
                return serviceName
            }
        }

        for candidate in candidates {
            if let serviceName = candidate.firstCapture(loginToPattern)?.normalizedSenderLabel,
               serviceName.isUsefulSenderLabel(comparedWith: appName) {
                return serviceName
            }
        }
        return nil
    }
}

private extension String {
    func matches(_ pattern: String, options: NSRegularExpression.Options = []) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(startIndex..., in: self)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }

    func firstMatch(_ pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range),
              let swiftRange = Range(match.range, in: self) else {
            return nil
        }
        return String(self[swiftRange])
    }

    func firstCapture(_ pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[swiftRange])
    }

    var removingDetectedURLs: String {
        replacingOccurrences(
            of: #"https?://[^\s<>"']+"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    var containsNumber: Bool {
        rangeOfCharacter(from: .decimalDigits) != nil
    }

    var normalizedSenderLabel: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "...", with: " ")
            .replacingOccurrences(of: "…", with: " ")
            .replacingOccurrences(of: "您的", with: "")
            .replacingOccurrences(of: "你正在", with: "")
            .replacingOccurrences(of: "您正在", with: "")
            .replacingOccurrences(of: "验证码", with: "")
            .replacingOccurrences(of: "校验码", with: "")
            .replacingOccurrences(of: "动态码", with: "")
            .replacingOccurrences(of: "动态密码", with: "")
            .replacingOccurrences(of: "短信码", with: "")
            .replacingOccurrences(of: "安全码", with: "")
            .replacingOccurrences(of: "提取码", with: "")
            .replacingOccurrences(of: "登录码", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "：:[]【】()（）- "))
    }

    func isUsefulSenderLabel(comparedWith appName: String) -> Bool {
        let candidate = normalizedSenderLabel
        guard !candidate.isEmpty, candidate.count <= 20 else {
            return false
        }

        let genericLabels = [
            "短信",
            "信息",
            "messages",
            "message",
            "notification",
            "验证码",
            "校验码",
            "动态码",
            "短信码",
            "code",
        ]

        if genericLabels.contains(candidate.lowercased()) {
            return false
        }

        if candidate.caseInsensitiveCompare(appName) == .orderedSame {
            return false
        }

        return true
    }
}
