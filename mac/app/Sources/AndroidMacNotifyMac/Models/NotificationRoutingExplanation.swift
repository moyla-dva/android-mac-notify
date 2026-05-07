import Foundation

enum NotificationRoutingExplanationTone: Sendable {
    case neutral
    case accent
    case warning
}

struct NotificationRoutingExplanation: Equatable, Sendable {
    let text: String
    let systemImage: String
    let tone: NotificationRoutingExplanationTone
}

extension LocalNotificationSummary {
    var routingExplanation: NotificationRoutingExplanation? {
        if ruleDecision.primarySurface == .statusCard {
            if ruleDecision.statusCardPolicy?.shouldNotifyOnTerminal == true {
                return NotificationRoutingExplanation(
                    text: "这是持续状态事件，终态或异常会提醒你",
                    systemImage: "timeline.selection",
                    tone: .accent
                )
            }

            return NotificationRoutingExplanation(
                text: "这是持续状态事件，过程会安静更新",
                systemImage: "timeline.selection",
                tone: .neutral
            )
        }

        if hasReasonCode("shared_file_received") {
            return NotificationRoutingExplanation(
                text: "文件已保存，可直接在 Mac 打开或定位",
                systemImage: "doc",
                tone: .accent
            )
        }

        if ruleDecision.privacyLevel == .sensitive {
            if hasReasonCode("verification_code_detected") {
                return NotificationRoutingExplanation(
                    text: "检测到验证码，只做即时处理，不进长期历史",
                    systemImage: "number",
                    tone: .accent
                )
            }

            if hasReasonCode("copy_text_available") {
                return NotificationRoutingExplanation(
                    text: "文本可直接处理，为保护隐私不进长期历史",
                    systemImage: "hand.raised",
                    tone: .neutral
                )
            }
        }

        if routesToActionInbox {
            if verificationCode != nil {
                return NotificationRoutingExplanation(
                    text: "检测到验证码，只做即时处理，不进长期历史",
                    systemImage: "number",
                    tone: .accent
                )
            }

            if hasReasonCode("link_detected") {
                return NotificationRoutingExplanation(
                    text: "识别到链接，可直接在 Mac 打开",
                    systemImage: "safari",
                    tone: .accent
                )
            }

            if hasReasonCode("copy_text_available") {
                return NotificationRoutingExplanation(
                    text: "识别到文本，可直接在 Mac 复制",
                    systemImage: "text.quote",
                    tone: .accent
                )
            }

            return NotificationRoutingExplanation(
                text: "识别到可执行动作，可直接处理",
                systemImage: "bolt",
                tone: .accent
            )
        }

        if ruleDecision.shouldPresentSystemNotification {
            return NotificationRoutingExplanation(
                text: "这类通知默认会主动提醒",
                systemImage: "bell",
                tone: .neutral
            )
        }

        if routesToHistory {
            return NotificationRoutingExplanation(
                text: "已进入最近记录，可稍后回看",
                systemImage: "clock.arrow.circlepath",
                tone: .neutral
            )
        }

        return nil
    }

    private func hasReasonCode(_ code: String) -> Bool {
        ruleDecision.reasonCodes.contains(code)
    }
}
