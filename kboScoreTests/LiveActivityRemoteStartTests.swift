import ActivityKit
import Foundation
import Testing
@testable import kboScore

@MainActor
struct LiveActivityRemoteStartTests {
    @Test func successfulRegistrationDeduplicatesButPreferenceReversalReRegisters() async {
        let recorder = StartRegistrationRecorder()
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        await registrar.register(payload(autoStart: true), reason: "test")
        await registrar.register(payload(autoStart: true), reason: "test")
        await registrar.register(payload(autoStart: false), reason: "test")
        await registrar.register(payload(autoStart: true), reason: "test")
        #expect(await recorder.requests.map(\.liveActivityAutoStartEnabled) == [true, false, true])
    }

    @Test func failedRegistrationCanBeRetriedWithSameToken() async {
        let recorder = StartRegistrationRecorder(outcomes: [.unauthorized, .synced])
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        await registrar.register(payload(), reason: "first")
        await registrar.register(payload(), reason: "retry")
        #expect(await recorder.requests.count == 2)
    }

    @Test func skippedRegistrationIsNotCachedAsSuccess() async {
        let recorder = StartRegistrationRecorder(outcomes: [.skipped, .synced])
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        await registrar.register(payload(), reason: "first")
        await registrar.register(payload(), reason: "retry")
        #expect(await recorder.requests.count == 2)
    }

    @Test func authorizationChangeUpdatesServerWithoutTokenRotation() async {
        let recorder = StartRegistrationRecorder()
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        await registrar.register(payload(authorized: false), reason: "launch")
        await registrar.register(payload(authorized: true), reason: "authorized")
        #expect(await recorder.requests.map(\.notificationsAuthorized) == [false, true])
    }

    @Test func rotatedTokensWithSamePrefixAreDistinct() async {
        let recorder = StartRegistrationRecorder()
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        let first = payload(token: "12345678-first")
        let second = payload(token: "12345678-second")
        await registrar.register(first, reason: "first")
        await registrar.register(second, reason: "rotation")
        #expect(await recorder.requests.count == 2)
        #expect(LiveActivityPushToStartTokenRegistrationKey(payload: first, endpointDescription: nil) != LiveActivityPushToStartTokenRegistrationKey(payload: second, endpointDescription: nil))
    }

    @Test func temporaryNetworkFailureRetriesAutomatically() async {
        let recorder = StartRegistrationRecorder(outcomes: [.timeout, .synced])
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        await registrar.register(payload(), reason: "test")
        #expect(await recorder.requests.count == 2)
    }

    @Test func settingsChangedDuringRequestAreSentAfterCurrentRequest() async {
        let recorder = StartRegistrationRecorder(blockFirst: true)
        let registrar = LiveActivityPushToStartTokenRegistrar(client: RecordingStartClient(recorder: recorder))
        let first = Task { await registrar.register(payload(autoStart: true), reason: "first") }
        await recorder.waitForFirstRequest()
        let second = Task { await registrar.register(payload(autoStart: false), reason: "settingsChanged") }
        await Task.yield()
        await recorder.releaseFirstRequest()
        await first.value
        await second.value
        #expect(await recorder.requests.map(\.liveActivityAutoStartEnabled) == [true, false])
        #expect(await recorder.maximumConcurrentRequests == 1)
    }

    @Test func remoteActivityRegistersDatabaseIdentityWithoutFetchingGame() throws {
        let attributes = FavoriteTeamGameActivityAttributes(
            gameID: "00000000-0000-0000-0000-000000000123",
            favoriteTeamID: "lotte", favoriteTeamName: "롯데 자이언츠", favoriteTeamShortName: "롯데",
            opponentTeamID: "doosan", opponentTeamName: "두산 베어스", opponentTeamShortName: "두산",
            venue: "사직", isHomeGame: true
        )
        let result = try #require(LiveActivityTokenRegistrationPayload(activityId: "remote-activity", activityToken: "update-token", attributes: attributes))
        #expect(result.databaseID == attributes.gameID)
        #expect(result.stableDetailIdentity == "database:" + attributes.gameID)
        #expect(result.favoriteTeamID == "lotte")
        #expect(result.publicGameID == nil)
        #expect(result.providerGameID == nil)
        #expect(result.activityId == "remote-activity")
    }

    @Test func updateTokenRotationDoesNotDeduplicateOnPrefix() {
        let first = LiveActivityTokenRegistrationPayload(activityId: "activity", activityToken: "12345678-first", favoriteTeamID: "lotte", publicGameID: nil, providerGameID: nil, databaseID: "game", stableDetailIdentity: "database:game")
        let second = LiveActivityTokenRegistrationPayload(activityId: "activity", activityToken: "12345678-second", favoriteTeamID: "lotte", publicGameID: nil, providerGameID: nil, databaseID: "game", stableDetailIdentity: "database:game")
        #expect(LiveActivityTokenRegistrationKey(payload: first, endpointDescription: nil) != LiveActivityTokenRegistrationKey(payload: second, endpointDescription: nil))
        #expect(!LiveActivityTokenRegistrationKey(payload: second, endpointDescription: nil).description.contains("12345678"))
    }

    private func payload(token: String = "start-token", autoStart: Bool = true, authorized: Bool = true) -> LiveActivityPushToStartTokenRegistrationPayload {
        LiveActivityPushToStartTokenRegistrationPayload(pushToStartToken: token, installationId: "test-installation", favoriteTeamID: "lotte", notificationsAuthorized: authorized, liveActivitiesEnabled: true, liveActivityAutoStartEnabled: autoStart, gameStartEnabled: true, favoriteTeamOnlyEnabled: true)
    }
}

private struct RecordingStartClient: LiveActivityPushToStartTokenRegistrationClient {
    let recorder: StartRegistrationRecorder
    nonisolated var debugEndpointDescription: String? { "https://example.invalid/devices/live-activities/push-to-start/register" }
    nonisolated func register(_ payload: LiveActivityPushToStartTokenRegistrationPayload) async throws -> LiveActivityTokenRegistrationStatus {
        try await recorder.record(payload)
    }
}

private actor StartRegistrationRecorder {
    enum Outcome: Sendable { case synced, skipped, unauthorized, timeout }
    private(set) var requests: [LiveActivityPushToStartTokenRegistrationPayload] = []
    private(set) var maximumConcurrentRequests = 0
    private var activeRequests = 0
    private var outcomes: [Outcome]
    private var blockFirst: Bool
    private var firstStarted: CheckedContinuation<Void, Never>?
    private var releaseFirst: CheckedContinuation<Void, Never>?

    init(outcomes: [Outcome] = [], blockFirst: Bool = false) {
        self.outcomes = outcomes
        self.blockFirst = blockFirst
    }

    func record(_ payload: LiveActivityPushToStartTokenRegistrationPayload) async throws -> LiveActivityTokenRegistrationStatus {
        requests.append(payload)
        activeRequests += 1
        maximumConcurrentRequests = max(maximumConcurrentRequests, activeRequests)
        defer { activeRequests -= 1 }
        if requests.count == 1 && blockFirst {
            await withCheckedContinuation { continuation in
                releaseFirst = continuation
                firstStarted?.resume()
                firstStarted = nil
            }
        }
        let outcome = outcomes.isEmpty ? .synced : outcomes.removeFirst()
        switch outcome {
        case .synced: return .synced
        case .skipped: return .skipped
        case .unauthorized: throw RemoteNotificationRegistrationClientError.unexpectedStatusCode(401)
        case .timeout: throw URLError(.timedOut)
        }
    }

    func waitForFirstRequest() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { firstStarted = $0 }
    }

    func releaseFirstRequest() { releaseFirst?.resume(); releaseFirst = nil }
}
