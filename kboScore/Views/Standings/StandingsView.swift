//
//  StandingsView.swift
//  kboScore
//  기능 설명: KBO 순위표 화면과 순위 상태 표시를 구성합니다.
//  사용자가 경기 상태와 설정을 빠르게 이해하도록 도메인 상태를 화면 구조에 직접 매핑합니다.
//  SwiftUI 상태 갱신, 접근성, 작은 화면 레이아웃에서 정보가 겹치지 않도록 표시 조건을 제한합니다.
//  TODO : 반복되는 화면 조각은 재사용 가능한 컴포넌트로 분리하고 미리보기 케이스를 보강합니다.
//
//  Created by Codex on 4/2/26.
//

import SwiftUI

// StandingsView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
struct StandingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var tableTextScale = 1.0
    @ScaledMetric(relativeTo: .largeTitle) private var rankSize = 36.0

    var body: some View {
        NavigationStack {
            ScrollView {
                standingsContent
            }
            .dashboardScreen()
            .task(id: appModel.selectedTab) {
                guard appModel.selectedTab == .standings else { return }
                await appModel.loadStandingsIfNeeded()
            }
            .refreshable {
                await appModel.refreshStandings()
            }
        }
    }

    private var standingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppScreenHeader(title: "순위", subtitle: "우리 팀의 오늘을 한눈에")
            HStack {
                Text("팀 순위").font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(StadiumPalette.app.elevatedCard, in: Capsule())
                Text("정규시즌").font(.subheadline).foregroundStyle(StadiumPalette.app.textSecondary)
                    .frame(maxWidth: .infinity)
            }.padding(4).background(StadiumPalette.app.recessedSurface, in: Capsule())
            if let favorite = appModel.standingsSnapshots.first(where: { $0.team.id == appModel.settings.favoriteTeamID }) {
                favoriteSummary(favorite)
            }
            AppSectionTitle(title: "\(Calendar.current.component(.year, from: Date())) 정규시즌")
            switch standingsContentState {
            case .loading:
                ProgressView("순위 데이터를 불러오는 중")
                    .frame(maxWidth: .infinity, minHeight: 220)
            case .empty:
                EmptyStateView(
                    systemImage: "list.number",
                    title: "정규시즌 순위 데이터 없음",
                    message: "현재 데이터에서 시범경기를 제외한 정규시즌 종료 경기를 찾지 못했습니다."
                )
            case let .table(rows, revision, favoriteTeamID):
                standingsTable(rows: rows, revision: revision, favoriteTeamID: favoriteTeamID)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private func favoriteSummary(_ snapshot: TeamStandingsSnapshot) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .bottom))
        return layout {
            VStack(alignment: .leading, spacing: 12) {
                let detailLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                detailLayout {
                    Text("MY TEAM").font(.caption2.weight(.semibold))
                        .foregroundStyle(StadiumPalette.app.tint)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(StadiumPalette.app.tabBarSelectionSurface, in: Capsule())
                    Text(snapshot.team.identity.displayName).font(.subheadline.weight(.semibold))
                }
                detailLayout {
                    Text(snapshot.recordText).font(.headline)
                    Text(snapshot.currentStreakText).font(.caption.weight(.semibold)).foregroundStyle(StadiumPalette.app.tint)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text("\(snapshot.rank)위").font(.system(size: rankSize, weight: .bold)).foregroundStyle(StadiumPalette.app.tint)
        }.cardSurface(padding: 16)
    }

    private var standingsContentState: StandingsContentState {
        StandingsContentState.make(
            rows: appModel.standingsSnapshots,
            isLoading: appModel.isLoading && appModel.games.isEmpty,
            revision: appModel.standingsRowsRevision,
            favoriteTeamID: appModel.settings.favoriteTeamID
        )
    }

    // standingsTable 메서드는 이 타입의 주요 동작을 수행합니다.
    private func standingsTable(
        rows: [TeamStandingsSnapshot],
        revision: Int,
        favoriteTeamID: String?
    ) -> some View {
#if DEBUG
        let _ = Self.logVisibleRows(rows, revision: revision)
#endif

        let metrics = StandingsTableMetrics(textScale: tableTextScale)
        let leaderSnapshot = rows.first

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    tableRows(rows, leader: leaderSnapshot, favoriteTeamID: favoriteTeamID, metrics: metrics)
                        .frame(width: metrics.width)
                        .padding(.bottom, 8)
                }
                .accessibilityIdentifier("standingsTable")
                .accessibilityLabel("팀 순위표")
                .accessibilityHint("좌우로 스크롤해 모든 기록을 확인할 수 있습니다")
            } else {
                GeometryReader { proxy in
                    let metrics = StandingsTableMetrics(textScale: tableTextScale, availableWidth: proxy.size.width)
                    ZStack(alignment: .topLeading) {
                        tableRows(rows, leader: leaderSnapshot, favoriteTeamID: favoriteTeamID, metrics: metrics, showsStats: false)

                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: metrics.pinnedWidth)
                                .allowsHitTesting(false)

                            ScrollView(.horizontal) {
                                VStack(spacing: 0) {
                                    StandingsStatsHeader(metrics: metrics)
                                    ForEach(rows) { snapshot in
                                        StandingsStatsCells(snapshot: snapshot, leader: leaderSnapshot, metrics: metrics)
                                            .frame(height: metrics.rowHeight)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .padding(.trailing, metrics.horizontalPadding)
                                .frame(width: metrics.statsContentWidth)
                                .padding(.bottom, 8)
                            }
                            .frame(width: max(0, proxy.size.width - metrics.pinnedWidth))
                            .accessibilityIdentifier("standingsStatsScroll")
                            .accessibilityLabel("팀별 기록")
                            .accessibilityHint("좌우로 스크롤해 모든 기록을 확인할 수 있습니다")
                        }
                    }
                }
                .frame(height: CGFloat(rows.count + 1) * metrics.rowHeight + 8)
            }
        }
        .font(.system(size: 13 * tableTextScale, weight: .medium))
        .cardSurface(padding: 4, cornerRadius: 18)
        .overlay(alignment: .bottomTrailing) {
            Text("← 기록을 옆으로 넘겨보세요 →")
                .font(.caption2).foregroundStyle(StadiumPalette.app.textSecondary)
                .offset(y: 18)
        }
        .padding(.bottom, 18)
    }

    private func tableRows(
        _ rows: [TeamStandingsSnapshot],
        leader: TeamStandingsSnapshot?,
        favoriteTeamID: String?,
        metrics: StandingsTableMetrics,
        showsStats: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            StandingsTableHeader(metrics: metrics, showsStats: showsStats)
            ForEach(rows) { snapshot in
                StandingsRowView(snapshot: snapshot, leaderSnapshot: leader, favoriteTeamID: favoriteTeamID,
                                 metrics: metrics, showsStats: showsStats)
            }
        }
    }

#if DEBUG
    // logVisibleRows 메서드는 이 타입의 주요 동작을 수행합니다.
    private static func logVisibleRows(_ rows: [TeamStandingsSnapshot], revision: Int) {
        let movementCount = rows.filter { $0.rankMovement != .unchanged }.count
        print("[StandingsRankMovement] visible rows source count=\(rows.count) movementCount=\(movementCount) revision=\(revision)")
    }
#endif
}

// StandingsTableHeader 구조체는 StandingsTableHeader 타입의 역할과 값을 정의합니다.
private struct StandingsTableHeader: View {
    @Environment(AppModel.self) private var appModel

    let metrics: StandingsTableMetrics
    var showsStats = true

    var body: some View {
        HStack(spacing: metrics.spacing) {
            Text("순위")
                .frame(width: metrics.rankMovementWidth, alignment: .trailing)
            Text("팀")
                .frame(width: metrics.teamColumnWidth, alignment: .leading)
            if showsStats {
                StandingsStatsHeader(metrics: metrics)
            }
        }
        .foregroundStyle(appModel.favoriteStadiumPalette?.textSecondary ?? .secondary)
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(height: metrics.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StandingsStatsHeader: View {
    let metrics: StandingsTableMetrics

    var body: some View {
        HStack(spacing: metrics.spacing) {
            headerLabel("경기", width: metrics.gamesWidth)
            headerLabel("승", width: metrics.countWidth)
            headerLabel("패", width: metrics.countWidth)
            headerLabel("무", width: metrics.countWidth)
            headerLabel("승률", width: metrics.percentageWidth)
            headerLabel("게임차", width: metrics.gamesBehindWidth)
            headerLabel("연속", width: metrics.streakWidth)
        }
        .foregroundStyle(StadiumPalette.app.textSecondary)
        .frame(height: metrics.rowHeight)
    }

    // headerLabel 메서드는 이 타입의 주요 동작을 수행합니다.
    private func headerLabel(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
    }
}

// StandingsRowView 구조체는 화면에 표시되는 SwiftUI 뷰 구성을 담당합니다.
private struct StandingsRowView: View {
    let snapshot: TeamStandingsSnapshot
    let leaderSnapshot: TeamStandingsSnapshot?
    let favoriteTeamID: String?
    let metrics: StandingsTableMetrics
    var showsStats = true

    var body: some View {
#if DEBUG
        let _ = logRender()
#endif
        ZStack(alignment: .leading) {
            rowBackground

            HStack(spacing: metrics.spacing) {
                rankCell
                teamCell
                if showsStats {
                    StandingsStatsCells(snapshot: snapshot, leader: leaderSnapshot, metrics: metrics)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: metrics.rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rankCell: some View {
        HStack(spacing: 2) {
            Text("\(snapshot.rank)")
                .monospacedDigit()
                .foregroundStyle(isFavorite ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
                .lineLimit(1)
                .frame(width: metrics.rankWidth, alignment: .trailing)

            Text(rankMovement.displayText)
                .monospacedDigit()
                .foregroundStyle(rankMovementColor)
                .lineLimit(1)
                .frame(width: metrics.movementWidth, alignment: .trailing)
        }
        .frame(width: metrics.rankMovementWidth, alignment: .trailing)
    }

    private var teamCell: some View {
        HStack(spacing: 5) {
            Text(teamName)
                .foregroundStyle(isFavorite ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
                .lineLimit(1)
            if isFavorite {
                Circle().fill(StadiumPalette.app.tint).frame(width: 4, height: 4)
            }
        }
        .frame(width: metrics.teamColumnWidth, alignment: .leading)
    }

    private var rowBackground: some View {
        LinearGradient(stops: [
            .init(color: isFavorite ? StadiumPalette.app.tabBarSelectionSurface : .clear, location: 0),
            .init(color: .clear, location: 0.5),
            .init(color: .clear, location: 1)
        ], startPoint: .leading, endPoint: .trailing)
    }

    private var identity: TeamIdentity {
        snapshot.team.identity
    }

    private var teamName: String {
        identity.standingsDisplayName
    }

    private var isFavorite: Bool {
        snapshot.team.id == favoriteTeamID
    }

    private var rankMovement: RankingMovement {
        snapshot.rankMovement
    }

    private var rankMovementColor: Color {
        switch rankMovement {
        case .up:
            Color.green
        case .down:
            Color.red
        case .unchanged:
            Color.secondary
        }
    }

    private var accessibilityLabel: String {
        let movementText = rankMovement.accessibilityText.map { ", \($0)" } ?? ""
        return "\(snapshot.rank)위 \(identity.standingsDisplayName)\(movementText), \(snapshot.wins)승 \(snapshot.losses)패 \(snapshot.ties)무, 승률 \(snapshot.winPercentageText), 게임차 \(snapshot.gamesBehindText(leader: leaderSnapshot)), 연속 \(snapshot.currentStreakText)"
    }

#if DEBUG
    // logRender 메서드는 이 타입의 주요 동작을 수행합니다.
    private func logRender() {
        let preGameRankText = snapshot.preGameRank.map(String.init) ?? "<nil>"
        print("[StandingsRankMovement] row render teamId=\(snapshot.team.id) rank=\(snapshot.rank) preGameRank=\(preGameRankText) movement displayText=\(rankMovement.displayText)")
    }
#endif
}

private struct StandingsStatsCells: View {
    @Environment(AppModel.self) private var appModel
    let snapshot: TeamStandingsSnapshot
    let leader: TeamStandingsSnapshot?
    let metrics: StandingsTableMetrics

    var body: some View {
        HStack(spacing: metrics.spacing) {
            StandingsColumnValue(value: "\(snapshot.gamesPlayed)", width: metrics.gamesWidth)
            StandingsColumnValue(value: "\(snapshot.wins)", width: metrics.countWidth)
            StandingsColumnValue(value: "\(snapshot.losses)", width: metrics.countWidth)
            StandingsColumnValue(value: "\(snapshot.ties)", width: metrics.countWidth)
            StandingsColumnValue(value: snapshot.broadcastWinPercentageText, width: metrics.percentageWidth)
            StandingsColumnValue(value: snapshot.gamesBehindText(leader: leader), width: metrics.gamesBehindWidth)
            StandingsColumnValue(value: snapshot.currentStreakText, width: metrics.streakWidth)
        }
        .foregroundStyle(snapshot.team.id == appModel.settings.favoriteTeamID ? StadiumPalette.app.tint : StadiumPalette.app.textPrimary)
    }
}

// StandingsColumnValue 구조체는 StandingsColumnValue 타입의 역할과 값을 정의합니다.
private struct StandingsColumnValue: View {
    let value: String
    let width: CGFloat

    var body: some View {
        Text(value)
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
    }
}

#Preview {
    StandingsView()
        .environment(AppModel.previewModel())
}
