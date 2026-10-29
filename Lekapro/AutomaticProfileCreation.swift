import Foundation
import Combine
import UIKit

struct AutomaticProfileResult: Identifiable {
    enum State: Equatable { case queued, running, approved, exhausted, failed, cancelled }
    let id = UUID()
    let position: Int
    var state: State = .queued
    var attempts = 0
    var profileID: UUID?
    var message = "Đang chờ"
}

enum AutomaticReviewOutcome: Equatable { case approved, duplicateDeleted, failed }

@MainActor
final class AutomaticProfileCreator: ObservableObject {
    typealias ReviewRunner = (UUID, ProfileStore, BrowserWorkspace, FingerprintReviewController) async -> AutomaticReviewOutcome
    // A single sequential creator across both entry points. No unbounded loop.
    private static var activeOwner: UUID?
    static let presets: [UserAgentPreset] = [.ios172, .crios174, .fxios175]
    @Published private(set) var results: [AutomaticProfileResult] = []
    @Published private(set) var busy = false
    @Published private(set) var finished = false
    @Published private(set) var status = ""
    @Published private(set) var review: FingerprintReviewController?
    private let runner: ReviewRunner?
    private var cancelled = false
    private var task: Task<Void, Never>?
    var approvedCount: Int { results.filter { $0.state == .approved }.count }
    @Published private(set) var duplicateCount = 0
    #if DEBUG
    private(set) var diagnosticEvents: [[String: String]] = []
    #endif

    init(runner: ReviewRunner? = nil) { self.runner = runner }

    func start(inputs: [PastedProxy], store: ProfileStore, workspace: BrowserWorkspace, cookieSeed: CookieSeedConfiguration? = nil) {
        guard !busy else { return }
        task = Task { await run(inputs: inputs, store: store, workspace: workspace, cookieSeed: cookieSeed) }
    }
    func cancel() {
        cancelled = true; status = "Đang dừng…"
        task?.cancel(); review?.close()
    }

    func run(inputs: [PastedProxy], store: ProfileStore, workspace: BrowserWorkspace, cookieSeed: CookieSeedConfiguration? = nil) async {
        guard !busy else { return }
        guard Self.activeOwner == nil else { status = "Đợt tạo trước vẫn đang hoàn tất. Hãy thử lại sau."; return }
        guard !inputs.isEmpty, inputs.count <= 20, !store.isReadOnly else { status = "Chưa thể bắt đầu tạo hồ sơ."; return }
        let owner = UUID(); Self.activeOwner = owner
        busy = true; finished = false; cancelled = false; duplicateCount = 0
        results = inputs.indices.map { AutomaticProfileResult(position: $0 + 1) }
        #if DEBUG
        diagnosticEvents = []
        #endif
        let idle = UIApplication.shared.isIdleTimerDisabled; UIApplication.shared.isIdleTimerDisabled = true
        defer {
            review?.close(); review = nil; busy = false; finished = true; task = nil
            if Self.activeOwner == owner { Self.activeOwner = nil }
            UIApplication.shared.isIdleTimerDisabled = idle
        }
        for index in inputs.indices {
            if cancelled || Task.isCancelled { markCancelled(from: index); break }
            results[index].state = .running
            do {
                let proxy = try store.proxyForQuickCreation(inputs[index])
                for (attempt, preset) in Self.presets.enumerated() {
                    if cancelled || Task.isCancelled { results[index].state = .cancelled; results[index].message = "Đã dừng"; break }
                    var candidate = BrowserProfile()
                    candidate.name = "Hồ sơ \(Date().formatted(date: .omitted, time: .shortened)) · \(index + 1)"
                    candidate.proxyID = proxy.id; candidate.timeZoneMode = .ip
                    candidate.userAgent = preset.value; candidate.fingerprintCheck = .newCandidate
                    try store.save(candidate)
                    results[index].attempts = attempt + 1; results[index].profileID = candidate.id
                    status = "Đang tạo hồ sơ \(index + 1)/\(inputs.count)"
                    if let cookieSeed {
                        results[index].message = "Đang chia và nạp cookie · lượt \(attempt + 1)"
                        do {
                            candidate.cookieSeed = try await cookieSeed.apply(to: candidate, proxy: proxy)
                            try store.save(candidate)
                        } catch {
                            try? store.recordFingerprintFailure(candidate.id, message: "Chưa nạp được cookie. Chưa mở website.")
                            results[index].state = cancelled || Task.isCancelled ? .cancelled : .failed
                            results[index].message = "Chưa nạp được cookie. Giữ hồ sơ chờ kiểm tra; chưa mở website."
                            break
                        }
                    }
                    results[index].message = "Lượt \(attempt + 1)/\(Self.presets.count) · \(preset.title)"
                    status = "Đang tạo hồ sơ \(index + 1)/\(inputs.count)"
                    let controller = FingerprintReviewController(); review = controller
                    let outcome: AutomaticReviewOutcome
                    if let runner { outcome = await runner(candidate.id, store, workspace, controller) }
                    else {
                        await controller.run(profileID: candidate.id, store: store, workspace: workspace)
                        outcome = controller.approved ? .approved : (controller.deleted ? .duplicateDeleted : .failed)
                    }
                    #if DEBUG
                    if let proof = controller.diagnosticProof {
                        diagnosticEvents.append(["profileID": candidate.id.uuidString,
                            "visitorID": proof.first.visitorID, "reloadVisitorID": proof.reload.visitorID,
                            "eventID": proof.first.eventID, "reloadEventID": proof.reload.eventID,
                            "exitIP": proof.first.exitIP, "environmentID": proof.first.environmentID])
                    }
                    #endif
                    review = nil
                    if outcome == .approved, store.profile(candidate.id)?.fingerprintCheck?.allowsBrowsing == true {
                        results[index].state = .approved; results[index].message = "Đã tạo · ID chưa có trong lịch sử"
                        break
                    }
                    if outcome == .duplicateDeleted, store.profile(candidate.id) == nil {
                        duplicateCount += 1; results[index].profileID = nil
                        if attempt == Self.presets.count - 1 {
                            results[index].state = .exhausted; results[index].message = "Cả \(Self.presets.count) lượt đều trùng ID · không giữ hồ sơ"
                        }
                        continue
                    }
                    // Network/parse/storage errors are not evidence of a
                    // duplicate. Keep this candidate blocked; do not keep retrying.
                    results[index].state = cancelled || Task.isCancelled ? .cancelled : .failed
                    results[index].message = "Chưa đo được ID. Giữ hồ sơ chờ kiểm tra; có thể thử lại từ danh sách."
                    break
                }
            } catch {
                results[index].state = .failed
                results[index].message = "Không lưu được proxy hoặc hồ sơ. Kiểm tra dữ liệu và thử lại."
            }
        }
        status = cancelled || Task.isCancelled ? "Đã dừng · giữ \(approvedCount) hồ sơ đạt" : "Hoàn tất · giữ \(approvedCount)/\(inputs.count) hồ sơ"
    }
    private func markCancelled(from index: Int) {
        for i in index..<results.count { results[i].state = .cancelled; results[i].message = "Chưa chạy · đã dừng" }
    }
}
