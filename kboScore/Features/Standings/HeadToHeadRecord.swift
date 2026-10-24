import Foundation

nonisolated struct HeadToHeadRecord: Equatable, Sendable {
    let firstTeamWins: Int
    let secondTeamWins: Int
    let draws: Int

    var gamesPlayed: Int { firstTeamWins + secondTeamWins + draws }

    static func make(
        games: [GameDetail],
        firstTeamID: String,
        secondTeamID: String,
        season: Int
    ) -> HeadToHeadRecord {
        let firstID = Team.canonicalID(for: firstTeamID) ?? firstTeamID
        let secondID = Team.canonicalID(for: secondTeamID) ?? secondTeamID
        guard firstID != secondID else {
            return HeadToHeadRecord(firstTeamWins: 0, secondTeamWins: 0, draws: 0)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var seenGames = Set<String>()
        var firstWins = 0
        var secondWins = 0
        var draws = 0

        for game in games {
            guard game.isRegularSeason, game.hasCompleteFinalScore,
                  calendar.component(.year, from: game.scheduledStart) == season,
                  let awayScore = game.awayScore, let homeScore = game.homeScore else { continue }
            let awayID = Team.canonicalID(for: game.awayTeam.id) ?? game.awayTeam.id
            let homeID = Team.canonicalID(for: game.homeTeam.id) ?? game.homeTeam.id
            guard (awayID == firstID && homeID == secondID) ||
                    (awayID == secondID && homeID == firstID),
                  seenGames.insert(game.canonicalGameIdentityKey).inserted else { continue }

            let firstScore = awayID == firstID ? awayScore : homeScore
            let secondScore = awayID == firstID ? homeScore : awayScore
            if firstScore > secondScore { firstWins += 1 }
            else if firstScore < secondScore { secondWins += 1 }
            else { draws += 1 }
        }
        return HeadToHeadRecord(firstTeamWins: firstWins, secondTeamWins: secondWins, draws: draws)
    }
}
