package com.vainve.androidmacnotify.notify

import android.app.Notification
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidNotificationRelayGateTest {
    @Test
    fun smsVerificationCodeMustRelay() {
        val decision = decide(
            packageName = "com.android.mms",
            title = "1069",
            text = "您的验证码是 482913，5 分钟内有效。",
        )

        assertTrue(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.RelayActionSignal, decision.reason)
    }

    @Test
    fun smsVerificationKeywordWithoutCodeDoesNotRelay() {
        val decision = decide(
            packageName = "com.android.mms",
            title = "1069",
            text = "您的验证码已发送，请稍后查看。",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.NoExecutableRelayAction, decision.reason)
    }

    @Test
    fun smsVerificationCodeInTextIsNotConfusedWithNumericSender() {
        val decision = decide(
            packageName = "com.android.mms",
            title = "1069",
            text = "…您的验证码是 004488，请于15分钟内正确输入。",
        )

        assertTrue(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.RelayActionSignal, decision.reason)
    }

    @Test
    fun ordinaryImWithoutHandoffSignalDoesNotRelay() {
        val decision = decide(
            packageName = "com.tencent.mm",
            title = "朋友",
            text = "今天晚上吃饭吗",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.OrdinaryImWithoutHandoff, decision.reason)
    }

    @Test
    fun imLinkStillRelaysAsHandoffAction() {
        val decision = decide(
            packageName = "com.tencent.mm",
            title = "朋友",
            text = "资料在 https://example.com/doc 这里",
        )

        assertTrue(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.RelayActionSignal, decision.reason)
    }

    @Test
    fun selfHandoffImWithoutLinkOrCodeDoesNotRelay() {
        val decision = decide(
            packageName = "com.tencent.mm",
            title = "文件传输助手",
            text = "这段文字等下在 Mac 上用",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.OrdinaryImWithoutHandoff, decision.reason)
    }

    @Test
    fun selfHandoffSignalInExpandedContextWithoutLinkOrCodeDoesNotRelay() {
        val decision = decide(
            packageName = "com.tencent.mm",
            title = "微信",
            text = "这段文字等下在 Mac 上用\n文件传输助手",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.OrdinaryImWithoutHandoff, decision.reason)
    }

    @Test
    fun foodDeliveryStatusDoesNotRelayByDefault() {
        val decision = decide(
            packageName = "com.sankuai.meituan.takeoutnew",
            title = "美团外卖",
            text = "骑手正在配送，预计 10 分钟送达。",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.NoExecutableRelayAction, decision.reason)
    }

    @Test
    fun highConfidenceMarketingDoesNotRelay() {
        val decision = decide(
            packageName = "com.taobao.taobao",
            title = "五一特惠限时立省",
            text = "会员福利大放送，领券低至 7.9 元。",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, decision.reason)
    }

    @Test
    fun lowValueFeedNotificationsDoNotRelayWithoutActionSignal() {
        val xhs = decide(
            packageName = "com.xingin.xhs",
            title = "小红书",
            text = "开始用 Codex 辅助开发后，我写代码的方式",
        )
        val bilibili = decide(
            packageName = "tv.danmaku.bili",
            title = "兰兮香事 [你的关注]",
            text = "发了视频：难道就因为我不红，就可以随意盗用我的视频？",
        )

        assertFalse(xhs.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, xhs.reason)
        assertFalse(bilibili.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, bilibili.reason)
    }

    @Test
    fun commerceMarketingNotificationsDoNotRelayWithoutStatusSignal() {
        val alipay = decide(
            packageName = "com.eg.android.AlipayGphone",
            title = "稳健储蓄新选择",
            text = "年领比例5.21%，收益写入合同，100%保证领取",
        )
        val jd = decide(
            packageName = "com.jingdong.app.mall",
            title = "福利集结",
            text = "狂欢开启，超多福利，点击领取~",
        )

        assertFalse(alipay.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, alipay.reason)
        assertFalse(jd.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, jd.reason)
    }

    @Test
    fun ongoingOrProgressSystemStateDoesNotRelay() {
        val ongoing = decide(
            packageName = "com.example.music",
            title = "正在播放",
            text = "歌曲名",
            isOngoing = true,
        )
        val progress = decide(
            packageName = "com.android.providers.downloads",
            title = "下载中",
            text = "已下载 32%",
            category = Notification.CATEGORY_PROGRESS,
        )

        assertFalse(ongoing.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.OngoingSystemState, ongoing.reason)
        assertFalse(progress.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.SystemNoise, progress.reason)
    }

    @Test
    fun unknownNonActionNotificationDoesNotRelay() {
        val decision = decide(
            packageName = "com.example.bank",
            title = "服务提醒",
            text = "请查看新的账户消息。",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.NoExecutableRelayAction, decision.reason)
    }

    @Test
    fun lowValueFeedLinkDoesNotRelay() {
        val decision = decide(
            packageName = "tv.danmaku.bili",
            title = "你关注的人发了视频",
            text = "https://www.bilibili.com/video/example",
        )

        assertFalse(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.HighConfidenceNoise, decision.reason)
    }

    @Test
    fun unknownLinkRelaysAsMacExecutableAction() {
        val decision = decide(
            packageName = "com.example.docs",
            title = "文档链接",
            text = "打开 https://example.com/docs 继续处理。",
        )

        assertTrue(decision.shouldRelay)
        assertEquals(AndroidNotificationRelayDecisionReason.RelayActionSignal, decision.reason)
    }

    private fun decide(
        packageName: String,
        title: String,
        text: String,
        category: String? = null,
        isOngoing: Boolean = false,
    ): AndroidNotificationRelayDecision {
        return AndroidNotificationRelayGate.decide(
            AndroidNotificationRelayInput(
                packageName = packageName,
                title = title,
                text = text,
                category = category,
                isOngoing = isOngoing,
            )
        )
    }
}
