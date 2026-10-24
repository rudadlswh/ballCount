import Foundation
import Testing
@testable import kboScore

@MainActor
struct ScheduleGameBadgeTests {
    @Test func officialPostseasonFixturesOverrideMissingOrRegularClassification() throws {
        let bundle = Bundle(for: FixtureBundle.self)
        let name = "2026-kbo-official-schedule-postseason-202610"
        let url = try #require(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json"))
        let payload = try KBOExternalResponseAdapter.normalize(data: Data(contentsOf: url))
        let officialGames = KBODataMapper.mapGames(payload.games, teams: payload.teams.map(KBODataMapper.mapTeam))
        let aliases = Set(officialGames.flatMap(\.gameIdentityAliases))

        for classification in [GameSeasonClassification.unknown, .regularSeason] {
            for filter in [ScheduleFilter.all, .myTeam] {
                for day in [14, 15] {
                    let stored = game(day: day, classification: classification)
                    #expect(label(stored, filter: filter, aliases: aliases) == "포스트시즌")
                }
                #expect(label(game(day: 12, classification: .regularSeason), filter: filter, aliases: aliases) == (filter == .all ? "리그" : "원정"))
                #expect(label(game(day: 17, classification: .regularSeason), filter: filter, aliases: aliases) == (filter == .all ? "리그" : "원정"))
            }
        }
    }

    @Test func explicitSeasonAndHomeAwayLabelsWorkWithoutOfficialFixtures() {
        #expect(label(game(classification: .postseason)) == "포스트시즌")
        #expect(label(game(classification: .exhibitionPreseason)) == "시범경기")
        #expect(label(game(classification: .regularSeason)) == "리그")
        #expect(label(game(classification: .regularSeason), filter: .myTeam) == "원정")
        #expect(SchedulePresentation.gameBadgeLabel(for: game(classification: .regularSeason), filter: .myTeam, favoriteTeamID: "lg", postseasonGameAliases: []) == "홈")
    }

    private func label(_ game: GameDetail, filter: ScheduleFilter = .all, aliases: Set<String> = []) -> String {
        SchedulePresentation.gameBadgeLabel(for: game, filter: filter, favoriteTeamID: "doosan", postseasonGameAliases: aliases)
    }

    private func game(day: Int = 14, classification: GameSeasonClassification) -> GameDetail {
        GameDetail(
            id: UUID(),
            scheduledStart: ISO8601DateFormatter().date(from: "2026-10-\(day)T18:30:00+09:00")!,
            venue: "잠실",
            awayTeam: Team(id: "doosan", name: "두산", shortName: "두산", englishName: "Doosan", markText: "D"),
            homeTeam: Team(id: "lg", name: "LG", shortName: "LG", englishName: "LG", markText: "L"),
            awayScore: 1, homeScore: 4, status: .final,
            seasonClassification: classification,
            inningText: "9회 초", bases: nil, balls: nil, strikes: nil, outs: nil,
            highlightText: nil, events: [], note: nil,
            providerGameID: "202610\(day)OBLG0",
            awayStartingPitcherName: nil, homeStartingPitcherName: nil
        )
    }
}

private final class FixtureBundle {}
