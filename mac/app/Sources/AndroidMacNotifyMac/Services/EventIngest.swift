import Foundation

enum EventIngest {
    static func notificationEvent(from payload: NotificationEventPayload, receivedAt: Int64) -> InboundEvent {
        let notificationPayload = NotificationPayload(
            appPackage: payload.appPackage,
            appName: payload.appName,
            title: payload.title,
            text: payload.text,
            notificationKey: payload.notificationKey
        )

        return InboundEvent(
            eventId: payload.eventId,
            kind: .notification,
            sourceDeviceId: payload.deviceId,
            occurredAt: payload.postedAt,
            receivedAt: receivedAt,
            payload: .notification(notificationPayload),
            metadata: EventMetadata(
                route: "/api/v1/events/notification",
                sourceAppPackage: payload.appPackage
            )
        )
    }
}
