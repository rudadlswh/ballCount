import Foundation
import Testing
@testable import kboScore

@MainActor
struct StandingsSeasonClassificationTests {
    @Test(arguments: ["regular_season", "postseason", "exhibition_preseason", "all_star"])
    func storedSeasonTypeControlsStandings(seasonType: String) throws {
        let game = try mappedGame(seasonFields: ["season_type": seasonType])
        #expect(game.seasonClassification == (GameSeasonClassification(rawValue: seasonType) ?? .unknown))
        let snapshot = StandingsCalculator.makeSnapshot(
            for: game.homeTeam, completedGames: [game], seasonGames: [game]
        )
        #expect(snapshot.wins == (seasonType == "regular_season" ? 1 : 0))
        #expect(snapshot.losses == 0)
        #expect(snapshot.ties == 0)
        #expect(snapshot.runsScored == (seasonType == "regular_season" ? 4 : 0))
        #expect(snapshot.runsAllowed == (seasonType == "regular_season" ? 1 : 0))
        #expect(snapshot.recentResults.count == (seasonType == "regular_season" ? 1 : 0))
    }

    @Test func unknownLegacySeasonPreservesExistingProviderClassification() throws {
        let game = try mappedGame(seasonFields: ["season_type": "unknown"])
        #expect(game.seasonClassification == .regularSeason)
    }

    @Test(arguments: [3, 4, 5, 7])
    func unknownSeasonWithPostseasonSeriesIsExcluded(seriesID: Int) throws {
        let game = try mappedGame(seasonFields: ["season_type": "unknown", "series_id": seriesID])
        #expect(game.seasonClassification == .postseason)
    }

    @Test(arguments: [0, 3, 4, 5, 7, 9, 6, 99])
    func storedSeriesControlsClassificationWhenSeasonTypeIsAbsent(seriesID: Int) throws {
        let game = try mappedGame(seasonFields: ["series_id": seriesID])
        let expected: GameSeasonClassification = switch seriesID {
        case 0: .regularSeason
        case 3, 4, 5, 7: .postseason
        case 9: .exhibitionPreseason
        default: .unknown
        }
        #expect(game.seasonClassification == expected)
    }

    #if canImport(Supabase)
    @Test func gameQueryRequestsStoredSeasonClassification() {
        let columns = SupabaseKBORepository.gameSelectColumns.split(separator: ",")
        #expect(columns.contains("season_type"))
        #expect(columns.contains("series_id"))
    }
    #endif

    private func mappedGame(seasonFields: [String: Any]) throws -> GameDetail {
        let awayID = UUID()
        let homeID = UUID()
        var payload: [String: Any] = [
            "id": UUID().uuidString,
            "public_game_id": "20261014-LG-DOO-1",
            "provider": "kbo",
            "provider_game_id": "20261014LGDO0",
            "game_date": "2026-10-14",
            "scheduled_at": "2026-10-14T18:30:00+09:00",
            "status": "final",
            "away_team_id": awayID.uuidString,
            "home_team_id": homeID.uuidString,
            "away_score": 1,
            "home_score": 4
        ]
        payload.merge(seasonFields) { _, new in new }
        let row = try JSONDecoder().decode(SupabaseGameRow.self, from: JSONSerialization.data(withJSONObject: payload))
        // Local row caches must preserve the server classification as well.
        let cachedRow = try JSONDecoder().decode(SupabaseGameRow.self, from: JSONEncoder().encode(row))
        return try #require(SupabaseKBOMapper.mapGames(gameRows: [cachedRow], teamRows: [
            SupabaseTeamRow(id: awayID, code: "lg", name: "LG 트윈스", shortName: "LG"),
            SupabaseTeamRow(id: homeID, code: "doosan", name: "두산 베어스", shortName: "두산")
        ]).first)
    }
}
