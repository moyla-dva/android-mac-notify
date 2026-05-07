import Foundation

struct AppStatusCardProjection: Equatable {
    let statusCard: StatusCardState
    let recentStatusCards: [StatusCardState]
}

enum AppStatusCardProjector {
    static func project(
        incomingCard: StatusCardState,
        currentCard: StatusCardState?,
        recentCards: [StatusCardState],
        maxHistoryCount: Int
    ) -> AppStatusCardProjection {
        let nextCard = mergedStatusCard(incomingCard, currentCard: currentCard)
        return AppStatusCardProjection(
            statusCard: nextCard,
            recentStatusCards: rememberedStatusCards(
                adding: nextCard,
                to: recentCards,
                maxHistoryCount: maxHistoryCount
            )
        )
    }

    static func mergedStatusCard(
        _ incomingCard: StatusCardState,
        currentCard: StatusCardState?
    ) -> StatusCardState {
        guard let currentCard,
              currentCard.id == incomingCard.id,
              incomingCard.updatedAt >= currentCard.updatedAt,
              !currentCard.stage.isTerminal,
              incomingCard.stage.progress < currentCard.stage.progress
        else {
            return incomingCard
        }

        return StatusCardState(
            id: incomingCard.id,
            category: incomingCard.category,
            sourceEventId: incomingCard.sourceEventId,
            appName: incomingCard.appName,
            title: currentCard.title,
            detail: incomingCard.detail,
            stage: currentCard.stage,
            etaText: incomingCard.etaText ?? currentCard.etaText,
            updatedAt: incomingCard.updatedAt
        )
    }

    static func rememberedStatusCards(
        adding card: StatusCardState,
        to recentCards: [StatusCardState],
        maxHistoryCount: Int
    ) -> [StatusCardState] {
        var nextCards = recentCards
        nextCards.removeAll {
            $0.sourceEventId == card.sourceEventId && $0.updatedAt == card.updatedAt
        }
        nextCards.insert(card, at: 0)
        return Array(nextCards.prefix(maxHistoryCount))
    }
}
