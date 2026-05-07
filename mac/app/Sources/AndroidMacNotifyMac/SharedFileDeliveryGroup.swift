import Foundation

struct SharedFileDeliveryGroup: Identifiable, Equatable {
    let id: String
    let deviceId: String
    let batchId: String?
    let receivedAt: Int64
    let summaries: [LocalNotificationSummary]

    var fileCount: Int {
        summaries.count
    }

    var latestSummary: LocalNotificationSummary {
        summaries.max { $0.receivedAt < $1.receivedAt } ?? summaries[0]
    }

    static func groups(
        from summaries: [LocalNotificationSummary],
        mergeWindowMillis: Int64 = 8_000
    ) -> [SharedFileDeliveryGroup] {
        let sortedSummaries = summaries.sorted { $0.receivedAt > $1.receivedAt }
        var batchBuckets: [String: [LocalNotificationSummary]] = [:]
        var summariesWithoutBatch: [LocalNotificationSummary] = []

        for summary in sortedSummaries {
            if let batchId = summary.sharedFileBatchId {
                batchBuckets["\(summary.deviceId)|\(batchId)", default: []].append(summary)
            } else {
                summariesWithoutBatch.append(summary)
            }
        }

        let batchGroups = batchBuckets.compactMap { _, summaries -> SharedFileDeliveryGroup? in
            guard let first = summaries.first, let batchId = first.sharedFileBatchId else {
                return nil
            }
            return SharedFileDeliveryGroup(
                id: "shared_file_batch_\(first.deviceId)_\(batchId)",
                summaries: summaries,
                sortByBatchIndex: true
            )
        }

        let inferredGroups = inferredTimeWindowGroups(
            from: summariesWithoutBatch,
            mergeWindowMillis: mergeWindowMillis
        )

        return (batchGroups + inferredGroups).sorted { $0.receivedAt > $1.receivedAt }
    }

    static func visibleGroups(
        from summaries: [LocalNotificationSummary],
        activeReceiveStatus: SharedFileReceiveStatus?,
        mergeWindowMillis: Int64 = 8_000
    ) -> [SharedFileDeliveryGroup] {
        let groups = groups(from: summaries, mergeWindowMillis: mergeWindowMillis)
        guard let activeReceiveStatus,
              activeReceiveStatus.stage == .receiving,
              let activeBatchId = activeReceiveStatus.batchId
        else {
            return groups
        }
        return groups.filter { group in
            group.batchId != activeBatchId
        }
    }

    private static func inferredTimeWindowGroups(
        from summaries: [LocalNotificationSummary],
        mergeWindowMillis: Int64
    ) -> [SharedFileDeliveryGroup] {
        var groupedSummaries: [[LocalNotificationSummary]] = []

        for summary in summaries {
            if let lastGroupIndex = groupedSummaries.indices.last,
               let newestInGroup = groupedSummaries[lastGroupIndex].first,
               newestInGroup.deviceId == summary.deviceId,
               newestInGroup.receivedAt - summary.receivedAt <= mergeWindowMillis {
                groupedSummaries[lastGroupIndex].append(summary)
            } else {
                groupedSummaries.append([summary])
            }
        }

        return groupedSummaries.compactMap { SharedFileDeliveryGroup(summaries: $0) }
    }

    private init?(
        id: String? = nil,
        summaries: [LocalNotificationSummary],
        sortByBatchIndex: Bool = false
    ) {
        let sortedSummaries = summaries.sorted { lhs, rhs in
            if sortByBatchIndex,
               let lhsIndex = lhs.sharedFileBatchIndex,
               let rhsIndex = rhs.sharedFileBatchIndex,
               lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.receivedAt > rhs.receivedAt
        }
        guard let newest = sortedSummaries.max(by: { $0.receivedAt < $1.receivedAt }),
              let oldest = sortedSummaries.min(by: { $0.receivedAt < $1.receivedAt })
        else {
            return nil
        }

        self.deviceId = newest.deviceId
        self.batchId = sortedSummaries.compactMap(\.sharedFileBatchId).first
        self.receivedAt = newest.receivedAt
        self.summaries = sortedSummaries
        self.id = id ?? (sortedSummaries.count == 1
            ? newest.eventId
            : "shared_file_group_\(newest.deviceId)_\(oldest.receivedAt)_\(newest.receivedAt)_\(sortedSummaries.count)")
    }
}

extension SharedFileDeliveryGroup {
    var savedFilePaths: [String] {
        summaries.compactMap(\.sharedFileSavedPath)
    }
}

extension LocalNotificationSummary {
    var sharedFileSavedPath: String? {
        actionCandidates.first { $0.kind == .openFile }?.fileValue?.path
            ?? actionCandidates.first { $0.kind == .revealFile }?.fileValue?.path
            ?? actionCandidates.first { $0.kind == .copyFilePath }?.fileValue?.path
    }

    var isSharedFileReceipt: Bool {
        ruleDecision.reasonCodes.contains("shared_file_received")
    }
}
