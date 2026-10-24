import Foundation

nonisolated enum PostseasonRound: Int, CaseIterable, Identifiable, Sendable {
    case wildCard, semiPlayoff, playoff, koreanSeries

    var id: Int { rawValue }
    var title: String { ["와일드카드", "준플레이오프", "플레이오프", "한국시리즈"][rawValue] }
    var shortTitle: String { ["와일드카드", "준PO", "PO", "한국시리즈"][rawValue] }
    var seriesID: String { ["4", "3", "5", "7"][rawValue] }
    var seed: Int { 4 - rawValue }
    var winsRequired: Int { self == .wildCard ? 2 : (self == .koreanSeries ? 4 : 3) }
    var rule: String { self == .wildCard ? "4위는 1승 또는 무승부 시 진출" : "\(winsRequired)선승제" }
    var placeholder: String { ["5위", "WC 승자", "준PO 승자", "PO 승자"][rawValue] }
}

nonisolated struct PostseasonSeries: Identifiable, Sendable {
    let round: PostseasonRound
    let seededTeam: Team?
    let challenger: Team?
    let games: [GameDetail]
    let winner: Team?
    var id: PostseasonRound { round }

    func wins(for team: Team?) -> Int {
        guard let team else { return 0 }
        return games.filter { game in
            guard game.status == .final, let away = game.awayScore, let home = game.homeScore else { return false }
            return away > home ? game.awayTeam.id == team.id : home > away && game.homeTeam.id == team.id
        }.count
    }
}

nonisolated struct PostseasonBracket: Sendable {
    let season: Int
    let series: [PostseasonSeries]

    var currentSeries: PostseasonSeries { series.first { $0.winner == nil } ?? series[3] }
    var champion: Team? { series.last?.winner }

    func isVisible(at now: Date) -> Bool {
        let games = series.flatMap(\.games).filter { $0.status != .cancelled }
        guard let start = games.map(\.scheduledStart).min(),
              Self.calendar.component(.year, from: now) == season,
              now >= Self.calendar.date(byAdding: .day, value: -7, to: Self.calendar.startOfDay(for: start))! else { return false }
        if champion != nil, let lastFinal = series.last?.games.filter({ $0.status == .final }).last {
            return now < Self.calendar.date(byAdding: .day, value: 1, to: Self.calendar.startOfDay(for: lastFinal.scheduledStart))!
        }
        return true
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    static func make(season: Int, schedules: [PostseasonRound: [GameDetail]], standings: [TeamStandingsSnapshot], liveGames: [GameDetail]) -> Self {
        var seeds: [Int: Team] = [:]
        for rank in 1...5 {
            let matches = standings.filter { $0.rank == rank }
            if matches.count == 1 { seeds[rank] = matches[0].team }
        }
        let rounds = PostseasonRound.allCases.map { round in
            uniqueGames(schedules[round] ?? []).filter { calendar.component(.year, from: $0.scheduledStart) == season }.map { scheduled in
                // A completed official result takes precedence over an older live snapshot.
                guard scheduled.status == .upcoming,
                      let live = liveGames.first(where: { gameKey($0) == gameKey(scheduled) }),
                      live.status != .upcoming else { return scheduled }
                return live
            }.sorted { $0.scheduledStart < $1.scheduledStart }
        }
        var result: [PostseasonSeries] = []
        for round in PostseasonRound.allCases {
            let games = rounds[round.rawValue]
            let first = games.first { $0.status != .cancelled }
            let participants = first.map { [$0.homeTeam, $0.awayTeam] } ?? []
            let previousWinner = result.last?.winner
            let seeded = seeds[round.seed] ?? participants.first { $0.id != previousWinner?.id }
            let challenger = participants.first { $0.id != seeded?.id } ?? (round == .wildCard ? seeds[5] : previousWinner)
            var winner = resolvedWinner(round: round, seeded: seeded, challenger: challenger, games: games)
            if winner == nil, round != .koreanSeries,
               let next = rounds[round.rawValue + 1].first(where: { $0.status != .cancelled }) {
                let candidates = [seeded, challenger].compactMap { $0 }.filter { next.involves(teamID: $0.id) }
                if candidates.count == 1 { winner = candidates[0] }
            }
            result.append(PostseasonSeries(round: round, seededTeam: seeded, challenger: challenger, games: games, winner: winner))
        }
        return Self(season: season, series: result)
    }

    private static func resolvedWinner(round: PostseasonRound, seeded: Team?, challenger: Team?, games: [GameDetail]) -> Team? {
        guard let seeded, let challenger else { return nil }
        var seededWins = 0
        var challengerWins = 0
        for game in games where game.status == .final && game.involves(teamID: seeded.id) && game.involves(teamID: challenger.id) {
            guard let away = game.awayScore, let home = game.homeScore else { continue }
            if away == home {
                if round == .wildCard { return seeded }
                continue
            }
            let winningID = away > home ? game.awayTeam.id : game.homeTeam.id
            if winningID == seeded.id { seededWins += 1 } else { challengerWins += 1 }
            if seededWins >= (round == .wildCard ? 1 : round.winsRequired) { return seeded }
            if challengerWins >= round.winsRequired { return challenger }
        }
        return nil
    }

    private static func gameKey(_ game: GameDetail) -> String { game.providerGameID ?? game.id.uuidString }

    private static func uniqueGames(_ games: [GameDetail]) -> [GameDetail] {
        var seen = Set<String>()
        return games.filter { seen.insert(gameKey($0)).inserted }
    }
}
