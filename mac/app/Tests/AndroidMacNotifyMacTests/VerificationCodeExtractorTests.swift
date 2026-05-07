import Testing
@testable import AndroidMacNotifyMac

struct VerificationCodeExtractorTests {
    @Test
    func testURLPortIsNotTreatedAsVerificationCode() {
        let context = VerificationCodeExtractor.extract(
            from: "Codex 链接持久化测试",
            text: "打开这个本地链接后，重启不应回到待处理：http://127.0.0.1:38471/api/v1/discovery",
            appName: "Browser"
        )

        #expect(context == nil)
    }

    @Test
    func testCodexURLIsNotTreatedAsEnglishCodeKeyword() {
        let context = VerificationCodeExtractor.extract(
            from: "Codex 普通链接测试",
            text: "打开这个链接：https://example.com/codex-persist",
            appName: "Browser"
        )

        #expect(context == nil)
    }

    @Test
    func testVerificationCodeStillExtractsWhenURLIsPresent() {
        let context = VerificationCodeExtractor.extract(
            from: "登录验证码",
            text: "验证码 864219，登录链接 https://example.com/login",
            appName: "短信"
        )

        #expect(context?.code == "864219")
    }

    @Test
    func testSmsVerificationCodeWithNumericSenderExtractsCode() {
        let context = VerificationCodeExtractor.extract(
            from: "106814270015948",
            text: "…您的验证码是 004488，请于15分钟内正确输入。",
            appName: "com.android.mms"
        )

        #expect(context?.code == "004488")
    }

    @Test
    func testShortNumericSmsSenderIsNotPreferredOverCodeText() {
        let context = VerificationCodeExtractor.extract(
            from: "1069",
            text: "您的验证码是 482913，5 分钟内有效。",
            appName: "短信"
        )

        #expect(context?.code == "482913")
    }

    @Test
    func testSmsVerificationKeywordWithoutCodeDoesNotExtractSenderNumber() {
        let context = VerificationCodeExtractor.extract(
            from: "1069",
            text: "您的验证码已发送，请稍后查看。",
            appName: "短信"
        )

        #expect(context == nil)
    }
}
