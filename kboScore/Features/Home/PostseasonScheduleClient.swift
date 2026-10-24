import Foundation
import Observation

struct PostseasonScheduleClient: Sendable {
    nonisolated func fetch(season: Int) async throws -> [PostseasonRound: [GameDetail]] {
        try await withThrowingTaskGroup(of: (PostseasonRound, [GameDetail]).self) { group in
            for round in PostseasonRound.allCases {
                group.addTask {
                    var request = URLRequest(url: URL(string: "https://www.koreabaseball.com/ws/Schedule.asmx/GetScheduleList")!)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 20
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("https://www.koreabaseball.com/Schedule/Schedule.aspx", forHTTPHeaderField: "Referer")
                    request.httpBody = Data("leId=1&srIdList=\(round.seriesID)&seasonId=\(season)&gameMonth=&teamId=".utf8)
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
                          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["rows"] is [Any] else {
                        throw URLError(.badServerResponse)
                    }
                    let payload = try KBOExternalResponseAdapter.normalize(data: data)
                    let teams = payload.teams.map(KBODataMapper.mapTeam)
                    let games = KBODataMapper.mapGames(payload.games, teams: teams)
                    return (round, games)
                }
            }
            var result: [PostseasonRound: [GameDetail]] = [:]
            for try await (round, games) in group { result[round] = games }
            return result
        }
    }
}

@MainActor @Observable
final class HomePostseasonModel {
    private(set) var schedules: [PostseasonRound: [GameDetail]] = [:]
    private(set) var season: Int?
    private(set) var errorMessage: String?
    private var loadID: UUID?
    private var lastLoaded: Date?

    func refresh(now: Date = Date(), force: Bool = false, scheduleDate: Date? = nil) async {
        let displayedDate = scheduleDate ?? now
        let year = PostseasonBracket.calendar.component(.year, from: displayedDate)
        guard loadID == nil || scheduleDate != nil else { return }
        if season != year { loadID = nil; schedules = [:]; season = year; lastLoaded = nil; errorMessage = nil }
        // Official postseason fixtures can be published before the regular season ends.
        guard PostseasonBracket.calendar.component(.month, from: displayedDate) >= 8 else { return }
        let refreshInterval: TimeInterval = schedules.values.allSatisfy(\.isEmpty) ? 15 * 60 : 60
        guard force || (lastLoaded.map({ now.timeIntervalSince($0) >= refreshInterval }) ?? true) else { return }
        let requestID = UUID()
        loadID = requestID
        defer { if loadID == requestID { loadID = nil } }
        do {
            let fetched = try await PostseasonScheduleClient().fetch(season: year)
            try Task.checkCancellation()
            guard loadID == requestID else { return }
            schedules = fetched
            lastLoaded = now
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, loadID == requestID else { return }
            errorMessage = "포스트시즌 일정을 새로 불러오지 못했습니다. 아래로 당겨 다시 시도해 주세요."
        }
    }

    func bracket(standings: [TeamStandingsSnapshot], liveGames: [GameDetail], now: Date = Date()) -> PostseasonBracket? {
        guard let season else { return nil }
        let bracket = PostseasonBracket.make(season: season, schedules: schedules, standings: standings, liveGames: liveGames)
        return bracket.isVisible(at: now) ? bracket : nil
    }
}
