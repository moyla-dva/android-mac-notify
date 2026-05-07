import Testing
@testable import AndroidMacNotifyMac

struct AppStatusCardProjectionTests {
    @Test
    func testNewerLowerProgressKeepsCurrentForwardStage() {
        let currentCard = statusCard(
            id: "delivery-1",
            sourceEventId: "event-1",
            title: "配送中",
            detail: "骑手正在配送",
            stage: .inProgress,
            etaText: "约 8 分钟",
            updatedAt: 100
        )
        let incomingCard = statusCard(
            id: "delivery-1",
            sourceEventId: "event-2",
            title: "备餐中",
            detail: "商家正在出餐",
            stage: .preparing,
            etaText: nil,
            updatedAt: 200
        )

        let projection = AppStatusCardProjector.project(
            incomingCard: incomingCard,
            currentCard: currentCard,
            recentCards: [],
            maxHistoryCount: 20
        )

        #expect(projection.statusCard.title == "配送中")
        #expect(projection.statusCard.detail == "商家正在出餐")
        #expect(projection.statusCard.stage == .inProgress)
        #expect(projection.statusCard.etaText == "约 8 分钟")
        #expect(projection.statusCard.updatedAt == 200)
    }

    @Test
    func testTerminalCurrentCardCanBeReplacedByIncomingCard() {
        let currentCard = statusCard(id: "delivery-1", title: "已送达", stage: .completed, updatedAt: 100)
        let incomingCard = statusCard(id: "delivery-1", title: "备餐中", stage: .preparing, updatedAt: 200)

        let mergedCard = AppStatusCardProjector.mergedStatusCard(incomingCard, currentCard: currentCard)

        #expect(mergedCard == incomingCard)
    }

    @Test
    func testRememberedStatusCardsDeduplicatesAndCapsHistory() {
        let oldCard = statusCard(id: "old", sourceEventId: "old-event", updatedAt: 1)
        let duplicateCard = statusCard(id: "delivery-1", sourceEventId: "event-1", updatedAt: 2)
        let incomingCard = statusCard(id: "delivery-1", sourceEventId: "event-1", updatedAt: 2)

        let cards = AppStatusCardProjector.rememberedStatusCards(
            adding: incomingCard,
            to: [duplicateCard, oldCard],
            maxHistoryCount: 1
        )

        #expect(cards == [incomingCard])
    }

    private func statusCard(
        id: String,
        sourceEventId: String = "event",
        title: String = "状态",
        detail: String = "状态详情",
        stage: StatusCardStage = .preparing,
        etaText: String? = nil,
        updatedAt: Int64
    ) -> StatusCardState {
        StatusCardState(
            id: id,
            category: .delivery,
            sourceEventId: sourceEventId,
            appName: "淘宝",
            title: title,
            detail: detail,
            stage: stage,
            etaText: etaText,
            updatedAt: updatedAt
        )
    }
}
