import Foundation

extension ActionKind {
    var displayTitle: String {
        switch self {
        case .showNotification:
            return "显示通知"
        case .copyVerificationCode:
            return "复制验证码"
        case .openLink:
            return "打开链接"
        case .copyText:
            return "复制文本"
        case .openFile:
            return "打开文件"
        case .revealFile:
            return "在 Finder 中显示"
        case .copyFilePath:
            return "复制路径"
        case .recordHistory:
            return "记录历史"
        }
    }
}
