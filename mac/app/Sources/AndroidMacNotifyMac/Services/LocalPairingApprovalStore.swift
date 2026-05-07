import Foundation

struct LocalPairingApprovalStore: Sendable {
    struct Record: Sendable {
        var request: PairingApprovalRequest
        var registration: PairRegisterResponse?
    }

    private var recordsById: [String: Record] = [:]

    mutating func removeAll() {
        recordsById.removeAll()
    }

    func record(for requestId: String) -> Record? {
        recordsById[requestId]
    }

    func pendingRecord(forDeviceId deviceId: String) -> Record? {
        recordsById.values.first { record in
            record.request.device.deviceId == deviceId && record.request.status == .pending
        }
    }

    func pendingRecord(forRequestId requestId: String) -> Record? {
        guard let record = recordsById[requestId], record.request.status == .pending else {
            return nil
        }
        return record
    }

    mutating func createPending(
        requestId: String,
        device: DeviceIdentity,
        requestedAt: Int64,
        expiresAt: Int64
    ) -> PairingApprovalRequest {
        let request = PairingApprovalRequest(
            requestId: requestId,
            device: device,
            requestedAt: requestedAt,
            expiresAt: expiresAt,
            status: .pending
        )
        recordsById[requestId] = Record(request: request, registration: nil)
        return request
    }

    mutating func approve(requestId: String, registration: PairRegisterResponse) -> Record? {
        guard var record = pendingRecord(forRequestId: requestId) else {
            return nil
        }

        record.request.status = .approved
        record.registration = registration
        recordsById[requestId] = record
        return record
    }

    mutating func reject(requestId: String) -> Record? {
        guard var record = pendingRecord(forRequestId: requestId) else {
            return nil
        }

        record.request.status = .rejected
        recordsById[requestId] = record
        return record
    }

    mutating func prune(at timestamp: Int64, retainedTerminalRecordMillis: Int64) -> [PairingApprovalRequest] {
        var expiredRequests: [PairingApprovalRequest] = []

        for (requestId, record) in recordsById {
            guard record.request.status == .pending, record.request.expiresAt <= timestamp else {
                continue
            }

            var expired = record
            expired.request.status = .expired
            recordsById[requestId] = expired
            expiredRequests.append(expired.request)
        }

        recordsById = recordsById.filter { _, record in
            switch record.request.status {
            case .pending:
                return true
            case .approved, .rejected, .expired:
                return timestamp - record.request.expiresAt <= retainedTerminalRecordMillis
            }
        }

        return expiredRequests
    }

    static func message(for status: PairApprovalStatus) -> String? {
        switch status {
        case .pending:
            return "Waiting for approval on Mac."
        case .approved:
            return "Pairing request was approved."
        case .rejected:
            return "Pairing request was rejected on Mac."
        case .expired:
            return "Pairing request expired."
        }
    }
}
