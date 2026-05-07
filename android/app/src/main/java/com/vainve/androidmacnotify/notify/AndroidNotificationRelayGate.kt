package com.vainve.androidmacnotify.notify

import android.app.Notification

data class AndroidNotificationRelayInput(
    val packageName: String,
    val title: String,
    val text: String,
    val category: String?,
    val isOngoing: Boolean,
)

enum class AndroidNotificationRelayDecisionReason {
    EmptyContent,
    OngoingSystemState,
    RelayActionSignal,
    OrdinaryImWithoutHandoff,
    HighConfidenceNoise,
    SystemNoise,
    NoExecutableRelayAction,
}

data class AndroidNotificationRelayDecision(
    val shouldRelay: Boolean,
    val reason: AndroidNotificationRelayDecisionReason,
)

object AndroidNotificationRelayGate {
    fun decide(input: AndroidNotificationRelayInput): AndroidNotificationRelayDecision {
        val title = input.title.trim()
        val text = input.text.trim()
        val combined = "$title\n$text".lowercase()
        val packageName = input.packageName.lowercase()

        if (title.isBlank() && text.isBlank()) {
            return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.EmptyContent)
        }
        if (input.isOngoing) {
            return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.OngoingSystemState)
        }
        if (hasVerificationCodeSignal(title, text)) {
            return AndroidNotificationRelayDecision(true, AndroidNotificationRelayDecisionReason.RelayActionSignal)
        }
        if (isHighConfidenceNoise(packageName, combined)) {
            return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.HighConfidenceNoise)
        }
        if (isSystemNoise(input.category, combined)) {
            return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.SystemNoise)
        }
        if (hasMacExecutableLink(combined)) {
            return AndroidNotificationRelayDecision(true, AndroidNotificationRelayDecisionReason.RelayActionSignal)
        }
        if (isKnownImPackage(packageName)) {
            return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.OrdinaryImWithoutHandoff)
        }

        return AndroidNotificationRelayDecision(false, AndroidNotificationRelayDecisionReason.NoExecutableRelayAction)
    }

    private fun hasVerificationCodeSignal(title: String, text: String): Boolean {
        val codeSearchTitle = title.removingDetectedUrls()
        val codeSearchText = text.removingDetectedUrls()
        val combined = listOf(codeSearchTitle, codeSearchText)
            .filter { it.isNotBlank() }
            .joinToString(separator = " ")
        if (combined.isBlank() || !verificationKeywordRegex.containsMatchIn(combined)) {
            return false
        }

        if (hasCodeAfterKeyword(combined)) {
            return true
        }

        return hasKeywordAndCodeInSameField(codeSearchText) ||
            hasKeywordAndCodeInSameField(codeSearchTitle)
    }

    private fun hasMacExecutableLink(value: String): Boolean {
        return urlRegex.containsMatchIn(value)
    }

    private fun isKnownImPackage(packageName: String): Boolean {
        return knownImPackages.any { packageName == it || packageName.startsWith("$it.") }
    }

    private fun isHighConfidenceNoise(packageName: String, value: String): Boolean {
        val packageSuggestsLowValue = lowValueContentPackages.any { packageName == it || packageName.startsWith("$it.") }
        val strongNoise = highConfidenceNoisePhrases.any(value::contains)
        val marketingNoise = marketingKeywords.count(value::contains) >= 2
        val lowValueFeedNoise = lowValueFeedPackages.any { packageName == it || packageName.startsWith("$it.") }
        val commerceNoise = commerceNoisePackages.any { packageName == it || packageName.startsWith("$it.") } &&
            (marketingKeywords.any(value::contains) || financeMarketingKeywords.any(value::contains))
        return lowValueFeedNoise || commerceNoise || (packageSuggestsLowValue && (strongNoise || marketingNoise))
    }

    private fun isSystemNoise(category: String?, value: String): Boolean {
        val noisyCategory = when (category) {
            Notification.CATEGORY_PROGRESS,
            Notification.CATEGORY_RECOMMENDATION,
            Notification.CATEGORY_SERVICE,
            Notification.CATEGORY_STATUS,
            Notification.CATEGORY_TRANSPORT -> true
            else -> false
        }
        if (!noisyCategory) return false

        return systemNoiseKeywords.any(value::contains) || !verificationKeywordRegex.containsMatchIn(value) && !hasMacExecutableLink(value)
    }

    private fun hasCodeAfterKeyword(value: String): Boolean {
        return verificationKeywordRegex.findAll(value).any { match ->
            val searchEnd = minOf(value.length, match.range.last + 1 + 32)
            val afterKeyword = value.substring(match.range.last + 1, searchEnd)
            containsCodeToken(afterKeyword)
        }
    }

    private fun hasKeywordAndCodeInSameField(value: String): Boolean {
        return verificationKeywordRegex.containsMatchIn(value) && containsCodeToken(value)
    }

    private fun containsCodeToken(value: String): Boolean {
        return digitCodeRegex.containsMatchIn(value) ||
            alphaNumericCodeRegex.findAll(value).any { token ->
                token.value.any(Char::isDigit)
            }
    }

    private fun String.removingDetectedUrls(): String {
        return replace(urlRegex, " ")
    }

    private val verificationKeywordRegex = Regex(
        pattern = "(验证码|校验码|动态码|动态密码|登录码|短信码|安全码|提取码|verification\\s+code|security\\s+code|one[- ]time\\s+code|otp|\\bcode\\b)",
        option = RegexOption.IGNORE_CASE,
    )
    private val digitCodeRegex = Regex(
        pattern = "(?<!\\d)\\d{4,8}(?!\\d)",
    )
    private val alphaNumericCodeRegex = Regex(
        pattern = "\\b[a-z0-9]{4,8}\\b",
        option = RegexOption.IGNORE_CASE,
    )
    private val urlRegex = Regex(
        pattern = "(https?://|www\\.|\\b[a-z0-9][a-z0-9.-]+\\.(com|cn|net|org|io|app|dev|me)\\b)",
        option = RegexOption.IGNORE_CASE,
    )

    private val highConfidenceNoisePhrases = listOf(
        "内容推荐",
        "营销通知",
        "猜你喜欢",
        "为你推荐",
        "限时立省",
        "低至",
        "大放送",
        "领券",
        "福利已送达",
        "点击领取",
        "点击查看",
        "狂欢开启",
        "超值爆款",
    )
    private val marketingKeywords = listOf("优惠", "红包", "福利", "秒杀", "促销", "会员", "抽奖", "领券", "特惠", "上新", "直播", "额度", "借呗")
    private val financeMarketingKeywords = listOf("储蓄", "理财", "收益", "利率", "年化", "领取", "保证领取", "基金", "保险", "贷款")
    private val systemNoiseKeywords = listOf("正在运行", "正在播放", "下载中", "上传中", "同步中", "剩余", "电量", "vpn")

    private val knownImPackages = listOf(
        "com.tencent.mm",
        "com.tencent.mobileqq",
        "com.tencent.tim",
        "org.telegram.messenger",
        "org.telegram.messenger.web",
        "org.thunderdog.challegram",
        "com.alibaba.android.rimet",
        "com.tencent.wework",
        "com.ss.android.lark",
    )
    private val lowValueContentPackages = listOf(
        "com.taobao.taobao",
        "com.jingdong.app.mall",
        "com.xunmeng.pinduoduo",
        "com.xingin.xhs",
        "tv.danmaku.bili",
        "com.netease.cloudmusic",
        "com.huawei.appmarket",
        "com.huawei.android.hwouc",
        "com.eg.android.alipaygphone",
    )
    private val lowValueFeedPackages = listOf(
        "com.xingin.xhs",
        "tv.danmaku.bili",
        "com.netease.cloudmusic",
        "com.huawei.appmarket",
        "com.huawei.android.hwouc",
    )
    private val commerceNoisePackages = listOf(
        "com.taobao.taobao",
        "com.jingdong.app.mall",
        "com.xunmeng.pinduoduo",
        "com.eg.android.alipaygphone",
    )
}
