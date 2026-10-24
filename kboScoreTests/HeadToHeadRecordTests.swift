import Foundation
import Testing
@testable import kboScore

@MainActor
struct HeadToHeadRecordTests {
    @Test func countsBothHomeAndAwayAndReversesPerspective() {
        let games = [
            game(away: "doosan", home: "hanwha", awayScore: 5, homeScore: 2),
            game(away: "hanwha", home: "doosan", awayScore: 1, homeScore: 3),
            game(away: "doosan", home: "hanwha", awayScore: 2, homeScore: 4),
            game(away: "hanwha", home: "doosan", awayScore: 3, homeScore: 3)
        ]
        let record = HeadToHeadRecord.make(games: games, firstTeamID: "doosan", secondTeamID: "hanwha", season: 2026)
        #expect(record == HeadToHeadRecord(firstTeamWins: 2, secondTeamWins: 1, draws: 1))
        #expect(record.gamesPlayed == 4)
        #expect(HeadToHeadRecord.make(games: games, firstTeamID: "hanwha", secondTeamID: "doosan", season: 2026)
                == HeadToHeadRecord(firstTeamWins: 1, secondTeamWins: 2, draws: 1))
    }

    @Test func excludesOtherTeamsSeasonsAndUnfinishedOrIncompleteGames() {
        let games = [
            game(),
            game(home: "kia"),
            game(status: .live),
            game(status: .upcoming),
            game(status: .cancelled),
            game(classification: .exhibitionPreseason),
            game(classification: .postseason),
            game(classification: .unknown),
            game(date: "2025-08-01T18:30:00+09:00"),
            game(homeScore: nil)
        ]
        #expect(HeadToHeadRecord.make(games: games, firstTeamID: "doosan", secondTeamID: "hanwha", season: 2026)
                == HeadToHeadRecord(firstTeamWins: 1, secondTeamWins: 0, draws: 0))
    }

    @Test func ignoresDuplicateGamesButKeepsDoubleheaderGames() {
        let first = game(providerID: "20260801OBHH0")
        let duplicate = game(providerID: "20260801OBHH0")
        let second = game(awayScore: 1, homeScore: 2, providerID: "20260801OBHH1")
        let record = HeadToHeadRecord.make(games: [first, duplicate, second], firstTeamID: "doosan", secondTeamID: "hanwha", season: 2026)
        #expect(record == HeadToHeadRecord(firstTeamWins: 1, secondTeamWins: 1, draws: 0))
    }

    @Test func noMatchAndSameTeamProduceEmptyRecord() {
        let empty = HeadToHeadRecord(firstTeamWins: 0, secondTeamWins: 0, draws: 0)
        #expect(HeadToHeadRecord.make(games: [game()], firstTeamID: "lg", secondTeamID: "kia", season: 2026) == empty)
        #expect(HeadToHeadRecord.make(games: [game()], firstTeamID: "doosan", secondTeamID: "doosan", season: 2026) == empty)
    }

    private func game(
        away: String = "doosan", home: String = "hanwha",
        awayScore: Int? = 5, homeScore: Int? = 2,
        status: GameStatus = .final,
        classification: GameSeasonClassification = .regularSeason,
        date: String = "2026-08-01T18:30:00+09:00",
        providerID: String? = nil
    ) -> GameDetail {
        func team(_ id: String) -> Team {
            Team(id: id, name: id, shortName: id, englishName: id, markText: id)
        }
        return GameDetail(
            id: UUID(), scheduledStart: ISO8601DateFormatter().date(from: date)!, venue: "잠실",
            awayTeam: team(away), homeTeam: team(home), awayScore: awayScore, homeScore: homeScore,
            status: status, seasonClassification: classification, inningText: nil, bases: nil,
            balls: nil, strikes: nil, outs: nil, highlightText: nil, events: [], note: nil,
            providerGameID: providerID, awayStartingPitcherName: nil, homeStartingPitcherName: nil
        )
    }
}
