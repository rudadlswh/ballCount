import SwiftUI

struct HomePostseasonBracketView: View {
    let bracket: PostseasonBracket
    let favoriteTeamID: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedRound: PostseasonRound?
    private let palette = StadiumPalette.app

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top))
            headerLayout {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(String(bracket.season)) POSTSEASON").font(.caption2.weight(.bold)).tracking(1.5)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(palette.tint)
                    Text("우승까지의 길").font(.title3.bold())
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                Text(statusText)
                    .font(.caption2.weight(.semibold)).padding(8)
                    .background(palette.tint.opacity(0.1), in: Capsule()).foregroundStyle(palette.tint)
            }
            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    staircase(width: max(proxy.size.width, dynamicTypeSize.isAccessibilitySize ? 640 : 280))
                }.scrollIndicators(.automatic)
            }.frame(height: dynamicTypeSize.isAccessibilitySize ? 340 : 242)
            if let champion = bracket.champion {
                Label("\(champion.displayName) 한국시리즈 우승", systemImage: "trophy.fill")
                    .font(.subheadline.bold()).foregroundStyle(palette.tint)
            } else {
                let current = bracket.currentSeries
                VStack(alignment: .leading, spacing: 5) {
                    Text(current.round.rule).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if let next = current.games.first(where: { $0.status.isLiveLike || $0.status == .upcoming }) {
                        Text("\(next.awayTeam.displayName) vs \(next.homeTeam.displayName) · \(next.scheduledStart.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.caption).foregroundStyle(palette.textSecondary)
                    } else {
                        Text("다음 경기 일정 확정 대기").font(.caption).foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
        .foregroundStyle(palette.textPrimary)
        .cardSurface(padding: 16, cornerRadius: 22)
        .accessibilityIdentifier("homePostseasonBracket")
        .sheet(item: $selectedRound) { round in
            scheduleSheet(bracket.series[round.rawValue])
        }
    }

    private var statusText: String {
        if bracket.champion != nil { return "시리즈 종료" }
        if bracket.currentSeries.round == .wildCard,
           let first = bracket.currentSeries.games.first(where: { $0.status != .cancelled }) {
            let calendar = PostseasonBracket.calendar
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: first.scheduledStart)).day ?? 0
            if days > 0 { return "개막 D-\(days)" }
        }
        return bracket.currentSeries.round.shortTitle
    }

    private func staircase(width: CGFloat) -> some View {
        let gap: CGFloat = 10
        let column = (width - gap * 3) / 4
        let rowHeight: CGFloat = dynamicTypeSize.isAccessibilitySize ? 72 : 42
        return HStack(alignment: .top, spacing: gap) {
            ForEach(bracket.series) { series in
                let active = bracket.currentSeries.round == series.round
                VStack(spacing: 7) {
                    Text(series.round.shortTitle).font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(active ? palette.tint : palette.textSecondary)
                    Button { selectedRound = series.round } label: {
                        VStack(spacing: 0) {
                            teamRow(series.seededTeam, placeholder: "\(series.round.seed)위", series: series)
                                .frame(height: rowHeight)
                            Rectangle().fill(palette.ghostBorder).frame(height: 1)
                            teamRow(series.challenger, placeholder: series.round.placeholder, series: series)
                                .frame(height: rowHeight)
                        }
                        .background(active ? palette.tint.opacity(0.07) : palette.elevatedCard, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? palette.tint : palette.ghostBorder, lineWidth: active ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(series.round.title), \(series.seededTeam?.displayName ?? "\(series.round.seed)위") 대 \(series.challenger?.displayName ?? series.round.placeholder)")
                    .accessibilityValue(series.winner.map { "\($0.displayName) 진출 확정" } ?? "진출팀 미정")
                    .accessibilityHint("시리즈 일정과 결과를 봅니다")
                    Text(series.winner.map { "\($0.displayName) \(series.round == .koreanSeries ? "우승" : "진출")" } ?? (series.round == .wildCard ? "최대 2경기" : series.round.rule))
                        .font(.caption2).foregroundStyle(series.winner == nil ? palette.textSecondary : palette.tint)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(width: column)
                .overlay(alignment: .topTrailing) {
                    if series.round != .koreanSeries {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 30))
                            path.addLine(to: CGPoint(x: gap / 2, y: 30))
                            path.addLine(to: CGPoint(x: gap / 2, y: 0))
                            path.addLine(to: CGPoint(x: gap, y: 0))
                        }
                        .stroke(palette.ghostBorder, lineWidth: 1.5)
                        .frame(width: gap, height: 30)
                        .offset(x: gap, y: rowHeight + 7)
                        .accessibilityHidden(true)
                    }
                }
                .padding(.top, CGFloat(3 - series.round.rawValue) * 30)
            }
        }.frame(width: width, alignment: .leading)
    }

    private func teamRow(_ team: Team?, placeholder: String, series: PostseasonSeries) -> some View {
        HStack(spacing: 3) {
            if let team, let seed = seed(for: team) {
                Text("\(seed)").font(.caption2).foregroundStyle(palette.textSecondary)
            }
            Text(team?.identity.monogram ?? placeholder)
                .font(.caption.weight(team == nil ? .regular : .bold))
                .lineLimit(1).minimumScaleFactor(0.7)
            if let team, series.games.contains(where: { $0.status == .final }) {
                Spacer(minLength: 0)
                Text("\(series.wins(for: team))").font(.caption2.bold()).monospacedDigit()
            }
        }
        .foregroundStyle(team?.id == favoriteTeamID && team != nil ? palette.tint : (team == nil ? palette.textSecondary : palette.textPrimary))
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func seed(for team: Team) -> Int? {
        bracket.series.first { $0.seededTeam?.id == team.id }?.round.seed
            ?? (bracket.series[0].challenger?.id == team.id ? 5 : nil)
    }

    private func scheduleSheet(_ series: PostseasonSeries) -> some View {
        NavigationStack {
            List {
                Section {
                    Text(series.round.rule)
                    if let winner = series.winner {
                        Label("\(winner.displayName) \(series.round == .koreanSeries ? "우승" : "진출 확정")", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(palette.tint)
                    }
                }
                Section("일정 및 결과") {
                    if series.games.isEmpty {
                        Text("대진 및 경기 일정 확정 대기").foregroundStyle(.secondary)
                    }
                    ForEach(series.games) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(game.awayTeam.displayName) vs \(game.homeTeam.displayName)").font(.headline)
                                Text("\(game.scheduledStart.formatted(.dateTime.month().day().hour().minute())) · \(game.venue)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if game.status == .final, let away = game.awayScore, let home = game.homeScore {
                                    Text("종료 · \(away) : \(home)").font(.subheadline.bold())
                                } else {
                                    Text(series.winner != nil && game.status == .upcoming ? "시리즈 종료 · 미개최" : game.status.title)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(series.round.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { selectedRound = nil } } }
        }.presentationDetents([.medium, .large])
    }
}

#Preview("포스트시즌 · 가로 상승형") {
    let teams = ["kt", "samsung", "kia", "lg", "doosan"].map {
        Team(id: $0, name: $0, shortName: $0, englishName: $0, markText: $0)
    }
    let standings = teams.enumerated().map {
        TeamStandingsSnapshot(team: $0.element, rank: $0.offset + 1, wins: 80, losses: 60, ties: 4, remainingRegularSeasonGames: 0, recentResults: [])
    }
    HomePostseasonBracketView(
        bracket: .make(season: 2026, schedules: [:], standings: standings, liveGames: []), favoriteTeamID: "lg"
    ).padding(22).background(StadiumPalette.app.background)
}
