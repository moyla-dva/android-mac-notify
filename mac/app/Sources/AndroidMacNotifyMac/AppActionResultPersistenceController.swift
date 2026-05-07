import Foundation

enum AppActionResultLoadOutcome: Equatable {
    case loaded([String: ActionResult])
    case failed(String)
}

actor AppActionResultPersistenceController {
    private let store: ActionResultStore

    init(store: ActionResultStore = ActionResultStore()) {
        self.store = store
    }

    func loadResultsById() async -> AppActionResultLoadOutcome {
        do {
            let results = try await store.load()
            return .loaded(Dictionary(uniqueKeysWithValues: results.map { ($0.actionId, $0) }))
        } catch {
            return .failed("动作结果读取失败: \(error.localizedDescription)")
        }
    }

    func save(_ resultsById: [String: ActionResult]) async -> String? {
        do {
            try await store.save(Array(resultsById.values))
            return nil
        } catch {
            return "动作结果保存失败: \(error.localizedDescription)"
        }
    }

    func clear() async -> String? {
        do {
            try await store.clear()
            return nil
        } catch {
            return "动作结果清理失败: \(error.localizedDescription)"
        }
    }
}
