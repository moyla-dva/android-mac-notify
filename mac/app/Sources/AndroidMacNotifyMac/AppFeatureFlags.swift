import Foundation

enum AppFeatureFlags {
    // Status cards are intentionally frozen while notification routing is being rethought.
    // Keep the provider code available for future explicit event sources, but do not route
    // Android notification events into cards by default.
    static let statusCardRoutingEnabled = false
}
