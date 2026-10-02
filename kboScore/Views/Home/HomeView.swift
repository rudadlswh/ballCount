import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppScreenHeader(title: "볼카운트", subtitle: "오늘도, \(appModel.favoriteTeam?.identity.displayName ?? "야구")와 함께")
                    favoriteTeamMenu
                    if let message = appModel.statusMessage(for: .home) {
                        DataStatusBannerView(message: message)
                    }
                    if appModel.isLoading && appModel.games.isEmpty {
                        ProgressView("경기를 불러오는 중")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let message = appModel.loadErrorMessage, appModel.games.isEmpty {
                        ContentUnavailableView {
                            Label("경기를 불러오지 못했습니다", systemImage: "wifi.exclamationmark")
                        } description: { Text(message) } actions: {
                            Button("다시 시도") { Task { await appModel.refreshHome() } }
                        }
                    } else {
                        gameSection
                    }
                    if let snapshot = appModel.standingsSnapshots.first(where: { $0.team.id == appModel.settings.favoriteTeamID }) {
                        seasonSummary(snapshot)
                    }
                    if let nextGame {
                        NavigationLink(value: nextGame) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar").foregroundStyle(StadiumPalette.app.textSecondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("다음 경기 · \(nextGame.awayTeam.identity.shortLabel) vs \(nextGame.homeTeam.identity.shortLabel)")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(nextGame.scheduledStart.formatted(.dateTime.month().day().hour().minute())) · \(nextGame.venue)")
                                        .font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                            }
                            .cardSurface(padding: 16, cornerRadius: 16)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            .dashboardScreen()
            .refreshable { await appModel.refreshHome() }
            .task { await appModel.loadStandingsIfNeeded() }
            .navigationDestination(for: String.self) { GameDetailView(gameIdentity: $0) }
            .navigationDestination(for: GameDetail.self) { GameDetailView(game: $0) }
        }
    }

    private var favoriteTeamMenu: some View {
        Menu {
            ForEach(appModel.teams) { team in
                Button(team.identity.displayName) { appModel.settings.favoriteTeamID = team.id }
            }
        } label: {
            HStack(spacing: 10) {
                FavoriteTeamBadge(teamID: appModel.settings.favoriteTeamID)
                Text(appModel.favoriteTeam?.identity.displayName ?? "응원 팀 선택").font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text("응원팀").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(StadiumPalette.app.textSecondary)
            }
            .cardSurface(padding: 8, cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("favoriteTeamMenu")
    }

    @ViewBuilder private var gameSection: some View {
        switch homeContentState {
        case .noGames, .noFilteredGames:
            EmptyStateView(systemImage: "sportscourt", title: "표시할 경기가 없습니다", message: "오늘 등록된 경기가 없습니다.")
        case let .fallbackStandings(title, subtitle, snapshots):
            HomeFallbackStandingsSection(title: title, subtitle: subtitle, snapshots: snapshots)
        case let .games(games):
            AppSectionTitle(title: "오늘의 경기", detail: games.first?.scheduledStart.formatted(.dateTime.month().day().weekday()) ?? "")
            if let featured = games.first {
                NavigationLink(value: featured) {
                    HomeHeroGameCard(summary: featured.summary(isMyTeamGame: featured.involves(teamID: appModel.settings.favoriteTeamID)), palette: .app)
                }.buttonStyle(.plain)
            }
        }
    }

    private func seasonSummary(_ snapshot: TeamStandingsSnapshot) -> some View {
        VStack(spacing: 12) {
            Button { appModel.selectedTab = .standings } label: {
                HStack {
                    Text("\(snapshot.team.identity.shortLabel)의 시즌").font(.headline).foregroundStyle(StadiumPalette.app.textPrimary)
                    Spacer()
                    Text("전체 순위  ›").font(.caption.weight(.semibold)).foregroundStyle(StadiumPalette.app.tint)
                }
            }.buttonStyle(.plain)
            HStack {
                AppMetric(value: "\(snapshot.rank)위", label: "리그 순위", highlighted: true)
                Divider().frame(height: 44)
                AppMetric(value: snapshot.winPercentageText, label: "승률")
                Divider().frame(height: 44)
                AppMetric(value: snapshot.currentStreakText, label: "최근 흐름")
            }.cardSurface(padding: 16)
        }
    }

    private var nextGame: GameDetail? {
        appModel.games.filter { $0.status == .upcoming && $0.involves(teamID: appModel.settings.favoriteTeamID) }
            .sorted { $0.scheduledStart < $1.scheduledStart }.first
    }

    private var homeContentState: HomeContentState {
        HomeContentState.make(todayGames: appModel.todayGames, filteredGames: appModel.filteredHomeGames,
                              filteredGameDetails: appModel.filteredHomeGameDetails,
                              fallbackTitle: appModel.homeFallbackTitleText, fallbackSubtitle: appModel.homeFallbackSubtitleText,
                              fallbackSnapshots: appModel.homeFallbackStandingsSnapshots)
    }
}

private struct HomeHeroGameCard: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: GameSummary
    let palette: StadiumPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    StatusBadge(status: summary.status)
                    Text(HomeHeroGamePresentation.timeText(for: summary)).font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Text(summary.venue).font(.caption).foregroundStyle(palette.textSecondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    StatusBadge(status: summary.status)
                    Text("\(HomeHeroGamePresentation.timeText(for: summary)) · \(summary.venue)").font(.caption)
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) {
                    teamSide(summary.awayTeam, score: summary.awayScore, role: "원정", pitcher: summary.awayStartingPitcherName)
                    teamSide(summary.homeTeam, score: summary.homeScore, role: "홈", pitcher: summary.homeStartingPitcherName)
                }
            } else {
                HStack(spacing: 12) {
                    teamSide(summary.awayTeam, score: summary.awayScore, role: "원정", pitcher: summary.awayStartingPitcherName)
                    Text(":").font(.title).foregroundStyle(palette.textSecondary)
                    teamSide(summary.homeTeam, score: summary.homeScore, role: "홈", pitcher: summary.homeStartingPitcherName)
                }
            }
            if summary.status.isLiveLike {
                Rectangle().fill(palette.ghostBorder).frame(height: 1)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(liveSituation).font(.caption)
                        Spacer(minLength: 8)
                        countIndicators
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(liveSituation).font(.caption)
                        countIndicators
                    }
                }
            }
            Text("경기 자세히 보기")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(palette.primary, in: RoundedRectangle(cornerRadius: 15))
        }
        .foregroundStyle(palette.textPrimary)
        .cardSurface(padding: 16, cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HomeHeroGamePresentation.accessibilityLabel(for: summary)), 점수 \(summary.awayScore.map(String.init) ?? "미정") 대 \(summary.homeScore.map(String.init) ?? "미정")")
        .accessibilityHint("경기 상세 정보를 엽니다")
    }

    private var liveSituation: String {
        [summary.outs.map { "\($0)사" }, HomeHeroGamePresentation.basesText(for: summary)].compactMap { $0 }.joined(separator: " · ")
    }

    private var countIndicators: some View {
        HStack(spacing: 8) {
            count("B", value: summary.balls, total: 3, color: Color(red: 84/255, green: 129/255, blue: 107/255))
            count("S", value: summary.strikes, total: 2, color: Color(red: 184/255, green: 141/255, blue: 48/255))
            count("O", value: summary.outs, total: 2, color: palette.tint)
        }
    }

    private func count(_ label: String, value: Int?, total: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundStyle(palette.textSecondary)
            ForEach(0..<total, id: \.self) { i in
                Circle().fill(i < (value ?? 0) ? color : palette.ghostBorder).frame(width: 4, height: 4)
            }
        }.accessibilityLabel("\(label) \(value.map(String.init) ?? "정보 없음")")
    }

    private func teamSide(_ team: Team, score: Int?, role: String, pitcher: String?) -> some View {
        VStack(spacing: 10) {
            Text(team.identity.shortLabel).font(.headline)
            if summary.showsLiveOrFinalScore {
                Text(score.map(String.init) ?? "–")
                    .font(.system(size: 61, weight: .bold)).monospacedDigit()
                    .foregroundStyle(team.id == appModel.settings.favoriteTeamID ? palette.tint : palette.textPrimary)
            } else {
                Text(HomeHeroGamePresentation.pitcherText(pitcher)).font(.subheadline).multilineTextAlignment(.center)
            }
            Text(role).font(.caption).foregroundStyle(palette.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}

// HomeFallbackStandingsSection 구조체는 HomeFallbackStandingsSection 타입의 역할과 값을 정의합니다.
private struct HomeFallbackStandingsSection: View {
    @Environment(AppModel.self) private var appModel
    let title: String
    let subtitle: String
    let snapshots: [TeamStandingsSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(appModel.favoriteStadiumPalette?.tint ?? .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
            }

            DisclosureGroup {
                LazyVStack(spacing: 8) {
                    ForEach(snapshots) { snapshot in
                        HomeFallbackStandingsRow(snapshot: snapshot)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("전체 팀 기록 보기").font(.subheadline.weight(.semibold))
            }
            .cardSurface(padding: 16, cornerRadius: 18)
        }
    }
}

// HomeFallbackStandingsRow 구조체는 HomeFallbackStandingsRow 타입의 역할과 값을 정의합니다.
private struct HomeFallbackStandingsRow: View {
    @Environment(AppModel.self) private var appModel

    let snapshot: TeamStandingsSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(snapshot.rank)")
                .font(.headline.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(appModel.favoriteStadiumPalette?.tint ?? appModel.currentTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(snapshot.team.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(StadiumPalette.app.textPrimary)
                        .lineLimit(1)
                    Text(snapshot.recordText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
                }

                HStack(spacing: 10) {
                    metric(title: "승률", value: snapshot.winPercentageText)
                    metric(title: snapshot.recentResultsMetricTitle, value: snapshot.recentResultsText)
                }
            }

            Spacer(minLength: 8)
        }
        .cardSurface(
            padding: 12,
            cornerRadius: 18
        )
    }

    // metric 메서드는 이 타입의 주요 동작을 수행합니다.
    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(appModel.favoriteStadiumPalette?.textPrimary ?? .primary)
                .lineLimit(1)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppModel.previewModel())
}
