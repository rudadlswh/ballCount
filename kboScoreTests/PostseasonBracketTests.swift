import Foundation
import Testing
@testable import kboScore

@MainActor
struct PostseasonBracketTests {
    @Test func seedsAppearInAscendingBracketWithoutInventingWinners() {
        let bracket = make([.wildCard: [game(status: .upcoming)]])
        #expect(bracket.series.map { $0.seededTeam?.id } == ["lg", "kia", "samsung", "kt"])
        #expect(bracket.series[0].challenger?.id == "doosan")
        #expect(bracket.series[1].challenger == nil)
        #expect(bracket.currentSeries.round == .wildCard)
    }

    @Test func fourthPlaceAdvancesOnOneWinOrDraw() {
        for score in [2, 3] {
            let bracket = make([.wildCard: [game(awayScore: 2, homeScore: score)]])
            #expect(bracket.series[0].winner?.id == "lg")
            #expect(bracket.series[1].challenger?.id == "lg")
            #expect(bracket.currentSeries.round == .semiPlayoff)
        }
    }

    @Test func fifthPlaceNeedsTwoWinsAndDuplicateResultsDoNotCount() {
        let first = game(awayScore: 4, homeScore: 1, providerID: "wc1")
        #expect(make([.wildCard: [first, first]]).series[0].winner == nil)
        let second = game(awayScore: 4, homeScore: 1, date: "2026-10-15T18:30:00+09:00", providerID: "wc2")
        #expect(make([.wildCard: [first, second]]).series[1].challenger?.id == "doosan")
    }

    @Test func ignoresUnfinishedCancelledIncompleteAndOtherSeasonResults() {
        for value in [game(status: .live), game(status: .cancelled), game(status: .upcoming), game(homeScore: nil), game(date: "2025-10-14T18:30:00+09:00")] {
            #expect(make([.wildCard: [value]]).series[0].winner == nil)
        }
    }

    @Test func nextRoundScheduleConfirmsWinnerWhenEarlierResultsAreMissing() {
        let bracket = make([
            .wildCard: [game(status: .upcoming)],
            .semiPlayoff: [game(away: "lg", home: "kia", status: .upcoming)]
        ])
        #expect(bracket.series[0].winner?.id == "lg")
        #expect(bracket.series[1].challenger?.id == "lg")
    }

    @Test func bestOfFiveRequiresThreeWinsAndDrawDoesNotCount() {
        let wins = (1...3).map { game(away: "lg", home: "kia", awayScore: 4, homeScore: 1, providerID: "semi\($0)") }
        #expect(make([.semiPlayoff: Array(wins.prefix(2))]).series[1].winner == nil)
        let draw = game(away: "lg", home: "kia", awayScore: 2, homeScore: 2)
        #expect(make([.semiPlayoff: Array(wins.prefix(2)) + [draw]]).series[1].winner == nil)
        #expect(make([.semiPlayoff: wins]).series[2].challenger?.id == "lg")
    }

    @Test func koreanSeriesRequiresFourWinsAndCardHidesTheFollowingDay() {
        let wins = (1...4).map { game(away: "samsung", home: "kt", awayScore: 1, homeScore: 4, date: "2026-10-30T18:30:00+09:00", providerID: "ks\($0)") }
        #expect(make([.koreanSeries: Array(wins.prefix(3))]).champion == nil)
        let bracket = make([.koreanSeries: wins])
        #expect(bracket.champion?.id == "kt")
        #expect(bracket.isVisible(at: date("2026-10-30T23:59:00+09:00")))
        #expect(!bracket.isVisible(at: date("2026-10-31T00:00:00+09:00")))
    }

    @Test func cardOnlyAppearsFromOneWeekBeforeFirstGameInCurrentSeason() {
        let bracket = make([.wildCard: [game(status: .upcoming)]])
        #expect(!bracket.isVisible(at: date("2026-10-06T23:59:00+09:00")))
        #expect(bracket.isVisible(at: date("2026-10-07T00:00:00+09:00")))
        #expect(!bracket.isVisible(at: date("2027-10-14T00:00:00+09:00")))
        #expect(!make([:]).isVisible(at: date("2026-10-14T00:00:00+09:00")))
    }

    @Test func finalLiveUpdateAdvancesWinnerButCannotOverwriteOfficialFinal() {
        let scheduled = game(status: .upcoming, providerID: "wc1")
        let final = game(awayScore: 1, homeScore: 4, providerID: "wc1")
        #expect(make([.wildCard: [scheduled]], live: [final]).series[1].challenger?.id == "lg")
        #expect(make([.wildCard: [final]], live: [scheduled]).series[1].challenger?.id == "lg")
    }

    @Test func officialPostseasonFixtureMapsActualParticipants() throws {
        let payload = try KBOExternalResponseAdapter.normalize(data: fixtureData())
        let games = KBODataMapper.mapGames(payload.games, teams: payload.teams.map(KBODataMapper.mapTeam))
        #expect(games.count == 2)
        #expect(make([.wildCard: games]).series[0].challenger?.id == "doosan")
        #expect(PostseasonRound.allCases.map(\.seriesID) == ["4", "3", "5", "7"])
    }

    @Test func officialDrawOnlyAdvancesFourthPlaceAfterReviewConfirmsFinal() throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var rows = try #require(object["rows"] as? [[String: Any]])
        var cells = try #require(rows[0]["row"] as? [[String: Any]])
        cells[2]["Text"] = "<span>두산</span><em><span class=\"same\">3</span><span>vs</span><span class=\"same\">3</span></em><span>LG</span>"
        for final in [false, true] {
            if final {
                cells[3]["Text"] = (cells[3]["Text"] as? String)?.replacingOccurrences(of: "START_PIT", with: "REVIEW")
            }
            rows[0]["row"] = cells
            object["rows"] = rows
            let payload = try KBOExternalResponseAdapter.normalize(data: JSONSerialization.data(withJSONObject: object))
            let games = KBODataMapper.mapGames(payload.games, teams: payload.teams.map(KBODataMapper.mapTeam))
            let scored = try #require(games.first { $0.awayScore == 3 })
            #expect(scored.homeScore == 3)
            #expect(scored.status == (final ? .final : .live))
            #expect(make([.wildCard: games]).series[0].winner?.id == (final ? "lg" : nil))
        }
    }

    @Test func officialRainCancellationOverridesPreviewAndScores() throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        let rows = try #require(object["rows"] as? [[String: Any]])
        var cells = try #require(rows[0]["row"] as? [[String: Any]])
        cells[0]["Text"] = "10.25(일)"
        cells[1]["Text"] = "<b>14:00</b>"
        cells[3]["Text"] = "<a href='/Schedule/GameCenter/Main.aspx?gameDate=20261025&gameId=20261025HTSS0&section=START_PIT'>프리뷰</a>"
        cells[7]["Text"] = "대구"
        cells[8]["Text"] = "<span>우천취소</span>"
        for scoreHTML in ["<span>vs</span>", "<span>0</span><span>vs</span><span>0</span>"] {
            cells[2]["Text"] = "<span>KIA</span><em>\(scoreHTML)</em><span>삼성</span>"
            object["rows"] = [["row": cells]]
            let payload = try KBOExternalResponseAdapter.normalize(data: JSONSerialization.data(withJSONObject: object))
            let dto = try #require(payload.games.first)
            #expect(dto.statusCode == "CANCELLED")
            #expect(dto.statusText == "우천취소")
            let games = KBODataMapper.mapGames(payload.games, teams: payload.teams.map(KBODataMapper.mapTeam))
            let cancelled = try #require(games.first)
            #expect(cancelled.providerGameID == "20261025HTSS0")
            #expect(cancelled.awayTeam.id == "kia")
            #expect(cancelled.homeTeam.id == "samsung")
            #expect(cancelled.status == .cancelled)
            let stale = game(away: "kia", home: "samsung", status: .upcoming, providerID: "20261025HTSS0")
            #expect(make([.playoff: games], live: [stale]).series[2].games.first?.status == .cancelled)
        }
    }

    @Test func regularScheduleFinalResultsRemainFinal() throws {
        let payload = try KBOExternalResponseAdapter.normalize(data: fixtureData(named: "2026-kbo-official-schedule-list-202603"))
        #expect(payload.games.filter { $0.statusCode == "FINAL" }.count == 4)
    }

    private func fixtureData(named name: String = "2026-kbo-official-schedule-postseason-202610") throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func make(_ schedules: [PostseasonRound: [GameDetail]], live: [GameDetail] = []) -> PostseasonBracket {
        let standings = ["kt", "samsung", "kia", "lg", "doosan"].enumerated().map {
            TeamStandingsSnapshot(team: team($0.element), rank: $0.offset + 1, wins: 80, losses: 60, ties: 4, remainingRegularSeasonGames: 0, recentResults: [])
        }
        return .make(season: 2026, schedules: schedules, standings: standings, liveGames: live)
    }

    private func team(_ id: String) -> Team { Team(id: id, name: id, shortName: id, englishName: id, markText: id) }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func game(away: String = "doosan", home: String = "lg", awayScore: Int? = 1, homeScore: Int? = 4, status: GameStatus = .final, date: String = "2026-10-14T18:30:00+09:00", providerID: String? = nil) -> GameDetail {
        GameDetail(id: UUID(), scheduledStart: self.date(date), venue: "잠실", awayTeam: team(away), homeTeam: team(home), awayScore: awayScore, homeScore: homeScore, status: status, seasonClassification: .postseason, inningText: nil, bases: nil, balls: nil, strikes: nil, outs: nil, highlightText: nil, events: [], note: nil, providerGameID: providerID, awayStartingPitcherName: nil, homeStartingPitcherName: nil)
    }
}

private final class BundleToken {}
