import Testing
@testable import AndroidMacNotifyMac

struct StatusCardClassifierTests {
    @Test
    func testTaobaoFlashOrderSentOutMapsToInProgress() {
        let card = StatusCardClassifier.cardState(
            from: NotificationPayload(
                appPackage: "com.taobao.taobao",
                appName: "淘宝",
                title: "淘宝闪购订单通知",
                text: "你的馍二爷肉夹馍●凉皮(塘朗店)订单已经送出，点击查看详情>>",
                notificationKey: "delivery-test"
            ),
            sourceEventId: "delivery-sent-out",
            updatedAt: 1
        )

        #expect(card?.stage == .inProgress)
        #expect(card?.title == "配送中")
    }

    @Test
    func testTaobaoFlashOrderMerchantAcceptedMapsToPreparing() {
        let card = StatusCardClassifier.cardState(
            from: NotificationPayload(
                appPackage: "com.taobao.taobao",
                appName: "淘宝",
                title: "淘宝闪购订单通知",
                text: "你的馍二爷肉夹馍●凉皮(塘朗店)订单商家已接单，点击查看详情>>",
                notificationKey: "delivery-test"
            ),
            sourceEventId: "delivery-preparing",
            updatedAt: 1
        )

        #expect(card?.stage == .preparing)
        #expect(card?.title == "备餐中")
    }
}
