import Foundation
import Testing
@testable import kboScore

@MainActor
struct AttendanceRecoveryTests {
    @Test(arguments: [true, false], [true, false])
    func listStartedBeforeSaveCannotOverwriteConfirmedChange(mark: Bool, staleRequestFails: Bool) async throws {
        let game = makeGame()
        let client = AttendanceRecoveryClient()
        client.records = AttendanceRecords(gameIDs: mark ? [] : [game.id], games: [game])
        let model = makeModel(client: client)
        await model.refreshAttendanceRecordsFromServer()

        client.holdNextFetch = true
        client.fetchError = staleRequestFails ? .httpStatus(500) : nil
        let refresh = Task { await model.refreshAttendanceRecordsFromServer(forceRefresh: true) }
        defer { client.releaseFetch(); refresh.cancel() }
        for _ in 0..<100 {
            if client.heldFetch != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(client.heldFetch != nil)
        model.toggleGameDetailAttendance(for: game)
        try await waitForSave(model: model, game: game)
        #expect(model.isGameDetailAttended(game) == mark)

        client.fetchError = nil
        client.releaseFetch()
        await refresh.value

        #expect(model.isGameDetailAttended(game) == mark)
        #expect(model.attendanceDashboard.hasGames == mark)
        #expect(model.attendanceSyncFailureMessage == nil)
        #expect(client.fetchCount == 3)
    }

    @Test func explicitRefreshRecoversAfterListFailure() async {
        let game = makeGame()
        let client = AttendanceRecoveryClient()
        client.fetchError = .httpStatus(500)
        let model = makeModel(client: client)

        await model.refreshAttendanceRecordsFromServer()
        #expect(model.attendanceSyncFailureMessage != nil)
        client.fetchError = nil
        client.records = AttendanceRecords(gameIDs: [game.id], games: [game])
        await model.refreshAttendanceRecordsFromServer()
        #expect(client.fetchCount == 1)

        await model.refreshAttendanceRecordsFromServer(forceRefresh: true)
        #expect(client.fetchCount == 2)
        #expect(model.attendanceSyncFailureMessage == nil)
        #expect(model.attendanceDashboard.overall.games == 1)
    }

    @Test func failedSaveCanBeRetriedAndDetailAppearsWithoutScheduleCache() async throws {
        let game = makeGame()
        let client = AttendanceRecoveryClient()
        client.setError = .httpStatus(500)
        let model = makeModel(client: client)
        #expect(model.attendanceDashboard.hasGames == false)

        model.toggleGameDetailAttendance(for: game)
        #expect(model.isGameDetailAttended(game) == false)
        try await waitForSave(model: model, game: game)
        #expect(model.attendanceSyncFailureMessage != nil)
        #expect(model.attendanceDashboard.hasGames == false)

        client.setError = nil
        model.toggleGameDetailAttendance(for: game)
        #expect(model.attendanceSyncFailureMessage == nil)
        try await waitForSave(model: model, game: game)
        #expect(model.isGameDetailAttended(game))
        #expect(model.attendanceDashboard.overall.games == 1)
        #expect(model.attendanceDashboard.overall.wins == 1)

        model.toggleGameDetailAttendance(for: game)
        try await waitForSave(model: model, game: game)
        #expect(model.attendanceDashboard.hasGames == false)
    }

    @Test func successfulSaveReenablesAutomaticListSync() async throws {
        let game = makeGame()
        let client = AttendanceRecoveryClient()
        client.fetchError = .httpStatus(500)
        client.records = AttendanceRecords(gameIDs: [], games: [game])
        let model = makeModel(client: client)
        await model.refreshAttendanceRecordsFromServer()

        client.fetchError = nil
        model.toggleGameDetailAttendance(for: game)
        try await waitForSave(model: model, game: game)
        await model.refreshAttendanceRecordsFromServer()

        #expect(client.fetchCount == 2)
        #expect(model.isGameDetailAttended(game))
        #expect(model.attendanceSyncFailureMessage == nil)
        #expect(model.attendanceDashboard.overall.games == 1)
    }

    private func makeModel(client: AttendanceRecoveryClient) -> AppModel {
        var settings = AppSettings.default
        settings.favoriteTeamID = "kt"
        return AppModel(
            attendanceClient: client,
            bootstrap: KBOBootstrapData(teams: MockKBOData.makeBootstrap().teams, games: [], notifications: [], settings: settings),
            usePersistedSettings: false
        )
    }

    private func waitForSave(model: AppModel, game: GameDetail) async throws {
        for _ in 0..<100 {
            if !model.isAttendanceSyncPending(for: game) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("직관 저장이 완료되지 않았습니다.")
    }

    private func makeGame() -> GameDetail {
        func team(_ id: String) -> Team {
            Team(id: id, name: id, shortName: id, englishName: id, markText: id)
        }
        return GameDetail(
            id: UUID(), scheduledStart: ISO8601DateFormatter().date(from: "2026-09-30T18:30:00+09:00")!, venue: "광주",
            awayTeam: team("kt"), homeTeam: team("kia"), awayScore: 3, homeScore: 2,
            status: .final, seasonClassification: .regularSeason, inningText: nil, bases: nil,
            balls: nil, strikes: nil, outs: nil, highlightText: nil, events: [], note: nil,
            providerGameID: "20260930KTHT0", awayStartingPitcherName: nil, homeStartingPitcherName: nil
        )
    }
}

@MainActor
private final class AttendanceRecoveryClient: AttendanceClient {
    var fetchError: AttendanceClientError?
    var setError: AttendanceClientError?
    var records = AttendanceRecords(gameIDs: [], games: [])
    var fetchCount = 0
    var holdNextFetch = false
    var heldFetch: CheckedContinuation<Void, Never>?

    func releaseFetch() {
        heldFetch?.resume()
        heldFetch = nil
    }

    nonisolated func fetchAttendedGameIDs(installationID: UUID) async throws -> Set<UUID> {
        try await fetchAttendanceRecords(installationID: installationID).gameIDs
    }

    nonisolated func fetchAttendanceRecords(installationID: UUID) async throws -> AttendanceRecords {
        try await fetch()
    }

    private func fetch() async throws -> AttendanceRecords {
        fetchCount += 1
        let response = records
        let error = fetchError
        if holdNextFetch {
            holdNextFetch = false
            await withCheckedContinuation { heldFetch = $0 }
        }
        if let error { throw error }
        return response
    }

    nonisolated func setAttendance(_ isAttended: Bool, installationID: UUID, gameID: UUID, publicGameID: String?, providerGameID: String?) async throws {
        try await save(isAttended, gameID: gameID)
    }

    private func save(_ isAttended: Bool, gameID: UUID) throws {
        if let setError { throw setError }
        var ids = records.gameIDs
        if isAttended { ids.insert(gameID) } else { ids.remove(gameID) }
        records = AttendanceRecords(gameIDs: ids, games: records.games)
    }
}
